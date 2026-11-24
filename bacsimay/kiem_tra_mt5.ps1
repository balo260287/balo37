# Kiem tra MT5 & bot: MT5 co dang chay, file bot co trong Experts, nhat ky moi nhat, che do ngu.
# Chay: powershell -ExecutionPolicy Bypass -File kiem_tra_mt5.ps1
$ErrorActionPreference = 'SilentlyContinue'
Write-Host "=== KIEM TRA MT5 & BOT ==="

$p = @(Get-Process terminal64)
if ($p.Count -gt 0) { Write-Host "[OK] MT5 dang chay ($($p.Count) cua so)" }
else { Write-Host "[!!] MT5 KHONG chay - hay mo MT5 va dang nhap" }

$root = Join-Path $env:APPDATA 'MetaQuotes\Terminal'
$dirs = @(Get-ChildItem $root -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'MQL5\Experts') })
if ($dirs.Count -eq 0) { Write-Host "[!!] Khong tim thay thu muc du lieu MT5 ($root)" }

foreach ($d in $dirs) {
    $originFile = Join-Path $d.FullName 'origin.txt'
    $origin = if (Test-Path $originFile) { (Get-Content $originFile -Raw).Trim() } else { $d.Name }
    Write-Host ""
    Write-Host "--- MT5: $origin"
    $exp = Join-Path $d.FullName 'MQL5\Experts'
    $bots = @(Get-ChildItem $exp -Recurse -Include '*Sweep*.mq5','*Sweep*.ex5')
    if ($bots.Count -eq 0) { Write-Host "    (chua co file bot Sweep trong Experts)" }
    foreach ($b in $bots) { Write-Host ("    {0,-30} {1}" -f $b.Name, $b.LastWriteTime) }

    $logDir = Join-Path $d.FullName 'MQL5\Logs'
    $log = Get-ChildItem $logDir -Filter '*.log' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($log) {
        Write-Host "    Nhat ky Experts moi nhat ($($log.Name), sua luc $($log.LastWriteTime)), 30 dong cuoi:"
        Get-Content $log.FullName -Encoding Unicode -Tail 30 | ForEach-Object { Write-Host "      $_" }
    } else { Write-Host "    (khong co nhat ky Experts - bot chua tung chay?)" }

    $jDir = Join-Path $d.FullName 'logs'
    $j = Get-ChildItem $jDir -Filter '*.log' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($j) {
        Write-Host "    Journal ($($j.Name)) - dong loi/canh bao gan nhat:"
        $hit = Get-Content $j.FullName -Encoding Unicode -Tail 500 |
               Select-String 'failed|error|disabled|rejected|removed|uninit|no connection|connection lost|not enough|invalid|closed' |
               Select-Object -Last 15
        if ($hit) { $hit | ForEach-Object { Write-Host "      $_" } } else { Write-Host "      (khong co loi)" }
    }
}

Write-Host ""
Write-Host "--- Che do ngu (dong 1 = cam sac, dong 2 = pin; 0x00000000 = khong bao gio ngu):"
powercfg /q SCHEME_CURRENT SUB_SLEEP STANDBYIDLE | Select-String '0x' | Select-Object -Last 2 | ForEach-Object { Write-Host "    $_" }
