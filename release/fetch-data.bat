@echo off
rem Fetch game data - WiwO 1.12.1 from the release's chunks, resume-friendly, checksummed.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0fetch-data.ps1" -AssetBase "__ASSET_BASE__"
pause
