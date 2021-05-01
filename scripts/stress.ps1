function RunStressTest {
    param (
        [Int32] $IntervalsCount,
        [String] $Cleaner,
        [String] $WorkloadGenerator,
        [String] $Monitor,
        [Int32] $WorkloadDuration = 0,
        [Int32] $PauseDuration = 0,
        [String] $OnTimeAction = "",
        [Int32] $ActionTime = 0
    )
    & $Cleaner
    $i = 0
    while ($i -ne $IntervalsCount) {
        Write-Host "Monitor iteration  #$i"
        if ($i -gt 0 -and $ActionTime -gt 0 -and $OnTimeAction.Length -gt 0) {
            $j = $i % $ActionTime
            if ($j -eq 0) {
                & $OnTimeAction
            }
        }
        if (($WorkloadDuration -gt 0) -and ($PauseDuration -gt 0)) {
            $j = $i % ($WorkloadDuration + $PauseDuration)
            if ($j -lt $WorkloadDuration) {
                & $WorkloadGenerator
            }
        } else {
            & $WorkloadGenerator
        }
        & $Monitor
        $i = $i + 1
    }   
}