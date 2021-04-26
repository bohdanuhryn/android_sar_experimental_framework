function RunStressTest 
{
    param (
        [Int32] $IntervalsCount,
        [String] $Cleaner,
        [String] $WorkloadGenerator,
        [String] $Monitor
    )
    & $Cleaner
    $i = 0
    while ($i -ne $IntervalsCount)
    {
        Write-Host "Monitor iteration  #$i"
        & $WorkloadGenerator
        & $Monitor
        $i = $i + 1
    }   
}