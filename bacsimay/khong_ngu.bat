@echo off
REM Giu may khong ngu khi cam sac (de bot MT5 chay xuyen dem)
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0
powercfg /change monitor-timeout-ac 10
powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0
powercfg /setactive SCHEME_CURRENT
echo DA XONG - MAY SE KHONG NGU KHI CAM SAC (man hinh tat sau 10 phut)
pause
