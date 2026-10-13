@echo off
REM Liga o Rojo: o que voce editar no VS Code aparece na hora no Roblox Studio.
REM No Studio: aba Plugins > Rojo > Connect.
cd /d "%~dp0"
"%~dp0tools-rojo\rojo.exe" serve default.project.json
pause
