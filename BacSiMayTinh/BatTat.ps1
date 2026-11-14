# ============================================================
#  BAT / TAT tu dong kham may moi ngay (bam 1 lan = doi trang thai)
# ============================================================
$ten     = 'BacSiMayTinh'
$noiCai  = 'C:\BacSiMayTinh'
$desktop = [Environment]::GetFolderPath('Desktop')

# Chep chuong trinh vao C:\BacSiMayTinh (lo xoa Downloads van chay)
New-Item -ItemType Directory -Path $noiCai -Force | Out-Null
foreach ($f in 'BacSiMayTinh.ps1','BatTat.ps1','BatTat.bat') {
    $src = Join-Path $PSScriptRoot $f
    if ((Test-Path $src) -and ((Resolve-Path $src).Path -ne (Join-Path $noiCai $f))) {
        Copy-Item $src $noiCai -Force
    }
}

function Tao-BieuTuong([bool]$bat) {
    # Xoa MOI bieu tuong cu (ca Desktop chung) de chi con 1 cai
    $publicDesktop = [Environment]::GetFolderPath('CommonDesktopDirectory')
    foreach ($d in @($desktop, $publicDesktop)) {
        Get-ChildItem $d -Filter 'Bac Si May Tinh - *.lnk' -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    }
    # Cat cac to bao cao cu ngoai Desktop vao C:\BacSiMayTinh\BaoCao
    New-Item -ItemType Directory -Path "$noiCai\BaoCao" -Force | Out-Null
    Get-ChildItem $desktop -Filter 'BacSiMayTinh_BaoCao_*.txt' -ErrorAction SilentlyContinue | Move-Item -Destination "$noiCai\BaoCao" -Force -ErrorAction SilentlyContinue
    $tenFile = if ($bat) { 'Bac Si May Tinh - DANG BAT.lnk' } else { 'Bac Si May Tinh - DANG TAT.lnk' }
    $icon    = if ($bat) { "$env:WINDIR\System32\imageres.dll,101" } else { "$env:WINDIR\System32\imageres.dll,100" }
    $ws = New-Object -ComObject WScript.Shell
    $lnk = $ws.CreateShortcut((Join-Path $desktop $tenFile))
    $lnk.TargetPath = "$noiCai\BatTat.bat"
    $lnk.WorkingDirectory = $noiCai
    $lnk.IconLocation = $icon
    $lnk.Description = 'Bam de BAT / TAT tu dong kham may moi ngay'
    $lnk.Save()
}

$dangCo = Get-ScheduledTask -TaskName $ten -ErrorAction SilentlyContinue

if ($dangCo) {
    # ---- TAT ----
    Unregister-ScheduledTask -TaskName $ten -Confirm:$false
    Tao-BieuTuong $false
    Write-Host ''
    Write-Host '   #######  ######  ######  ' -ForegroundColor Red
    Write-Host '   #     #  #       #       ' -ForegroundColor Red
    Write-Host '   #     #  ####    ####    ' -ForegroundColor Red
    Write-Host '   #     #  #       #       ' -ForegroundColor Red
    Write-Host '   #######  #       #       ' -ForegroundColor Red
    Write-Host ''
    Write-Host 'DA TAT tu dong kham may.' -ForegroundColor Red
    Write-Host 'Bam lai bieu tuong "Bac Si May Tinh" ngoai Desktop de BAT lai.'
} else {
    # ---- BAT ----
    $action    = New-ScheduledTaskAction -Execute 'powershell.exe' `
                 -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Minimized -File `"$noiCai\BacSiMayTinh.ps1`""
    $trigger   = New-ScheduledTaskTrigger -Daily -At '12:00PM'
    $user      = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
    $settings  = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries `
                 -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 2)
    Register-ScheduledTask -TaskName $ten -Action $action -Trigger $trigger -Principal $principal `
        -Settings $settings -Description 'Bac Si May Tinh: quet virus + don rac moi ngay' -Force | Out-Null
    Tao-BieuTuong $true
    Write-Host ''
    Write-Host '   #######  ##    #  ' -ForegroundColor Green
    Write-Host '   #     #  # #   #  ' -ForegroundColor Green
    Write-Host '   #     #  #  #  #  ' -ForegroundColor Green
    Write-Host '   #     #  #   # #  ' -ForegroundColor Green
    Write-Host '   #######  #    ##  ' -ForegroundColor Green
    Write-Host ''
    Write-Host 'DA BAT! May se tu kham MOI NGAY luc 12 GIO TRUA.' -ForegroundColor Green
    Write-Host 'Luc do may tat thi lan bat may tiep theo se tu kham bu.'
    Write-Host 'Bao cao luu ngoai Desktop. Bam lai bieu tuong de TAT.'
}
