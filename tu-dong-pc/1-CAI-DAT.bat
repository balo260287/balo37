@echo off
REM Tu dong xin quyen Administrator roi chay cai-dat.ps1
cd /d "%~dp0"
net session >nul 2>&1
if %errorlevel% neq 0 (
  echo Dang xin quyen Administrator... Hay bam YES.
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0cai-dat.ps1"
echo.
pause
