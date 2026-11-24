# Kham tong quat may tinh: CPU, RAM, o dia, nhiet/pin, mang, Windows Update, chuong trinh an RAM.
# Chi DOC thong tin, khong thay doi gi tren may.
# Chay: powershell -ExecutionPolicy Bypass -File kham_may.ps1
$ErrorActionPreference = 'SilentlyContinue'
$warn = New-Object System.Collections.Generic.List[string]
Write-Host "=== KHAM TONG QUAT MAY TINH ==="

# --- He dieu hanh & thoi gian bat may
$os = Get-CimInstance Win32_OperatingSystem
$up = (Get-Date) - $os.LastBootUpTime
Write-Host ("[i] {0} | Bat may lien tuc: {1} ngay {2} gio" -f $os.Caption, $up.Days, $up.Hours)
if ($up.Days -ge 7) { $warn.Add("May chua khoi dong lai $($up.Days) ngay -> nen Restart 1 lan (luc khong co lenh)") }

# --- CPU
$cpu = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
Write-Host ("[i] CPU dang dung: {0}%" -f [int]$cpu)
if ($cpu -ge 85) { $warn.Add("CPU qua tai ($([int]$cpu)%) -> xem danh sach chuong trinh nang ben duoi") }

# --- RAM
$totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
$freeGB  = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
$usedPct = [int](100 - ($os.FreePhysicalMemory * 100 / $os.TotalVisibleMemorySize))
Write-Host ("[i] RAM: dung {0}% (con trong {1} / {2} GB)" -f $usedPct, $freeGB, $totalGB)
if ($usedPct -ge 85) { $warn.Add("RAM gan day ($usedPct%) -> tat bot tab Chrome / chuong trinh khong can") }

# --- O dia
Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
    $freeD = [math]::Round($_.FreeSpace / 1GB, 1); $sizeD = [math]::Round($_.Size / 1GB, 1)
    $pct = if ($_.Size) { [int]($_.FreeSpace * 100 / $_.Size) } else { 0 }
    Write-Host ("[i] O {0} con trong {1} / {2} GB ({3}%)" -f $_.DeviceID, $freeD, $sizeD, $pct)
    if ($_.DeviceID -eq 'C:' -and ($freeD -lt 10 -or $pct -lt 10)) { $warn.Add("O C: sap day ($freeD GB) -> chay Disk Cleanup / xoa file tai ve") }
}
$disk = Get-PhysicalDisk | Select-Object -First 1
if ($disk) {
    Write-Host ("[i] O cung: {0} ({1}), suc khoe: {2}" -f $disk.FriendlyName, $disk.MediaType, $disk.HealthStatus)
    if ($disk.HealthStatus -and $disk.HealthStatus -ne 'Healthy') { $warn.Add("O cung bao loi suc khoe ($($disk.HealthStatus)) -> sao luu du lieu ngay") }
    if ($disk.MediaType -eq 'HDD') { $warn.Add("May dung o HDD (cham) -> nang cap SSD se nhanh hon rat nhieu") }
}

# --- Pin / nguon
$bat = Get-CimInstance Win32_Battery
if ($bat) {
    $ac = if ($bat.BatteryStatus -eq 2) { 'DANG CAM SAC' } else { 'DANG CHAY PIN' }
    Write-Host ("[i] Pin: {0}% - {1}" -f $bat.EstimatedChargeRemaining, $ac)
    if ($bat.BatteryStatus -ne 2) { $warn.Add("Laptop dang chay pin -> cam sac de bot chay xuyen dem") }
}
$plan = (powercfg /getactivescheme) -replace '.*\((.*)\).*', '$1'
Write-Host "[i] Che do nguon: $plan"

# --- Mang
$ping = Test-Connection -ComputerName 8.8.8.8 -Count 4 -ErrorAction SilentlyContinue
if ($ping) {
    $ms = [int]($ping | Measure-Object -Property ResponseTime -Average).Average
    $lost = 4 - @($ping).Count
    Write-Host ("[i] Mang: ping {0} ms, mat {1}/4 goi" -f $ms, $lost)
    if ($ms -gt 150 -or $lost -gt 0) { $warn.Add("Mang cham/chap chon (ping $ms ms) -> dung day LAN hoac doi gan modem") }
} else {
    Write-Host "[!!] KHONG CO MANG"; $warn.Add("Mat ket noi internet -> kiem tra wifi/modem")
}

# --- Windows Update cho khoi dong lai
$reboot = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') -or
          (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending')
if ($reboot) { Write-Host "[!!] Windows Update dang CHO KHOI DONG LAI"; $warn.Add("Windows sap tu khoi dong lai -> Restart chu dong luc khong co lenh, hoac Pause updates") }
else { Write-Host "[OK] Khong co ban cap nhat cho khoi dong lai" }

# --- Lan tat may bat thuong gan day (mat dien, treo)
$crash = @(Get-WinEvent -FilterHashtable @{LogName='System'; Id=41; StartTime=(Get-Date).AddDays(-14)} -MaxEvents 5)
if ($crash.Count -gt 0) {
    Write-Host ("[!!] {0} lan tat may dot ngot trong 14 ngay (lan cuoi: {1})" -f $crash.Count, $crash[0].TimeCreated)
    $warn.Add("May tung tat dot ngot -> kiem tra nguon dien, nhiet do, cap sac")
}

# --- Chuong trinh an RAM nhat
Write-Host ""
Write-Host "--- 8 chuong trinh dung nhieu RAM nhat:"
Get-Process | Group-Object ProcessName | ForEach-Object {
    [pscustomobject]@{ Ten = $_.Name; MB = [int](($_.Group | Measure-Object WorkingSet64 -Sum).Sum / 1MB); SoCuaSo = $_.Count }
} | Sort-Object MB -Descending | Select-Object -First 8 | ForEach-Object {
    Write-Host ("    {0,-28} {1,6} MB  ({2})" -f $_.Ten, $_.MB, $_.SoCuaSo)
}

# --- Chuong trinh tu chay khi bat may
$startup = @(Get-CimInstance Win32_StartupCommand)
Write-Host ""
Write-Host ("--- {0} chuong trinh tu chay khi bat may" -f $startup.Count)
$startup | Select-Object -First 12 | ForEach-Object { Write-Host ("    {0}" -f $_.Name) }
if ($startup.Count -gt 12) { $warn.Add("Nhieu chuong trinh tu chay ($($startup.Count)) -> tat bot trong Task Manager > Startup apps") }

# --- Ket luan
Write-Host ""
Write-Host "=== KET LUAN ==="
if ($warn.Count -eq 0) { Write-Host "[OK] May khoe, khong thay van de" }
else { $i = 1; foreach ($w in $warn) { Write-Host ("  {0}. {1}" -f $i, $w); $i++ } }
