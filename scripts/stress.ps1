function RunStressTest {
    param (
        [Int32] $IntervalsCount,
        [String] $Cleaner,
        [String] $WorkloadGenerator,
        [String] $Monitor,
        [Int32] $WorkloadDuration = 0,
        [Int32] $PauseDuration = 0
    )
    & $Cleaner
    $i = 0
    while ($i -ne $IntervalsCount) {
        Write-Host "Monitor iteration  #$i"
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