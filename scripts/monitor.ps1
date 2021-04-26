#adb shell perfetto
#adb shell dumpsys
#adb shell dumpsys procstats --hours 3

function InitOutputDirs
{
    param ([String] $Output)
    # Root dir
    CreateFileIfNotExists -Path ".\output" -Name $Output -Type "directory"
    # BugReports dir
    #CreateFileIfNotExists -Path ".\output\$Output" -Name "bugReports" -Type "directory"
    # LogCat dir
    CreateFileIfNotExists -Path ".\output\$Output" -Name "logcat" -Type "directory"
    # Dumpsys dir
    CreateFileIfNotExists -Path ".\output\$Output" -Name "dumpsys" -Type "directory"
    # ProcTasks dir
    CreateFileIfNotExists -Path ".\output\$Output" -Name "proctasks" -Type "directory"
}

function BugReportsMonitor 
{
    Param([String] $Output)
    Write-Host "RunBugReport call"
    $path = ".\output\$Output\bugReports"
    adb bugreport $path
}

function DumpsysServiceMonitor
{
    Param(
        [String] $Output,
        [String] $Service,
        [String[]] $Packages,
        [String] $OptionalParams = ""
    )
    Write-Host "Dumpsys $Service call"
    $path = ".\output\$Output\dumpsys"
    if ($Packages.Count -gt 0) 
    {
        foreach ($p in $Packages) 
        {
            $name = "$Service-$p.txt"
            $fullPath = "$path\$name"
            CreateFileIfNotExists -Path $path -Name $name -Type "file"
            Get-Date | Out-File -FilePath "$path\$name" -Append
            adb shell dumpsys $Service $p $OptionalParams | Out-File -FilePath $fullPath -Append
        }
    }
    else 
    {
        $name = "$Service.txt"
        $fullPath = "$path\$name"
        CreateFileIfNotExists -Path $path -Name $name -Type "file"
        Get-Date | Out-File -FilePath $fullPath -Append
        adb shell dumpsys $Service $OptionalParams | Out-File -FilePath $fullPath -Append
    }
}

function LogCatMonitor
{
    Param([String] $Output)
    Write-Host "LogCat call"
    $path = ".\output\$Output\logcat\logcat.txt"
    Get-Date | Out-File -FilePath $path -Append
    adb logcat -d -v monotonic | Out-File -FilePath $path -Append
    adb logcat -c
}

function ProcTasksMonitor {
    Param([String] $Output)
    Write-Host "ProcTasks call"
    $path = ".\output\$Output\proctasks\proctasks.txt"
    Get-Date | Out-File -FilePath $path -Append
    $dirs_str = adb shell ls /proc/
    $dirs_str = $dirs_str.Split(' ')
    $dirs_str = @($dirs_str) -match '^\d+$'

    $dirs_str_full = $dirs_str | ForEach-Object { "/proc/" + $_ + "/stat" }

    $res = adb shell cat ($dirs_str_full -join ' ')

    if ($null -ne $res) {
        $res | Out-File -FilePath $path -Append
    }
}

function CreateFileIfNotExists
{
    param (
        $Path,
        $Name,
        $Type
    )
    if (!(Test-Path "$Path\$Name"))
    {
        New-Item -Path $Path -Name $Name -ItemType $Type -Force
    }
}