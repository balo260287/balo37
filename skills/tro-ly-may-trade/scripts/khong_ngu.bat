@echo off
REM Giu may khong ngu khi cam sac (de bot MT5 chay xuyen dem)
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0
powercfg /change monitor-timeout-ac 10
powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0
REM Tat "ngu de tiet kiem" cua o cung va USB khi cam sac (tranh MT5 bi dung giua dem)
powercfg /setacvalueindex SCHEME_CURRENT SUB_DISK DISKIDLE 0
powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /setactive SCHEME_CURRENT
echo.
echo Kiem tra (dong AC phai la 0x00000000):
powercfg /q SCHEME_CURRENT SUB_SLEEP STANDBYIDLE | findstr /i "AC"
echo DA XONG - MAY SE KHONG NGU KHI CAM SAC (man hinh tat sau 10 phut)
pause
