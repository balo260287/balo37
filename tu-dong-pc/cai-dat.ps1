# Cai dat tu dong: MT5 tu mo khi bat may, may tu NGU ban dem va tu THUC buoi sang.
$ErrorActionPreference = 'Stop'
$Dir = 'C:\WyckoffAuto'

function Ask-Time($question, $default) {
    while ($true) {
        $s = Read-Host "$question (Enter = $default)"
        if ([string]::IsNullOrWhiteSpace($s)) { $s = $default }
        if ($s -match '^([01]?\d|2[0-3]):[0-5]\d$') { return [datetime]::ParseExact($s.PadLeft(5,'0'), 'HH:mm', $null) }
        Write-Host "  Sai dinh dang. Vi du dung: 23:00" -ForegroundColor Red
    }
}

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  CAI DAT TU DONG CHO MAY CHAY BOT VANG"       -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# ---- 1. Tim MT5 ----
Write-Host "[1/5] Dang tim MetaTrader 5 tren may..."
$found = @()
foreach ($root in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, "$env:LOCALAPPDATA\Programs")) {
    if ($root -and (Test-Path $root)) {
        $found += Get-ChildItem -Path $root -Filter 'terminal64.exe' -Recurse -Depth 2 -ErrorAction SilentlyContinue
    }
}
$mt5 = $null
if ($found.Count -eq 1) {
    $mt5 = $found[0].FullName
} elseif ($found.Count -gt 1) {
    Write-Host "  Tim thay nhieu MT5:"
    for ($i = 0; $i -lt $found.Count; $i++) { Write-Host "   $($i+1). $($found[$i].FullName)" }
    $n = Read-Host "  Go so thu tu MT5 dang chay bot"
    $mt5 = $found[[int]$n - 1].FullName
} else {
    Write-Host "  Khong tu tim thay MT5." -ForegroundColor Yellow
    $mt5 = (Read-Host "  Keo tha file terminal64.exe vao day roi Enter").Trim('"', ' ')
}
if (-not (Test-Path $mt5)) { throw "Khong thay file MT5: $mt5" }
Write-Host "  OK: $mt5" -ForegroundColor Green

# ---- 2. Hoi gio ----
Write-Host ""
Write-Host "[2/5] Chon gio (dung gio dong ho tren may tinh, dinh dang 24h)"
$sleepAt = Ask-Time "  May di NGU luc may gio?" "23:00"
$wakeAt  = Ask-Time "  May tu THUC luc may gio?" "06:00"

# ---- 3. Chep script ----
Write-Host ""
Write-Host "[3/5] Chep script vao $Dir ..."
New-Item -ItemType Directory -Force -Path $Dir | Out-Null
Copy-Item "$PSScriptRoot\ngu.ps1", "$PSScriptRoot\giu-thuc.ps1" -Destination $Dir -Force
$statusFile = Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files\WyckoffGold_status.txt'

# ---- 4. Tao lich hen ----
Write-Host "[4/5] Tao lich hen trong Task Scheduler..."
$sys = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

# 4a. Thuc day + giu may thuc ca ngay (chay tu luc thuc den luc ngu)
$aWake = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Dir\giu-thuc.ps1`""
$tWake = @( (New-ScheduledTaskTrigger -Daily -At $wakeAt), (New-ScheduledTaskTrigger -AtStartup) )
$sWake = New-ScheduledTaskSettingsSet -WakeToRun -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName 'WyckoffAuto-Thuc' -Action $aWake -Trigger $tWake -Principal $sys -Settings $sWake -Force | Out-Null

# 4b. Di ngu (chi ngu khi KHONG con lenh mo)
$aSleep = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Dir\ngu.ps1`" -StatusFile `"$statusFile`""
$sSleep = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 4)
Register-ScheduledTask -TaskName 'WyckoffAuto-Ngu' -Action $aSleep -Trigger (New-ScheduledTaskTrigger -Daily -At $sleepAt) -Principal $sys -Settings $sSleep -Force | Out-Null

# 4c. MT5 tu mo khi dang nhap Windows
$startup = [Environment]::GetFolderPath('Startup')
$ws = New-Object -ComObject WScript.Shell
$lnk = $ws.CreateShortcut((Join-Path $startup 'MT5 (WyckoffAuto).lnk'))
$lnk.TargetPath = $mt5
$lnk.WorkingDirectory = Split-Path $mt5
$lnk.Save()

# ---- 5. Cai dat nguon dien ----
Write-Host "[5/5] Cai dat nguon dien..."
powercfg /setacvalueindex SCHEME_CURRENT SUB_SLEEP RTCWAKE 1 | Out-Null   # cho phep hen gio danh thuc
powercfg /setdcvalueindex SCHEME_CURRENT SUB_SLEEP RTCWAKE 1 | Out-Null
powercfg /setactive SCHEME_CURRENT | Out-Null
powercfg /change standby-timeout-ac 0 | Out-Null                         # ban ngay khong tu ngu
Start-ScheduledTask -TaskName 'WyckoffAuto-Thuc'                         # bat che do giu thuc ngay bay gio

Write-Host ""
Write-Host "=============== XONG ===============" -ForegroundColor Green
Write-Host ("  May tu NGU luc  : {0:HH:mm} hang ngay (neu con lenh mo thi doi, toi da 3 gio)" -f $sleepAt)
Write-Host ("  May tu THUC luc : {0:HH:mm} hang ngay" -f $wakeAt)
Write-Host  "  MT5 tu mo khi dang nhap Windows"
Write-Host  "  Nhat ky: $Dir\nhat-ky.txt"
Write-Host ""
Write-Host "  BUOC TIEP THEO: chay file 2-THU-NGHIEM.bat de kiem tra may co tu thuc duoc khong." -ForegroundColor Yellow
