Set-Alias -Name adb -Value c:\Users\Bohdan\AppData\Local\Android\Sdk\platform-tools\adb

. Current-Location\..\scripts\stress.ps1
. Current-Location\..\scripts\workload.ps1
. Current-Location\..\scripts\monitor.ps1

function RunCleaners {
    param ([String[]] $Packages)
    adb logcat -c
    foreach ($p in $Packages) {
        adb shell dumpsys gfxinfo $p reset
    }
}

function RestartPackages {
    param ([String[]] $Packages)
    KillPackages -Packages $Packages
    RunPackages -Packages $Packages
}

function RunWorkloadGenerators {
    param ([String[]] $Packages)
    RunMonkey -Packages $Packages -DurationMs 60000 -EventsCount 200
}

function RunMonitors {
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

### Native

$packagesNative = "com.google.android.youtube", "com.android.chrome", "com.android.camera", "com.google.android.apps.photos", "com.android.contacts"
$outputNativeMultipleApps = "native_multiple_apps_test"
$outputNativeUsageDelays = "native_usage_delays_test"
function RestartNativeApps { RestartPackages -Packages $packagesNative }
function RunNativeCleaners { RunCleaners -Packages $packagesNative }
function RunNativeWorkload { RunWorkloadGenerators -Packages $packagesNative }
function RunNativeMultipleAppsMonitor { RunMonitors -Output $outputNativeMultipleApps -Packages $packagesNative }
function RunNativeUsageDelaysMonitor { RunMonitors -Output $outputNativeUsageDelays -Packages $packagesNative }
function RunNativeMultipleAppsTest {
    InitOutputDirs -Output $outputNativeMultipleApps -Packages $packagesNative
    RestartPackages -Packages $packagesNative
    RunStressTest -IntervalsCount 600 -Cleaner 'RunNativeCleaners' -WorkloadGenerator 'RunNativeWorkload' -Monitor 'RunNativeMultipleAppsMonitor' -ActionTime 200 -OnTimeAction 'RestartNativeApps'
}
function RunNativeUsageDelaysTest {
    InitOutputDirs -Output $outputNativeMultipleApps -Packages $packagesNativeApps
    RestartPackages -Packages $packagesNativeApps
    RunStressTest -IntervalsCount 400 -Cleaner 'RunNativeCleaners' -WorkloadGenerator 'RunNativeWorkload' -Monitor 'RunNativeUsageDelaysMonitor' -ActionTime 150 -OnTimeAction 'RestartNativeApps' -WorkloadDurationTicks 100 -PauseDurationSeconds 1800
}

### Flutter

$packagesFlutter = "com.reflectlyApp", "com.hamilton.app", "com.ebay.motorsapp", "com.spotlightsix.zentimerlite2", "com.mgmresorts.mgmresorts"#,"com.grab.merchant", "com.google.stadia.android"
$outputFlutterMultipleApps = "flutter_multiple_apps_test"
$outputFlutterUsageDelays = "flutter_usage_delays_test"
function RestartFlutterApps { RestartPackages -Packages $packagesFlutter }
function RunFlutterCleaners { RunCleaners -Packages $packagesFlutter }
function RunFlutterWorkload { RunWorkloadGenerators -Packages $packagesFlutter }
function RunFlutterMultipleAppsMonitor { RunMonitors -Output $outputFlutterMultipleApps -Packages $packagesFlutter }
function RunFlutterUsageDelaysMonitor { RunMonitors -Output $outputFlutterUsageDelays -Packages $packagesFlutter }
function RunFlutterMultipleAppsTest {
    InitOutputDirs -Output $outputFlutterMultipleApps -Packages $packagesFlutter
    RestartPackages -Packages $packagesFlutter
    RunStressTest -IntervalsCount 600 -Cleaner 'RunFlutterCleaners' -WorkloadGenerator 'RunFlutterWorkload' -Monitor 'RunFlutterMultipleAppsMonitor'  -ActionTime 200 -OnTimeAction 'RestartFlutterApps'
}
function RunFlutterUsageDelaysTest {
    InitOutputDirs -Output $outputFlutterUsageDelays -Packages $packagesFlutter
    RestartPackages -Packages $packagesFlutter
    RunStressTest -IntervalsCount 400 -Cleaner 'RunFlutterCleaners' -WorkloadGenerator 'RunFlutterWorkload' -Monitor 'RunFlutterUsageDelaysMonitor' -ActionTime 150 -OnTimeAction 'RestartFlutterApps' -WorkloadDurationTicks 100 -PauseDurationSeconds 1800 
}

### React Native

$outputReactMultipleApps = "react_multiple_apps_test"
$packagesReactMultipleApps = "com.shinetext.shine", "com.pinterest", "com.cleevio.spendee", "com.myntra.android"#, "com.edutapps.maphi"

### Entry point

Write-Host "Run test:
    - native   multiple apps  (1)
    - native   usage delay    (11)
    - flutter  multiple apps  (2)
    - flutter  usage delay    (22)"
$run_code = Read-Host -Prompt 'Input run code:'

switch ($run_code) {
    1 { RunNativeMultipleAppsTest; Break }
    11 { RunNativeUsageDelaysTest; Break }
    2 { RunFlutterMultipleAppsTest; Break }
    22 { RunFlutterUsageDelaysTest; Break }
    Default { Write-Host "Ooops! :)" }
}
