#$pid_max = adb shell cat /proc/sys/kernel/pid_max
#$pid_max = [int32]$pid_max
#Write-Host $pid_max

$dirs_str = adb shell ls /proc/
$dirs_str = $dirs_str.Split(' ')
$dirs_str = @($dirs_str) -match '^\d+$'
Write-Host "Task dirs: $dirs_str"

$dirs_str_full = $dirs_str | ForEach-Object { "/proc/" + $_ + "/stat" }

adb shell cat ($dirs_str_full -join ' ')

#for ($i = 0; $i -lt $dirs_str.Length; $i++) {
#    $v = $dirs_str[$i]
#    $res = adb shell cat /proc/$v/stat
#    Write-Host $res
#}