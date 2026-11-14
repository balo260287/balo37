# ============================================================
#  BAC SI MAY TINH - kham va chua benh cho PC Windows
#  Chay bang file 1-KhamNhanh.bat hoac 2-KhamKy.bat (tu xin quyen Admin)
# ============================================================
param(
    [switch]$KhamKy   # Kham ky: quet toan bo o dia + sua file he thong (SFC/DISM), lau 30-90 phut
)

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$Host.UI.RawUI.WindowTitle = 'Bac Si May Tinh'

$baoCao = Join-Path ([Environment]::GetFolderPath('Desktop')) ("BacSiMayTinh_BaoCao_{0}.txt" -f (Get-Date -Format 'yyyy-MM-dd_HH-mm'))
$tongDonDep = 0

function Ghi([string]$text, [string]$mau = 'White') {
    Write-Host $text -ForegroundColor $mau
    Add-Content -Path $baoCao -Value $text -Encoding UTF8
}
function Buoc([string]$ten) { Ghi ''; Ghi ("=== {0} ===" -f $ten) 'Cyan' }

function Get-KichThuoc([string]$path) {
    if (-not (Test-Path $path)) { return 0 }
    $s = (Get-ChildItem $path -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    if ($s) { return [int64]$s } else { return 0 }
}

function Xoa-NoiDung([string]$path) {
    # Xoa file ben trong thu muc; file dang duoc dung se tu bo qua
    if (-not (Test-Path $path)) { return 0 }
    $truoc = Get-KichThuoc $path
    Get-ChildItem $path -Force -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    $sau = Get-KichThuoc $path
    return [math]::Max(0, $truoc - $sau)
}

function MB([int64]$bytes) { '{0:N1} MB' -f ($bytes / 1MB) }

# ---------- Kiem tra quyen Admin ----------
$laAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $laAdmin) {
    Write-Host 'Can quyen Administrator. Hay chay bang file .bat (no tu xin quyen).' -ForegroundColor Red
    exit 1
}

Ghi '############################################'
Ghi '#         BAC SI MAY TINH - BAT DAU         #'
Ghi '############################################'
Ghi ("Thoi gian : {0}" -f (Get-Date))
Ghi ("May       : {0}" -f $env:COMPUTERNAME)
Ghi ("Che do    : {0}" -f $(if ($KhamKy) { 'KHAM KY (quet toan bo + sua he thong)' } else { 'KHAM NHANH' }))

# ---------- 1. Diet virus bang Windows Defender ----------
Buoc '1. QUET VIRUS (Windows Defender)'
$coDefender = $false
try {
    $st = Get-MpComputerStatus -ErrorAction Stop
    $coDefender = $true
    if (-not $st.AntivirusEnabled -or -not $st.RealTimeProtectionEnabled) {
        Ghi 'CANH BAO: Bao ve thoi gian thuc dang TAT (hoac may dung phan mem diet virus khac).' 'Yellow'
    }
} catch {
    Ghi 'Khong dung duoc Windows Defender tren may nay (co the da cai phan mem diet virus khac). Bo qua buoc quet.' 'Yellow'
}

