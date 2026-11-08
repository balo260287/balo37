# Go bo toan bo che do tu dong.
foreach ($t in 'WyckoffAuto-Thuc', 'WyckoffAuto-Ngu', 'WyckoffAuto-ThuNghiem') {
    Stop-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $t -Confirm:$false -ErrorAction SilentlyContinue
}
Remove-Item (Join-Path ([Environment]::GetFolderPath('Startup')) 'MT5 (WyckoffAuto).lnk') -ErrorAction SilentlyContinue
Remove-Item 'C:\WyckoffAuto' -Recurse -Force -ErrorAction SilentlyContinue
powercfg /change standby-timeout-ac 30 | Out-Null
Write-Host "Da go bo xong. May tro lai binh thuong (tu ngu sau 30 phut khong dung)." -ForegroundColor Green
