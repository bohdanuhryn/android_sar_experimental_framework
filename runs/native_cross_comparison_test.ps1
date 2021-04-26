Set-Alias -Name adb -Value c:\Users\Bohdan\AppData\Local\Android\Sdk\platform-tools\adb

. Current-Location\..\scripts\stress.ps1
. Current-Location\..\scripts\workload.ps1
. Current-Location\..\scripts\monitor.ps1

$packagesFlutter = "com.emkore.apps.cryptograph", "com.reflectlyApp", "com.hamilton.app"
$packagesReact = "com.shinetext.shine", "com.pinterest", "com.skype.raider"

$outputFlutterMultipleApps = "flutter_multiple_apps_test"
$outputFlutterSingleApp = "flutter_single_app_test"
$outputFlutterUsageWithGaps = "flutter_usage_with_gaps_test"

$outputReactMultipleApps = "react_multiple_apps_test"
$outputReactSingleApp = "react_single_app_test"
$outputReactUsageWithGaps = "react_usage_with_gaps_test"

$intervalsCount = 500

$intervalDurationMs = 60 * 1000

$intervalEventsCount = 200

function RunCleaners
{
    param ([String[]] $Packages)
    adb logcat -c
    foreach ($p in $Packages)
    {
        adb shell dumpsys gfxinfo $p reset
    }
}

function RunPackagesInitial
{
    param ([String[]] $Packages)
    KillPackages -Packages $Packages
    RunPackages -Packages $Packages
}

function RunWorkloadGenerators
{
    param ([String[]] $Packages)
    RunMonkey -Packages $Packages -DurationMs $intervalDurationMs -EventsCount $intervalEventsCount
}

function RunMonitors
{
    param (
        [String] $Output,
        [String[]] $Packages
    )
    DumpsysServiceMonitor -Output $Output -Packages $Packages -Service gfxinfo -OptionalParams "framestats reset"
    DumpsysServiceMonitor -Output $Output -Service meminfo -OptionalParams "-c"
    DumpsysServiceMonitor -Output $Output -Service graphicsstats -OptionalParams framestats
    LogCatMonitor -Output $Output -OptionalParams "*:I"
    ProcTasksMonitor -Output $Output
}

$outputNativeMultipleApps = "native_multiple_apps_test"
$packagesNativeMultipleApps = "com.google.android.youtube", "com.android.chrome", "com.android.camera", "com.google.android.apps.photos"
function RunNativeMultipleAppsCleaners { RunCleaners -Packages $packagesNativeMultipleApps }
function RunNativeMultipleAppsWorkloadGenerators { RunWorkloadGenerators -Packages $packagesNativeMultipleApps }
function RunNativeMultipleAppsMonitors { RunMonitors -Output $outputNativeMultipleApps -Packages $packagesNativeMultipleApps }
function RunNativeMultipleAppsTest
{
    InitOutputDirs -Output $outputNativeMultipleApps -Packages $packagesNativeMultipleApps
    RunPackagesInitial -Packages $packagesNativeMultipleApps
    RunStressTest -IntervalsCount $intervalsCount -Cleaner 'RunNativeMultipleAppsCleaners' -WorkloadGenerator 'RunNativeMultipleAppsWorkloadGenerators' -Monitor 'RunNativeMultipleAppsMonitors'   
}

function RunNativeSingleAppTest
{
    $packages = "com.android.chrome"
    $output = "native_single_app_test"
    InitOutputDirs -Output $output -Packages $packages
    RunPackages -Packages $packages
    $RunCleaners = { RunCleaners -Packages $packages }
    $RunWorkloadGenerators = { RunWorkloadGenerators -Packages $packages }
    $RunMonitors = { RunMonitors -Outputs $output -Packages $packages }
    RunStressTest -IntervalsCount $intervalsCount -Cleaner $RunCleaners -WorkloadGenerator $RunWorkloadGenerators -Monitor $RunMonitors   
}

function RunNativeUsageWithGaps
{
    $packages = "com.android.chrome"
    $output = "native_usage_with_gaps_test"
    InitOutputDirs -Output $output -Packages $packages
    RunPackages -Packages $packages
    $RunCleaners = { RunCleaners -Packages $packages }
    $RunWorkloadGenerators = { RunWorkloadGenerators -Packages $packages }
    $RunMonitors = { RunMonitors -Outputs $output -Packages $packages }
    RunStressTest -IntervalsCount $intervalsCount -Cleaner $RunCleaners -WorkloadGenerator $RunWorkloadGenerators -Monitor $RunMonitors   
}

RunNativeMultipleAppsTest
