# BAC SI MAY - tu "ngo" MT5 va ghi bao cao. Chi DOC, khong thay doi gi tren may.
# Chay tay: powershell -ExecutionPolicy Bypass -File C:\BacSiMay\bao_cao_mt5.ps1
# Bao cao luu o: C:\BacSiMay\baocao\  (moi lan chay them 1 file, giu 7 ngay)
param([switch]$KhongBaoPopup)
$ErrorActionPreference = 'SilentlyContinue'
$base   = Split-Path -Parent $MyInvocation.MyCommand.Path
$outDir = Join-Path $base 'baocao'
New-Item -ItemType Directory -Force $outDir | Out-Null
$now    = Get-Date
$lines  = New-Object System.Collections.Generic.List[string]
$canhBao = New-Object System.Collections.Generic.List[string]
function W($s) { $lines.Add($s) }

W "=== BAO CAO MT5 luc $($now.ToString('dd/MM/yyyy HH:mm')) ==="
$cuoiTuan = ($now.DayOfWeek -eq 'Saturday') -or ($now.DayOfWeek -eq 'Sunday')

# 1. MT5 co chay khong
$p = @(Get-Process terminal64)
if ($p.Count -gt 0) { W "[OK] MT5 dang chay ($($p.Count) cua so)" }
else { W "[!!] MT5 KHONG chay"; $canhBao.Add('MT5 dang TAT - mo lai MT5 va dang nhap') }

# 2. Mang
if (Test-Connection 8.8.8.8 -Count 1 -Quiet) { W "[OK] Co mang Internet" }
else { W "[!!] MAT MANG"; $canhBao.Add('May dang mat mang') }

# 3. Nhat ky tung MT5
$root = Join-Path $env:APPDATA 'MetaQuotes\Terminal'
$dirs = @(Get-ChildItem $root -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'MQL5\Experts') })
if ($dirs.Count -eq 0) { W "[!!] Khong tim thay thu muc du lieu MT5" }
foreach ($d in $dirs) {
    $of = Join-Path $d.FullName 'origin.txt'
    $origin = if (Test-Path $of) { (Get-Content $of -Raw).Trim() } else { $d.Name }
    W ""
    W "--- MT5: $origin"

    $log = Get-ChildItem (Join-Path $d.FullName 'MQL5\Logs') -Filter '*.log' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($log) {
        $gio = [math]::Round(($now - $log.LastWriteTime).TotalHours, 1)
        W "    Bot ghi nhat ky lan cuoi: $($log.LastWriteTime.ToString('dd/MM HH:mm')) (cach day $gio gio)"
        if ($gio -gt 3 -and -not $cuoiTuan -and $p.Count -gt 0) { $canhBao.Add("Bot im lang $gio gio ($origin) - kiem tra bot con tren chart / nut Algo Trading") }
        W "    15 dong Experts moi nhat:"
        Get-Content $log.FullName -Encoding Unicode -Tail 15 | ForEach-Object { W "      $_" }
        $loiBot = Get-Content $log.FullName -Encoding Unicode -Tail 300 | Select-String 'failed|error|retcode=100(1[4-9]|2[17]|30)|DUNG|MAT KET NOI'
        if ($loiBot) { $canhBao.Add("Experts co $(@($loiBot).Count) dong loi/canh bao ($origin)") }
    } else { W "    (chua co nhat ky Experts - chua gan bot nao?)" }

    $j = Get-ChildItem (Join-Path $d.FullName 'logs') -Filter '*.log' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($j) {
        $hit = @(Get-Content $j.FullName -Encoding Unicode -Tail 500 |
                 Select-String 'failed|error|disabled|rejected|removed|no connection|connection lost|not enough|invalid' |
                 Select-Object -Last 10)
        W "    Journal - loi gan nhat:"
        if ($hit.Count) {
            $hit | ForEach-Object { W "      $_" }
            if ($hit | Select-String 'disabled|investor') { $canhBao.Add("Journal: Algo Trading bi TAT ($origin)") }
            if ($hit | Select-String 'removed')           { $canhBao.Add("Journal: bot bi GO khoi chart ($origin)") }
        } else { W "      (khong co loi)" }
    }
}

# 4. Suc khoe may
W ""
$os  = Get-CimInstance Win32_OperatingSystem
$ram = [math]::Round($os.FreePhysicalMemory/1MB, 1)
$c   = Get-PSDrive C
$cGB = [math]::Round($c.Free/1GB, 1)
$up  = [math]::Round(($now - $os.LastBootUpTime).TotalDays, 1)
W "--- May: RAM trong $ram GB | O C trong $cGB GB | Da bat $up ngay"
if ($ram -lt 1)  { $canhBao.Add("RAM sap het ($ram GB) - dong bot Chrome/app nang") }
if ($cGB -lt 10) { $canhBao.Add("O C sap day ($cGB GB)") }
$ngu = powercfg /q SCHEME_CURRENT SUB_SLEEP STANDBYIDLE | Select-String '0x' | Select-Object -Last 2
W "    Che do ngu (cam sac / pin): $(($ngu | ForEach-Object { ($_ -split ':')[-1].Trim() }) -join ' / ')"
if ($ngu -and ($ngu[0] -notmatch '0x00000000')) { $canhBao.Add('May van tu NGU khi cam sac - chay khong_ngu.bat') }

# 5. Ket luan
W ""
if ($canhBao.Count -eq 0) { W "KET LUAN: MOI THU BINH THUONG" }
else { W "KET LUAN: CAN CHU Y"; $canhBao | ForEach-Object { W "  - $_" } }

$file = Join-Path $outDir ("baocao_" + $now.ToString('yyyyMMdd_HHmm') + ".txt")
$lines | Set-Content $file -Encoding UTF8
$lines | Set-Content (Join-Path $outDir 'MOI_NHAT.txt') -Encoding UTF8
Get-ChildItem $outDir -Filter 'baocao_*.txt' | Where-Object { $_.LastWriteTime -lt $now.AddDays(-7) } | Remove-Item
$lines | ForEach-Object { Write-Host $_ }

if ($canhBao.Count -gt 0 -and -not $KhongBaoPopup) {
    $msg = "BAC SI MAY - MT5 can chu y:`n`n" + ($canhBao -join "`n") + "`n`nChi tiet: $file"
    (New-Object -ComObject WScript.Shell).Popup($msg, 600, 'Bac si may - MT5', 48) | Out-Null
}
