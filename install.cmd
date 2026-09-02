@echo off
setlocal
set "INSTALLER=%TEMP%\claude-mode-install-%RANDOM%-%RANDOM%.ps1"
if defined CLAUDE_MODE_INSTALL_URL (
  set "INSTALL_URL=%CLAUDE_MODE_INSTALL_URL%"
) else (
  set "INSTALL_URL=https://raw.githubusercontent.com/Mineru98/claude-mode/refs/heads/main/install.ps1"
)
curl.exe -fsSL "%INSTALL_URL%" -o "%INSTALLER%"
if errorlevel 1 (
  echo claude-mode: install.ps1 download failed 1>&2
  exit /b 1
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%INSTALLER%"
set "RESULT=%ERRORLEVEL%"
del /q "%INSTALLER%" >nul 2>&1
exit /b %RESULT%
