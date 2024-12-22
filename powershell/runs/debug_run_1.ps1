Set-Alias -Name adb -Value c:\Users\Bohdan\AppData\Local\Android\Sdk\platform-tools\adb

. Current-Location\..\scripts\stress.ps1
. Current-Location\..\scripts\workload.ps1
. Current-Location\..\scripts\monitor.ps1

$output = "debug_run_1"

$packages = "com.google.android.calendar", "com.android.contacts"

$intervalsCount = 30

$intervalDurationMs = 30 * 1000

$intervalEventsCount = 60

function RunCleaners
{
    adb logcat -c
}

function RunWorkloadGenerators
{
    KillPackages -Packages $packages
    RunPackages -Packages $packages 
    RunMonkey -Packages $packages -DurationMs $intervalDurationMs -EventsCount $intervalEventsCount
}

function RunMonitors
{
    #DumpsysServiceMonitor -Output $output -Service cpuinfo
    #DumpsysServiceMonitor -Output $output -Service meminfo
    #DumpsysServiceMonitor -Output $output -Service procstats
    #DumpsysServiceMonitor -Output $output -Service batterystats
    DumpsysServiceMonitor -Output $output -Packages $packages -Service gfxinfo -OptionalParams framestats
    DumpsysServiceMonitor -Output $output -Service meminfo -OptionalParams "-c"
    DumpsysServiceMonitor -Output $output -Service graphicsstats -OptionalParams framestats
    LogCatMonitor -Output $output
}

InitOutputDirs -Output $output -Packages $packages

RunStressTest -IntervalsCount $intervalsCount -Cleaner 'RunCleaners' -WorkloadGenerator 'RunWorkloadGenerators' -Monitor 'RunMonitors'