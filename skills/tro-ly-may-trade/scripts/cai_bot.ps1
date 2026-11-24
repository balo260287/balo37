# Cai / cap nhat bot vao MT5: sao luu ban cu, chep file .mq5 vao MQL5\Experts va compile bang MetaEditor.
# Chay: powershell -ExecutionPolicy Bypass -File cai_bot.ps1 -File "C:\...\GoldSweepBot.mq5" [-Index 0]
param(
    [Parameter(Mandatory = $true)][string]$File,
    [int]$Index = -1
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path $File)) { Write-Host "[!!] Khong tim thay file: $File"; exit 1 }
$File = (Resolve-Path $File).Path
if ([IO.Path]::GetExtension($File) -notin '.mq5', '.mqh') { Write-Host "[!!] File phai la .mq5 (hoac .mqh)"; exit 1 }

# Thu muc du lieu: ban cai thuong + ban portable dang chay
$dirs = @()
$root = Join-Path $env:APPDATA 'MetaQuotes\Terminal'
$dirs += @(Get-ChildItem $root -Directory -ErrorAction SilentlyContinue |
           Where-Object { Test-Path (Join-Path $_.FullName 'MQL5\Experts') })
foreach ($x in @(Get-Process terminal64 -ErrorAction SilentlyContinue)) {
    $inst = Split-Path $x.Path
    if (Test-Path (Join-Path $inst 'MQL5\Experts')) { $dirs += Get-Item $inst }
}
$dirs = @($dirs | Sort-Object FullName -Unique)
if ($dirs.Count -eq 0) { Write-Host "[!!] Khong tim thay MT5. Mo MT5 mot lan roi chay lai."; exit 1 }

function Get-Origin($d) {
    $f = Join-Path $d.FullName 'origin.txt'
    if (Test-Path $f) { return (Get-Content $f -Raw).Trim() }
    return $d.FullName   # ban portable: thu muc chinh la noi cai
}

if ($dirs.Count -gt 1 -and $Index -lt 0) {
    Write-Host "Tim thay nhieu MT5. Chay lai voi -Index <so> de chon:"
    for ($i = 0; $i -lt $dirs.Count; $i++) { Write-Host ("  [{0}] {1}" -f $i, (Get-Origin $dirs[$i])) }
    exit 2
}
if ($Index -ge $dirs.Count) { Write-Host "[!!] -Index $Index khong hop le (chi co 0..$($dirs.Count - 1))"; exit 1 }
$d = if ($Index -ge 0) { $dirs[$Index] } else { $dirs[0] }
$origin = Get-Origin $d
$sub = if ([IO.Path]::GetExtension($File) -eq '.mqh') { 'MQL5\Include' } else { 'MQL5\Experts' }
$dest = Join-Path (Join-Path $d.FullName $sub) (Split-Path $File -Leaf)

if ($File -ieq $dest) { Write-Host "[i] File da nam san trong Experts, chi compile lai" }
else {
    if (Test-Path $dest) {
        $bak = Join-Path $d.FullName ('MQL5\Backup_bot\' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
        New-Item -ItemType Directory -Force -Path $bak | Out-Null
        Copy-Item $dest $bak -Force
        Write-Host "[OK] Da sao luu ban cu vao: $bak"
    }
    Copy-Item $File $dest -Force
    Write-Host "[OK] Da chep vao: $dest"
}
if ($sub -eq 'MQL5\Include') { Write-Host "[i] File .mqh khong can compile rieng - compile lai bot dung no"; exit 0 }

$me = Join-Path $origin 'metaeditor64.exe'
if (-not (Test-Path $me)) {
    $me = @(Get-ChildItem 'C:\Program Files', 'C:\Program Files (x86)' -Filter 'metaeditor64.exe' -Recurse -Depth 2 -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName)
}
if (-not $me -or -not (Test-Path $me)) {
    Write-Host "[!!] Khong tim thay metaeditor64.exe. Mo MetaEditor (F4 trong MT5), mo file va bam F7."
    exit 0
}

$ex5 = [IO.Path]::ChangeExtension($dest, '.ex5')
$before = if (Test-Path $ex5) { (Get-Item $ex5).LastWriteTime } else { [datetime]::MinValue }
$log = [IO.Path]::ChangeExtension($dest, '.log')
Remove-Item $log -ErrorAction SilentlyContinue
Start-Process -FilePath $me -ArgumentList "/compile:`"$dest`"", "/log:`"$log`"" -Wait -WindowStyle Hidden

if (Test-Path $log) {
    $txt = Get-Content $log -Encoding Unicode
    if (-not (($txt -join '') -match '[A-Za-z]')) { $txt = Get-Content $log }
    $txt | Select-String 'error|warning|Result' | ForEach-Object { Write-Host "    $_" }
}
$fresh = (Test-Path $ex5) -and ((Get-Item $ex5).LastWriteTime -gt $before)
if ($fresh) {
    Write-Host "[OK] Compile xong: $ex5"
    Write-Host "     Neu bot dang chay tren chart: MT5 tu nap ban moi. Neu chua: Ctrl+N > Expert Advisors > keo vao chart"
} else {
    Write-Host "[!!] Compile LOI - file .ex5 khong duoc tao moi. Xem cac dong error o tren (so dong, ten bien)"
    exit 3
}