if ($coDefender) {
    Ghi 'Dang cap nhat du lieu virus moi nhat...'
    try { Update-MpSignature -ErrorAction Stop; Ghi 'Cap nhat xong.' 'Green' }
    catch { Ghi 'Khong cap nhat duoc (kiem tra mang). Van quet bang du lieu hien co.' 'Yellow' }

    $kieu = if ($KhamKy) { 'FullScan' } else { 'QuickScan' }
    Ghi ("Dang quet ({0})... {1}" -f $kieu, $(if ($KhamKy) { 'co the mat 30-90 phut, cu de may chay.' } else { 'khoang 2-10 phut.' }))
    try {
        Start-MpScan -ScanType $kieu -ErrorAction Stop
        Ghi 'Quet xong.' 'Green'
    } catch { Ghi ("Loi khi quet: {0}" -f $_.Exception.Message) 'Red' }

    $moiThreat = Get-MpThreatDetection -ErrorAction SilentlyContinue |
        Where-Object { $_.InitialDetectionTime -gt (Get-Date).AddDays(-1) }
    if ($moiThreat) {
        Ghi ("PHAT HIEN {0} moi de doa! Dang xu ly..." -f @($moiThreat).Count) 'Red'
        foreach ($t in $moiThreat) {
            $ten = (Get-MpThreat -ThreatID $t.ThreatID -ErrorAction SilentlyContinue).ThreatName
            Ghi ("  - {0}  ->  {1}" -f $ten, ($t.Resources -join ', ')) 'Red'
        }
        try { Remove-MpThreat -ErrorAction Stop; Ghi 'Da cach ly / xoa cac moi de doa.' 'Green' }
        catch { Ghi 'Defender da tu xu ly hoac can khoi dong lai may de xoa het.' 'Yellow' }
    } else {
        Ghi 'Khong phat hien virus. May sach!' 'Green'
    }
}

