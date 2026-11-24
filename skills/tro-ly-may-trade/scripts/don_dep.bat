@echo off
REM Don dep nhe cho may: xoa file tam (TEMP) va thung rac. KHONG dung toi MT5, bot hay tai lieu.
REM Nen dong MT5 truoc khi chay (khong bat buoc).
echo Dang don file tam...
del /q /f /s "%TEMP%\*" >nul 2>&1
for /d %%x in ("%TEMP%\*") do rd /s /q "%%x" >nul 2>&1
echo Dang don thung rac...
powershell -NoProfile -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue"
echo Mo cong cu Disk Cleanup cua Windows (tick 'Temporary files', 'Windows Update Cleanup' roi OK)...
start "" cleanmgr /d C:
echo DA XONG - file dang duoc dung se tu bo qua, khong sao
pause
