@echo off
rem Play Azeroth Survivors — run the local server, then open the game in the default browser.
cd /d "%~dp0"
if not exist "Data\terrain.MPQ" (
    echo no game data yet - fetch it first ^(Start menu: Azeroth Survivors -^> Fetch game data^)
    pause
    exit /b 1
)
start "" /b cmd /c "timeout /t 2 /nobreak >nul && start "" http://127.0.0.1:8090/"
echo the game: http://127.0.0.1:8090/  (Ctrl+C stops the server)
"bins\wenilla-host.exe" --www www --data Data
