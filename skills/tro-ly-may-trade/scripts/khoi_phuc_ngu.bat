@echo off
REM Khoi phuc che do ngu binh thuong
powercfg /change standby-timeout-ac 30
powercfg /change hibernate-timeout-ac 0
powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 1
powercfg /setacvalueindex SCHEME_CURRENT SUB_DISK DISKIDLE 1200
powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1
powercfg /setactive SCHEME_CURRENT
echo DA KHOI PHUC - MAY NGU SAU 30 PHUT, GAP MAY LA NGU
pause
