# Cai / go Bac Si May Tinh tu chay moi tuan
param([switch]$Go)
$ten = 'BacSiMayTinh'
$noiCai = 'C:\BacSiMayTinh'

if ($Go) {
    Unregister-ScheduledTask -TaskName $ten -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host 'Da TAT tu dong kham may.' -ForegroundColor Yellow
    exit
}

# Chep chuong trinh vao C:\BacSiMayTinh de lo xoa thu muc Downloads van chay duoc
New-Item -ItemType Directory -Path $noiCai -Force | Out-Null
Copy-Item -Path (Join-Path $PSScriptRoot 'BacSiMayTinh.ps1') -Destination $noiCai -Force

$action   = New-ScheduledTaskAction -Execute 'powershell.exe' `
            -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Minimized -File `"$noiCai\BacSiMayTinh.ps1`""
$trigger  = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At '8:00PM'
$user     = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$principal= New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries `
            -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 2)

Register-ScheduledTask -TaskName $ten -Action $action -Trigger $trigger -Principal $principal `
    -Settings $settings -Description 'Bac Si May Tinh: quet virus + don rac moi tuan' -Force | Out-Null

Write-Host ''
Write-Host 'DA CAI TU DONG THANH CONG!' -ForegroundColor Green
Write-Host 'May se tu kham moi CHU NHAT luc 8 GIO TOI.'
Write-Host 'Neu luc do may tat, may se tu kham ngay lan bat may tiep theo.'
Write-Host 'Bao cao luu ngoai Desktop sau moi lan kham.'
