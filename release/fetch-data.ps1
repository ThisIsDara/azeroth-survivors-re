param(
    [Parameter(Mandatory = $true)][string]$AssetBase,
    [string]$InstallDir   # {app} of the Inno setup, no backslash; defaults next to this file
)
# fetch-data.ps1 - the Azeroth Survivors Windows data fetcher. Pulls the WoW 1.12.1 client's
# Data folder as the release's ~1.9 GiB chunks, resumable (HTTP Range), checksummed per chunk
# against assets.sha256, then reassembles, unpacks to .\Data, and cleans up.
#
# The repository ships no Blizzard content; the bundled data re-hosts archive.org's WoW client
# at the repo owner's request.

$ErrorActionPreference = 'Stop'

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

if (-not $InstallDir) { $InstallDir = $PSScriptRoot }
$chunks = Join-Path $InstallDir '.data-parts'
$data   = Join-Path $InstallDir 'Data'

if ((Test-Path (Join-Path $data 'terrain.MPQ')) -and (Test-Path (Join-Path $data 'patch.MPQ'))) {
    Write-Host "game data already present in $data"
    exit 0
}
New-Item -ItemType Directory -Force $chunks | Out-Null

$shaMap = @{}
$rawText = (New-Object Net.WebClient).DownloadString("$AssetBase/assets.sha256")
$rawText -split "`r?`n" | ForEach-Object {
    $line = $_.Trim()
    if ($line) {
        $parts = $line -split '\s+', 2
        if ($parts.Count -ge 2) {
            $shaMap[$parts[1].Trim()] = $parts[0].ToLower()
        }
    }
}

# The chunk count is a release-time fact; assets.sha256 knows it.
$names = @()
for ($i = 0; $i -lt 8; $i++) {
    $name = 'wow-data.tar.part-{0:D2}' -f $i
    if (-not $shaMap.ContainsKey($name)) { break }
    $names += $name
}
if (-not $names) {
    Write-Host "this release has no game-data chunks (the build workflow's data input was off)"
    exit 1
}

function Get-RangeResumable([string]$Url, [string]$Dest) {
    $have = 0
    if (Test-Path $Dest) {
        $have = [long](Get-Item $Dest).Length
    } else {
        [void](New-Item -ItemType File -Force $Dest)
    }
    $name = Split-Path -Leaf $Url
    $req = [Net.HttpWebRequest]::Create($Url)
    $req.UserAgent = 'azeroth-survivors-installer'
    $req.AllowAutoRedirect = $true
    if ($have -gt 0) { $req.AddRange([long]$have) }

    try
    {
        $resp = $req.GetResponse()
    } catch [Net.WebException] {
        if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 416) {
            Write-Host "  $name already complete"
            return
        }
        throw
    }
    if ($have -gt 0 -and [int]$resp.StatusCode -ne 206) {
        $resp.Close()
        Remove-Item $Dest -Force
        throw "$name resume unsupported by the server - deleted $Dest, re-run to fetch whole"
    }
    $total = $have + [long]$resp.ContentLength
    $src = $resp.GetResponseStream()
    $fs = [IO.File]::Open($Dest, [IO.FileMode]::Append, [IO.FileAccess]::Write)
    try
    {
        $buf = New-Object byte[] (8MB)
        while ($true) {
            $read = $src.Read($buf, 0, $buf.Length)
            if ($read -le 0) { break }
            $fs.Write($buf, 0, $read)
            $have += $read
            if ($have % (32MB) -lt 8MB) {
                Write-Progress -Activity 'fetching game data' `
                    -CurrentOperation $name `
                    -PercentComplete ([math]::Min(99, [int](100 * $have / $total)))
            }
        }
    } finally {
        $fs.Close(); $src.Close(); $resp.Close()
        Write-Progress -Activity 'fetching game data' -Completed
    }
}

foreach ($name in $names) {
    $dest = Join-Path $chunks $name
    Write-Host "fetching $name"
    Get-RangeResumable "$AssetBase/$name" $dest
    Write-Host "verifying $name"
    $got = (Get-FileHash -Algorithm SHA256 $dest).Hash.ToLower()
    if ($got -ne $shaMap[$name]) {
        throw "checksum mismatch on $name - re-run the fetcher (resumes); if it persists, delete $chunks"
    }
}

Write-Host 'reassembling'
$combined = Join-Path $chunks 'wow-data.tar'
$out = [IO.File]::Create($combined)
foreach ($name in $names) {
    $src = [IO.File]::OpenRead((Join-Path $chunks $name))
    try { $src.CopyTo($out, 64MB) } finally { $src.Close() }
}
$out.Close()

Write-Host 'unpacking (this takes a minute)'
New-Item -ItemType Directory -Force $InstallDir | Out-Null
tar -xf $combined -C $InstallDir
Set-Content -Encoding ascii -NoNewline (Join-Path $data '.ready') 'ok'

Write-Host 'cleaning up'
Remove-Item $chunks -Recurse -Force
if (-not (Test-Path (Join-Path $data 'terrain.MPQ'))) {
    throw "Data\terrain.MPQ missing after unpack - check $InstallDir for a partial Data folder"
}

Write-Host "done - the game data is in $data. Run play.lnk / Play Azeroth Survivors."
