@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\claude-mode.ps1" %*
exit /b %errorlevel%
