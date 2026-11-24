# Kiem tra MT5 & bot: MT5 co dang chay, file bot trong Experts, nhat ky Experts + Journal, loi hay gap, che do ngu.
# Chi DOC thong tin, khong thay doi gi tren may.
# Chay: powershell -ExecutionPolicy Bypass -File kiem_tra_mt5.ps1 [-Lines 30] [-Bot GoldSweep]
param(
    [int]$Lines = 30,
    [string]$Bot = ''   # loc theo ten bot (de trong = tat ca bot)
)
$ErrorActionPreference = 'SilentlyContinue'
Write-Host "=== KIEM TRA MT5 & BOT ==="

$p = @(Get-Process terminal64)
if ($p.Count -gt 0) {
    foreach ($x in $p) {
        Write-Host ("[OK] MT5 dang chay: {0} | RAM {1} MB | mo luc {2}" -f $x.Path, [int]($x.WorkingSet64 / 1MB), $x.StartTime)
        if ($x.Responding -eq $false) { Write-Host "[!!] MT5 KHONG PHAN HOI (treo) - dong han bang Task Manager roi mo lai" }
    }
} else { Write-Host "[!!] MT5 KHONG chay - hay mo MT5 va dang nhap" }

# Thu muc du lieu: ban cai thuong (%APPDATA%) + ban portable (Program Files co thu muc MQL5)
$dirs = @()
$root = Join-Path $env:APPDATA 'MetaQuotes\Terminal'
$dirs += @(Get-ChildItem $root -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'MQL5\Experts') })
foreach ($x in $p) {
    $inst = Split-Path $x.Path
    if (Test-Path (Join-Path $inst 'MQL5\Experts')) { $dirs += Get-Item $inst }
}
$dirs = @($dirs | Sort-Object FullName -Unique)
if ($dirs.Count -eq 0) { Write-Host "[!!] Khong tim thay thu muc du lieu MT5 ($root)" }

# Dong nhat ky dang chu y
$pattern = 'error|loi|failed|retcode=100[0-9][0-9]|10027|10018|10019|10016|10014|10030|4756|4752|disconnect|connection lost|MAT KET NOI|removed|uninit|DUNG|initialization failed|cannot load'

function Read-MtLog($path, $n) {
    # Nhat ky MT5 la UTF-16; doc dung ma de khong bi loi font
    $t = Get-Content $path -Encoding Unicode -Tail $n
    if (-not $t -or ($t -join '') -notmatch '[A-Za-z]') { $t = Get-Content $path -Tail $n }
    return $t
}

foreach ($d in $dirs) {
    $originFile = Join-Path $d.FullName 'origin.txt'
    $origin = if (Test-Path $originFile) { (Get-Content $originFile -Raw).Trim() } else { $d.FullName }
    Write-Host ""
    Write-Host "--- MT5: $origin"
    Write-Host "    Du lieu: $($d.FullName)"

    $exp = Join-Path $d.FullName 'MQL5\Experts'
    $mine = @(Get-ChildItem $exp -Recurse -Include '*.mq5', '*.ex5' |
              Where-Object { $_.FullName -notmatch '\\(Examples|Advisors|Free Robots|Market)\\' } |
              Where-Object { -not $Bot -or $_.Name -like "*$Bot*" })
    if ($mine.Count -eq 0) { Write-Host "    (chua co file bot nao cua ban trong Experts)" }
    foreach ($b in ($mine | Sort-Object LastWriteTime -Descending | Select-Object -First 15)) {
        Write-Host ("    {0,-34} {1}" -f $b.Name, $b.LastWriteTime)
    }
    # Canh bao .mq5 moi hon .ex5 (sua code nhung chua compile)
    foreach ($src in ($mine | Where-Object Extension -eq '.mq5')) {
        $ex5 = [IO.Path]::ChangeExtension($src.FullName, '.ex5')
        if (-not (Test-Path $ex5)) { Write-Host "    [!!] $($src.Name) CHUA compile (khong co .ex5)" }
        elseif ((Get-Item $ex5).LastWriteTime -lt $src.LastWriteTime) { Write-Host "    [!!] $($src.Name) da sua nhung CHUA compile lai" }
    }

    # Nhat ky Experts (MQL5\Logs) va Journal (logs)
    foreach ($kind in @(@('Experts', 'MQL5\Logs'), @('Journal', 'logs'))) {
        $log = Get-ChildItem (Join-Path $d.FullName $kind[1]) -Filter '*.log' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (-not $log) { continue }
        $all = Read-MtLog $log.FullName 2000
        if ($Bot) { $all = @($all | Where-Object { $_ -match [regex]::Escape($Bot) }) }
        Write-Host ""
        Write-Host ("    [{0}] {1}, {2} dong cuoi:" -f $kind[0], $log.Name, $Lines)
        $all | Select-Object -Last $Lines | ForEach-Object { Write-Host "      $_" }
        $bad = @($all | Where-Object { $_ -match $pattern })
        if ($bad.Count -gt 0) {
            Write-Host ("    [!!] {0} dong bao loi/canh bao hom nay, 5 dong moi nhat:" -f $bad.Count)
            $bad | Select-Object -Last 5 | ForEach-Object { Write-Host "      >> $_" }
        }
    }
}

Write-Host ""
Write-Host "--- Che do ngu (dong 1 = cam sac, dong 2 = pin; 0x00000000 = khong bao gio ngu):"
powercfg /q SCHEME_CURRENT SUB_SLEEP STANDBYIDLE | Select-String '0x' | Select-Object -Last 2 | ForEach-Object { Write-Host "    $_" }

$ping = Test-Connection -ComputerName 8.8.8.8 -Count 2 -ErrorAction SilentlyContinue
if ($ping) { Write-Host ("[OK] Co mang (ping {0} ms)" -f [int]($ping | Measure-Object ResponseTime -Average).Average) }
else { Write-Host "[!!] KHONG CO MANG - bot se khong dat duoc lenh" }
