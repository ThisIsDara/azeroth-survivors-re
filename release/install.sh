#!/usr/bin/env bash
#
# install.sh — the Azeroth Survivors portable installer. Bash, no root; works in Git Bash on
# Windows and plain bash on Linux/macOS.
#
#   ./install.sh [dir]          # into ./azeroth-survivors by default
#
# Downloads (resumable, checksummed) from the release that shipped this script:
# client.tar.gz (the browser client), host.tar.gz (prebuilt wenilla-host binaries), and — when
# the release carries the game — the WoW 1.12.1 client's Data folder as ~1.9 GiB chunks,
# reassembled and verified against the one-stream checksum.
#
# No Blizzard content originates in the repository; the data section only exists where a
# release carries it (the `data` input in the build workflow).
set -euo pipefail

BASE="${WENILLA_ASSET_BASE:-__ASSET_BASE__}"
DIR="${1:-azeroth-survivors}"

say() { printf '\033[1;31m✦\033[0m %s\n' "$*"; }

say "installing into ${DIR}"
mkdir -p "${DIR}"
cd "${DIR}"

fetch() { curl --fail --location --progress-bar -C - -o "$1" "$2"; }

verify() {
    local want got
    want=$(awk -v f="$1" '$2 == f {print $1}' assets.sha256)
    got=$(sha256sum "$1" | awk '{print $1}')
    [ "$want" = "$got" ] || { say "checksum mismatch on $1 (want $want, got $got)"; return 1; }
}

say "checksums (assets.sha256)"
fetch assets.sha256 "${BASE}/assets.sha256"

say "the browser client (client.tar.gz)"
fetch client.tar.gz "${BASE}/client.tar.gz"
verify client.tar.gz
tar -xzf client.tar.gz && rm client.tar.gz

say "the host binaries (host.tar.gz)"
fetch host.tar.gz "${BASE}/host.tar.gz"
verify host.tar.gz
tar -xzf host.tar.gz && rm host.tar.gz
gzip -d bins/*.gz
chmod +x bins/*

# The data: WoW 1.12.1 (build 5875) split under GitHub's 2 GiB per-asset ceiling. A release
# built with the `data` input off has no chunks, and this whole block is skipped.
if curl --fail --silent --head "${BASE}/wow-data.tar.part-00" >/dev/null 2>&1; then
    say "the game data — a WoW 1.12.1 client, ~5.5 GB, chunked and resumable"
    if [ ! -f sha256.txt ]; then fetch sha256.txt "${BASE}/sha256.txt"; fi
    have=""
    for n in 00 01 02 03 04; do
        out="wow-data.tar.part-${n}"
        if fetch "$out" "${BASE}/${out}"; then
            verify "$out"
            have=$n
        else
            rm -f "$out"
            break
        fi
    done
    [ -n "$have" ] || { say "no data chunks could be fetched"; exit 1; }
    say "reassembling and verifying against sha256.txt"
    cat wow-data.tar.part-* | sha256sum | grep -q "$(awk '$2 == "wow-data.tar" {print $1}' sha256.txt)" || {
        say "reassembled data does not match sha256.txt — re-run, downloads resume"; exit 1
    }
    say "unpacking (this takes a minute)"
    cat wow-data.tar.part-* | tar -xf -
    rm -f wow-data.tar.part-*
fi

# The launcher: the host serves ./web/dist on 127.0.0.1:8090 with ./Data as the MPQ chain.
cat > play.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
host=bins/wenilla-host-linux-x86_64
uname -s | grep -qi windows && host=bins/wenilla-host-windows-x86_64.exe
[ -x "${host}" ] || { echo "no host binary at ${host} (run install.sh first)"; exit 1; }
echo "the game: http://127.0.0.1:8090/  (Ctrl+C stops the server)"
exec "${host}" --www web/dist --data Data
EOF
chmod +x play.sh

say "done — run ./play.sh (needs a WebGPU browser; Chrome on Linux wants --enable-unsafe-webgpu)"
