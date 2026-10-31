; Inno Setup script - the Azeroth Survivors Windows installer.
; Compiled by the build workflow:
;   ISCC /DAssetBase=<release url> /DBuildStamp=<date sha> /Osetup release\azeroth-survivors.iss
;
; The game data is NOT inside this exe - the WoW 1.12.1 client (~5.5 GB) busts GitHub's 2 GiB
; per-asset ceiling, so it publishes as the release's ~1.9 GiB chunks that fetch-data.ps1
; pulls into <install>\Data on first run (also from Start menu: "Fetch game data").

[Setup]
AppId={{B79C68A9-2E54-4B61-9B70-2030D34288A0}
AppName=Azeroth Survivors
AppVersion={#BuildStamp}
WizardStyle=modern
DefaultDirName={autopf}\Azeroth Survivors
DefaultGroupName=Azeroth Survivors
UninstallDisplayName=Azeroth Survivors
OutputBaseFilename=azeroth-survivors-setup
Compression=none
SolidCompression=no
; Nothing writes to the install dir at runtime except the data churn, wiped on uninstall.
AllowNoIcons=yes

[Files]
Source: "..\stage\www\*"; DestDir: "{app}\www"; Flags: recursesubdirs createallsubdirs
Source: "..\target\release\wenilla-host.exe"; DestDir: "{app}\bins"
Source: "fetch-data.ps1"; DestDir: "{app}"
Source: "fetch-data.bat"; DestDir: "{app}"
Source: "play.bat"; DestDir: "{app}"

[Icons]
Name: "{group}\Play Azeroth Survivors"; Filename: "{app}\play.bat"; WorkingDir: "{app}"
Name: "{group}\Fetch game data"; Filename: "{app}\fetch-data.bat"; WorkingDir: "{app}"
Name: "{autodesktop}\Play Azeroth Survivors"; Filename: "{app}\play.bat"; WorkingDir: "{app}"

[Run]
Filename: "{app}\fetch-data.bat"; Description: "Download the game data now (~5.5 GB, needs internet; resumable if interrupted)"; Flags: postinstall runasoriginaluser
Filename: "{app}\play.bat"; Description: "Play now"; Flags: postinstall unchecked skipifsilent runasoriginaluser

[UninstallDelete]
Type: filesandordirs; Name: "{app}\.data-parts"
Type: filesandordirs; Name: "{app}\Data"