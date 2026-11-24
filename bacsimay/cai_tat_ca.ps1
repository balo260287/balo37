# CAI BAC SI MAY 1 LAN: tai file ve C:\BacSiMay, giu may khong ngu khi cam sac,
# cai lich kiem tra MT5 moi 1 gio, chay thu 1 lan. Khong dat lenh, khong sua bot.
$ErrorActionPreference = 'Stop'
$dir = 'C:\BacSiMay'
$src = 'https://raw.githubusercontent.com/balo260287/balo37/claude/intelligent-heisenberg-ezl14z/bacsimay'
$files = 'bao_cao_mt5.ps1','kiem_tra_mt5.ps1','kham_may.ps1','khong_ngu.bat','khoi_phuc_ngu.bat','cai_lich_kiem_tra.bat','go_lich_kiem_tra.bat','HUONG_DAN.txt'
New-Item -ItemType Directory -Force $dir | Out-Null
Write-Host "1/4 Tai file ve $dir ..."
foreach ($f in $files) { Invoke-WebRequest "$src/$f" -OutFile (Join-Path $dir $f) -UseBasicParsing }
Get-ChildItem $dir | Unblock-File
Write-Host "2/4 Giu may khong ngu khi cam sac (man hinh van tat sau 10 phut)..."
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0
powercfg /change monitor-timeout-ac 10
powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0
powercfg /setactive SCHEME_CURRENT
Write-Host "3/4 Cai lich kiem tra MT5 moi 1 gio..."
$tr = "powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$dir\bao_cao_mt5.ps1`""
schtasks /create /f /tn "BacSiMay_NgoMT5" /sc hourly /mo 1 /tr $tr | Out-Null
Write-Host "4/4 Chay thu lan dau:"
Write-Host ""
& powershell -NoProfile -ExecutionPolicy Bypass -File "$dir\bao_cao_mt5.ps1" -KhongBaoPopup
Write-Host ""
Write-Host "=== DA CAI XONG BAC SI MAY ===  Bao cao: $dir\baocao\MOI_NHAT.txt"
Write-Host "Go bo: bam dup $dir\go_lich_kiem_tra.bat va $dir\khoi_phuc_ngu.bat"
