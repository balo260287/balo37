# Kham may cham (CHI DOC, khong thay doi gi).
# Chay: powershell -ExecutionPolicy Bypass -File kham_may.ps1
$ErrorActionPreference = 'SilentlyContinue'
Write-Host "=== KHAM MAY ==="

$os = Get-CimInstance Win32_OperatingSystem
$free = $os.FreePhysicalMemory / 1MB; $tot = $os.TotalVisibleMemorySize / 1MB
Write-Host ("RAM trong: {0:N1} / {1:N1} GB" -f $free, $tot)
if ($free -lt 1) { Write-Host "  [!!] RAM gan het - dong bot Chrome/app nang" }

$c = Get-PSDrive C
Write-Host ("O C con trong: {0:N1} GB" -f ($c.Free / 1GB))
if ($c.Free / 1GB -lt 10) { Write-Host "  [!!] O C sap day - nen don may (don_may.ps1)" }

$cpu = (Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 2 -MaxSamples 3).CounterSamples |
       Measure-Object CookedValue -Average
Write-Host ("CPU trung binh 6 giay: {0:N0}%" -f $cpu.Average)

Write-Host ""
Write-Host "10 chuong trinh ton RAM nhat:"
Get-Process | Group-Object Name | ForEach-Object {
    [pscustomobject]@{ Ten = $_.Name; RAM_MB = [int](($_.Group | Measure-Object WorkingSet64 -Sum).Sum / 1MB); SoCuaSo = $_.Count }
} | Sort-Object RAM_MB -Descending | Select-Object -First 10 | Format-Table -AutoSize | Out-String | Write-Host

Write-Host "Ung dung tu bat khi mo may:"
Get-CimInstance Win32_StartupCommand | ForEach-Object { Write-Host "  - $($_.Name)" }

$up = (Get-Date) - $os.LastBootUpTime
Write-Host ("May da chay lien tuc: {0} ngay {1} gio" -f $up.Days, $up.Hours)
if ($up.Days -ge 7) { Write-Host "  [!!] Lau chua khoi dong lai - nen restart khi bot khong co lenh mo" }

$mt5 = @(Get-Process terminal64)
Write-Host ("So cua so MT5 dang mo: {0}" -f $mt5.Count)
