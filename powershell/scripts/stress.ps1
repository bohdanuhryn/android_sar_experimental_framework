function RunStressTest {
    param (
        [Int32] $IntervalsCount,
        [String] $Cleaner,
        [String] $WorkloadGenerator,
        [String] $Monitor,
        [Int32] $WorkloadDurationTicks = 0,
        [Int32] $PauseDurationSeconds = 0,
        [String] $OnTimeAction = "",
        [Int32] $ActionTime = 0
    )
    & $Cleaner
    $i = 0
    while ($i -ne $IntervalsCount) {
        Write-Host "Monitor iteration  #$i"
        if (($i -gt 0) -and ($ActionTime -gt 0) -and ($OnTimeAction.Length -gt 0)) {
            $j = $i % $ActionTime
            if ($j -eq 0) {
                & $OnTimeAction
            }
        }
        if (($i -gt 0) -and ($WorkloadDurationTicks -gt 0) -and ($PauseDurationSeconds -gt 0)) {
            if (($i % $WorkloadDurationTicks) -eq 0) {
                Write-Host "Pause begin for $PauseDurationSeconds"
                $sec = 0
                while ($sec -lt $PauseDurationSeconds) {
                    Write-Host "Pause sec = $sec"
                    Start-Sleep -s 25
                    & $Monitor
                    $sec = $sec + 30#TODO: fix pause timing - remove hardcoded 20/30
                }
            } else {
                & $WorkloadGenerator
            }
        } else {
            & $WorkloadGenerator
        }
        & $Monitor
        $i = $i + 1
    }   
}