# ---------- 2. Don rac ----------
Buoc '2. DON FILE RAC'
$thuMucRac = @(
    @{ Ten = 'File tam cua ban';          Path = $env:TEMP },
    @{ Ten = 'File tam cua Windows';      Path = "$env:WINDIR\Temp" },
    @{ Ten = 'Bo nho dem Windows Update'; Path = "$env:WINDIR\SoftwareDistribution\Download" },
    @{ Ten = 'Bao cao loi cu';            Path = "$env:ProgramData\Microsoft\Windows\WER\ReportArchive" },
    @{ Ten = 'Bo nho dem thumbnail';      Path = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"; Loc = 'thumbcache_*.db' }
)

# Tam dung Windows Update de xoa duoc bo nho dem cua no
$wu = Get-Service wuauserv -ErrorAction SilentlyContinue
$wuDangChay = $wu -and $wu.Status -eq 'Running'
if ($wuDangChay) { Stop-Service wuauserv -Force -ErrorAction SilentlyContinue }

foreach ($r in $thuMucRac) {
    if ($r.Loc) {
        $files = Get-ChildItem $r.Path -Filter $r.Loc -Force -ErrorAction SilentlyContinue
        $truoc = ($files | Measure-Object Length -Sum).Sum
        $files | Remove-Item -Force -ErrorAction SilentlyContinue
        $sau = (Get-ChildItem $r.Path -Filter $r.Loc -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        $da = [math]::Max(0, [int64]$truoc - [int64]$sau)
    } else {
        $da = Xoa-NoiDung $r.Path
    }
    $tongDonDep += $da
    Ghi ("  {0,-28}: {1}" -f $r.Ten, (MB $da))
}
if ($wuDangChay) { Start-Service wuauserv -ErrorAction SilentlyContinue }

# Cache trinh duyet (chi cache, KHONG dung mat khau / lich su / bookmark)
$cacheTrinhDuyet = @(
    "$env:LOCALAPPDATA\Google\Chrome\User Data\*\Cache\Cache_Data",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\*\Code Cache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\*\Cache\Cache_Data",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\*\Code Cache",
    "$env:LOCALAPPDATA\CocCoc\Browser\User Data\*\Cache\Cache_Data",
    "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles\*\cache2"
)
$daTrinhDuyet = 0
foreach ($p in $cacheTrinhDuyet) {
    foreach ($d in (Get-Item $p -Force -ErrorAction SilentlyContinue)) { $daTrinhDuyet += Xoa-NoiDung $d.FullName }
}
$tongDonDep += $daTrinhDuyet
Ghi ("  {0,-28}: {1}" -f 'Cache trinh duyet', (MB $daTrinhDuyet))

# Thung rac
try {
    $shell = New-Object -ComObject Shell.Application
    $rb = ($shell.NameSpace(10).Items() | ForEach-Object { $_.Size } | Measure-Object -Sum).Sum
    Clear-RecycleBin -Force -ErrorAction Stop
    $tongDonDep += [int64]$rb
    Ghi ("  {0,-28}: {1}" -f 'Thung rac (Recycle Bin)', (MB ([int64]$rb)))
} catch { Ghi '  Thung rac                   : da trong' }

Ghi ("TONG DA DON: {0}" -f (MB $tongDonDep)) 'Green'

# ---------- 3. Mang ----------
Buoc '3. LAM MOI MANG'
ipconfig /flushdns | Out-Null
Ghi 'Da xoa bo nho dem DNS (giup vao web nhanh / het loi trang khong vao duoc).' 'Green'

# ---------- 4. Suc khoe o cung & bo nho ----------
Buoc '4. KIEM TRA SUC KHOE'
Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ne $null -and ($_.Used + $_.Free) -gt 0 } | ForEach-Object {
    $tong = $_.Used + $_.Free
    $phanTram = [math]::Round($_.Free / $tong * 100)
    $mau = if ($phanTram -lt 10) { 'Red' } elseif ($phanTram -lt 20) { 'Yellow' } else { 'Green' }
    Ghi ("  O {0}: con trong {1:N1} GB / {2:N1} GB ({3}%)" -f $_.Name, ($_.Free / 1GB), ($tong / 1GB), $phanTram) $mau
    if ($phanTram -lt 10) { Ghi '    -> O sap day! Nen xoa bot phim/game/file lon khong dung.' 'Red' }
}
try {
    Get-PhysicalDisk -ErrorAction Stop | ForEach-Object {
        $mau = if ($_.HealthStatus -eq 'Healthy') { 'Green' } else { 'Red' }
        $tt = if ($_.HealthStatus -eq 'Healthy') { 'KHOE' } else { "CO VAN DE ($($_.HealthStatus)) - nen sao luu du lieu ngay!" }
        Ghi ("  O cung '{0}' ({1}): {2}" -f $_.FriendlyName, $_.MediaType, $tt) $mau
    }
} catch {}

$os = Get-CimInstance Win32_OperatingSystem
$ramDung = [math]::Round((1 - $os.FreePhysicalMemory / $os.TotalVisibleMemorySize) * 100)
Ghi ("  RAM dang dung: {0}%" -f $ramDung) $(if ($ramDung -gt 85) { 'Yellow' } else { 'Green' })
$uptime = (Get-Date) - $os.LastBootUpTime
if ($uptime.TotalDays -gt 7) {
    Ghi ("  May chua khoi dong lai {0} ngay -> nen Restart de may nhanh hon." -f [int]$uptime.TotalDays) 'Yellow'
}

Ghi ''
Ghi 'Top 5 chuong trinh ngon RAM nhat:'
Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 5 | ForEach-Object {
    Ghi ("  {0,-30} {1}" -f $_.ProcessName, (MB $_.WorkingSet64))
}

Ghi ''
Ghi 'Chuong trinh tu chay khi bat may (nhieu qua se lam may khoi dong cham):'
$startup = Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue
foreach ($s in $startup) { Ghi ("  - {0}" -f $s.Name) }
Ghi '  (Tat bot: Ctrl+Shift+Esc -> tab Startup -> chuot phai -> Disable)' 'DarkGray'

# ---------- 5. Kham ky: sua file he thong ----------
if ($KhamKy) {
    Buoc '5. SUA FILE HE THONG (DISM + SFC)'
    Ghi 'Dang chay DISM (sua kho file goc cua Windows)... co the 10-30 phut.'
    DISM /Online /Cleanup-Image /RestoreHealth | Out-Host
    Ghi 'Dang chay SFC (kiem tra va sua file he thong bi hong)...'
    sfc /scannow | Out-Host
    Ghi 'Don dep thanh phan Windows cu...'
    DISM /Online /Cleanup-Image /StartComponentCleanup | Out-Host
    Ghi 'Xong phan sua he thong.' 'Green'
}

# ---------- Ket thuc ----------
Ghi ''
Ghi '############################################'
Ghi '#     KHAM XONG - MAY CUA BAN DA KHOE!      #'
Ghi '############################################'
Ghi ("Bao cao da luu tai: {0}" -f $baoCao) 'Cyan'
