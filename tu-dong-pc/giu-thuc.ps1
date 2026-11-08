# Giu may thuc (khong tu ngu) cho den khi ngu.ps1 dung tac vu nay.
$sig = '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint esFlags);'
$k = Add-Type -MemberDefinition $sig -Name 'Power' -Namespace 'WyckoffAuto' -PassThru
$ES_CONTINUOUS = [uint32]'0x80000000'
$ES_SYSTEM_REQUIRED = [uint32]'0x00000001'
Add-Content -Path 'C:\WyckoffAuto\nhat-ky.txt' -Value ("{0}  May thuc, bat che do giu thuc" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'))
while ($true) {
    [void]$k::SetThreadExecutionState($ES_CONTINUOUS -bor $ES_SYSTEM_REQUIRED)
    Start-Sleep -Seconds 60
}
