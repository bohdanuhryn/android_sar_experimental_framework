Set-Alias -Name adb -Value c:\Users\Bohdan\AppData\Local\Android\Sdk\platform-tools\adb

. Current-Location\..\scripts\stress.ps1
. Current-Location\..\scripts\workload.ps1
. Current-Location\..\scripts\monitor.ps1

$packages = "com.google.android.youtube", "com.android.contacts", "com.android.chrome", "com.android.camera", "com.google.android.apps.photos"

$intervalsCount1 = 400
$intervalsCount2 = 500

$intervalDurationMs = 30 * 1000

$intervalEventsCount1 = 80
$intervalEventsCount2 = 100

$output1 = "user_perceived_response_metrics_with_forced_restarts_test"
$output2 = "user_perceived_response_metrics_test"

function RunCleaners
{
    adb logcat -c
    foreach ($p in $Packages)
    {
        adb shell dumpsys gfxinfo $p reset
    }
}

function RunWorkloadGenerators1
{
    KillPackages -Packages $packages
    RunPackages -Packages $packages 
    RunMonkey -Packages $packages -DurationMs $intervalDurationMs -EventsCount $intervalEventsCount1
}

function RunWorkloadGenerators2
{
    RunMonkey -Packages $packages -DurationMs $intervalDurationMs -EventsCount $intervalEventsCount2
}

function RunMonitors1
{
    DumpsysServiceMonitor -Output $output1 -Packages $packages -Service gfxinfo -OptionalParams "framestats reset"
    DumpsysServiceMonitor -Output $output1 -Service meminfo -OptionalParams "-c"
    DumpsysServiceMonitor -Output $output1 -Service graphicsstats -OptionalParams framestats
    LogCatMonitor -Output $output1 -OptionalParams "*:I"
}

function RunMonitors2
{
    DumpsysServiceMonitor -Output $output2 -Packages $packages -Service gfxinfo -OptionalParams "framestats reset"
    DumpsysServiceMonitor -Output $output2 -Service meminfo -OptionalParams "-c"
    DumpsysServiceMonitor -Output $output2 -Service graphicsstats -OptionalParams framestats
    LogCatMonitor -Output $output2 -OptionalParams "*:I"
}

InitOutputDirs -Output $output1 -Packages $packages
InitOutputDirs -Output $output2 -Packages $packages

#RunStressTest -IntervalsCount $intervalsCount1 -Cleaner 'RunCleaners' -WorkloadGenerator 'RunWorkloadGenerators1' -Monitor 'RunMonitors1'

RunStressTest -IntervalsCount $intervalsCount2 -Cleaner 'RunCleaners' -WorkloadGenerator 'RunWorkloadGenerators2' -Monitor 'RunMonitors2'