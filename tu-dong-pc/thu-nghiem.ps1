# Thu: cho may ngu ngay, 3 phut sau may phai tu thuc day.
$Dir = 'C:\WyckoffAuto'
New-Item -ItemType Directory -Force -Path $Dir | Out-Null
$ok = "$Dir\thu-nghiem-ok.txt"
Remove-Item $ok -ErrorAction SilentlyContinue

Write-Host "THU NGHIEM: may se NGU ngay bay gio va TU THUC sau khoang 3 phut." -ForegroundColor Cyan
Write-Host "Dung cham vao chuot/ban phim. Cho 3-4 phut va xem may co tu sang len khong."
Read-Host "Bam Enter de bat dau (luu cong viec dang lam truoc)"

powercfg /setacvalueindex SCHEME_CURRENT SUB_SLEEP RTCWAKE 1 | Out-Null
powercfg /setactive SCHEME_CURRENT | Out-Null

$at  = (Get-Date).AddMinutes(3)
$sys = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$act = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument "/c echo ok > `"$ok`""
$set = New-ScheduledTaskSettingsSet -WakeToRun -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName 'WyckoffAuto-ThuNghiem' -Action $act -Trigger (New-ScheduledTaskTrigger -Once -At $at) -Principal $sys -Settings $set -Force | Out-Null

Stop-ScheduledTask -TaskName 'WyckoffAuto-Thuc' -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3
Add-Type -AssemblyName System.Windows.Forms
[void][System.Windows.Forms.Application]::SetSuspendState([System.Windows.Forms.PowerState]::Suspend, $false, $false)

# --- Sau khi may thuc lai ---
Start-Sleep -Seconds 20
Unregister-ScheduledTask -TaskName 'WyckoffAuto-ThuNghiem' -Confirm:$false -ErrorAction SilentlyContinue
Start-ScheduledTask -TaskName 'WyckoffAuto-Thuc' -ErrorAction SilentlyContinue
Write-Host ""
if (Test-Path $ok) {
    Write-Host "THANH CONG: may tu thuc day dung hen. Moi thu da san sang." -ForegroundColor Green
} else {
    Write-Host "THAT BAI: may KHONG tu thuc (ban phai bam nut de bat lai)." -ForegroundColor Red
    Write-Host "Xem muc 'Neu thu nghiem THAT BAI' trong file HUONG-DAN.md"
}
