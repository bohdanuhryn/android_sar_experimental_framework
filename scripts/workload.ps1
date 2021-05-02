function RunMonkey 
{
    param (
        [String[]] $Packages,
        [Int32] $DurationMs = 0,
        [Int32] $EventsCount = 100,
        [Boolean] $IgnoreErrors = $true,
        [Boolean] $EnableEvents = $true,
        [Boolean] $EnableSwitches = $true
    )
    [Int32] $eventsDelayMs = $DurationMs / $EventsCount
    $packagesParams = ""
    if ($Packages.Count -gt 0)
    {
        $packagesParams = "-p " + [String]::Join(" -p ", $Packages)
    }

    $throttleParam = ""
    if ($eventsDelayMs -gt 0)
    {
        $throttleParam = "--throttle $eventsDelayMs"
    }

    $ignoreParams = ""
    if ($IgnoreErrors) 
    {
        $ignoreParams = "--ignore-crashes --ignore-timeouts --ignore-security-exceptions --kill-process-after-error"
    }

    $eventsParams = ""
    if ($EnableEvents -and $EnableSwitches)
    {
        #$eventsParams = "--pct-touch 15 --pct-motion 10 --pct-trackball 15 --pct-nav 20 --pct-majornav 15 --pct-syskeys 5 --pct-appswitch 10 --pct-anyevent 5 --pct-flip 2 --pct-pinchzoom 3 --pct-permission 0"
        $eventsParams = "--pct-touch 20 --pct-motion 20 --pct-trackball 15 --pct-nav 20 --pct-majornav 15 --pct-syskeys 0 --pct-appswitch 6 --pct-anyevent 0 --pct-flip 2 --pct-pinchzoom 2"
    }
    elseif ($EnableEvents)
    {
        #$eventsParams = "--pct-touch 15 --pct-motion 10 --pct-trackball 15 --pct-nav 25 --pct-majornav 15 --pct-syskeys 10 --pct-anyevent 5 --pct-flip 2 --pct-pinchzoom 3 --pct-permission 0"
        $eventsParams = "--pct-touch 20 --pct-motion 15 --pct-trackball 15 --pct-nav 20 --pct-majornav 15 --pct-syskeys 5 --pct-anyevent 5 --pct-flip 2 --pct-pinchzoom 3"
    }
    elseif ($EnableSwitches)
    {
        #$eventsParams = "--pct-touch 0 --pct-motion 0 --pct-trackball 0 --pct-nav 0 --pct-majornav 0 --pct-syskeys 0 --pct-appswitch 100 --pct-anyevent 0 --pct-flip 0 --pct-pinchzoom 0 --pct-permission 0"
        $eventsParams = "--pct-touch 0 --pct-motion 0 --pct-trackball 0 --pct-nav 0 --pct-majornav 0 --pct-syskeys 0 --pct-appswitch 100 --pct-anyevent 0 --pct-flip 0 --pct-pinchzoom 0"
    }

    Write-Host "[Workload Generator] all params: $packagesParams -v -v $throttleParam $eventsParams $ignoreParams $EventsCount"

    adb shell monkey $packagesParams -v -v $throttleParam $eventsParams $ignoreParams $EventsCount
}

function RunPackages
{
    param (
        [String[]] $Packages
    )
    foreach ($package in $Packages) 
    {
        adb shell monkey -p $package -c android.intent.category.LAUNCHER 1
    }
}

function KillPackages
{
    param (
        [String[]] $Packages
    )
    foreach ($package in $Packages) 
    {
        #adb shell killall -9 $package
        adb shell am force-stop $package
    }
}