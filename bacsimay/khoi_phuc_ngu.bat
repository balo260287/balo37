@echo off
REM Khoi phuc che do ngu binh thuong
powercfg /change standby-timeout-ac 30
powercfg /change hibernate-timeout-ac 0
powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 1
powercfg /setactive SCHEME_CURRENT
echo DA KHOI PHUC - MAY NGU SAU 30 PHUT, GAP MAY LA NGU
pause
