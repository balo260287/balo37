@echo off
REM Cai lich: moi 1 gio tu chay bao_cao_mt5.ps1 (chi doc, khong thay doi MT5).
REM Go bo: chay go_lich_kiem_tra.bat
set DIR=%~dp0
schtasks /create /f /tn "BacSiMay_NgoMT5" /sc hourly /mo 1 /tr "powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File \"%DIR%bao_cao_mt5.ps1\""
if %errorlevel%==0 (echo DA CAI LICH: moi 1 gio kiem tra MT5. Bao cao o %DIR%baocao\MOI_NHAT.txt) else (echo LOI khi cai lich)
powershell -NoProfile -ExecutionPolicy Bypass -File "%DIR%bao_cao_mt5.ps1" -KhongBaoPopup
pause
