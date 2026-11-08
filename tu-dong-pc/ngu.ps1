# Cho may ngu (Sleep). Neu con lenh dang mo thi doi, toi da 3 gio.
param([string]$StatusFile)
$log = 'C:\WyckoffAuto\nhat-ky.txt'
function Log($m) { Add-Content -Path $log -Value ("{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $m) }

$deadline = (Get-Date).AddHours(3)
while ($true) {
    $open = 0
    if ($StatusFile -and (Test-Path $StatusFile)) {
        $age = ((Get-Date) - (Get-Item $StatusFile).LastWriteTime).TotalMinutes
        if ($age -lt 30) {   # file cu hon 30 phut = MT5/bot khong chay -> bo qua
            $txt = Get-Content $StatusFile -Raw
            if ($txt -match 'positions=(\d+)') { $open += [int]$Matches[1] }
            if ($txt -match 'orders=(\d+)')    { $open += [int]$Matches[1] }
        }
    }
    if ($open -eq 0) { break }
    if ((Get-Date) -gt $deadline) { Log "Van con $open lenh sau 3 gio -> KHONG ngu dem nay"; exit }
    Log "Con $open lenh/lenh cho -> doi 10 phut"
    Start-Sleep -Seconds 600
}

Log "Khong con lenh -> cho may NGU"
Stop-ScheduledTask -TaskName 'WyckoffAuto-Thuc' -ErrorAction SilentlyContinue
Start-Sleep -Seconds 5
Add-Type -AssemblyName System.Windows.Forms
[void][System.Windows.Forms.Application]::SetSuspendState([System.Windows.Forms.PowerState]::Suspend, $false, $false)
