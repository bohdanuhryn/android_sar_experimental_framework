# PowerShell Scripts — Issue Analysis

Files analysed:
- `powershell/scripts/stress.ps1`
- `powershell/scripts/monitor.ps1`
- `powershell/scripts/workload.ps1`
- `powershell/runs/debug_run_1.ps1`
- `powershell/runs/frames_draw_and_launch_time_comparison_test.ps1`
- `powershell/runs/native_cross_comparison_test.ps1`

---

## Bugs

### B1 — Dot-sourcing uses non-existent `Current-Location` path (all run scripts)
```powershell
. Current-Location\..\scripts\stress.ps1
```
`Current-Location` is not a PowerShell automatic variable. This resolves to a literal directory named `Current-Location` that does not exist, so the dot-source fails at runtime. Should use `$PSScriptRoot`:
```powershell
. "$PSScriptRoot\..\scripts\stress.ps1"
```
**Affects**: all three run scripts.

---

### B2 — Undefined variable `$packagesNativeApps` in `native_cross_comparison_test.ps1`
```powershell
function RunNativeUsageDelaysTest {
    InitOutputDirs -Output $outputNativeMultipleApps -Packages $packagesNativeApps
    RestartPackages -Packages $packagesNativeApps
    ...
}
```
The defined variable is `$packagesNative`; `$packagesNativeApps` is never declared. PowerShell resolves it to `$null`, so `RunNativeUsageDelaysTest` runs with an empty package list. Same function also uses `$outputNativeMultipleApps` instead of `$outputNativeUsageDelays` for output directory name.

---

### B3 — `LogCatMonitor` silently ignores `-OptionalParams` in `frames_draw_and_launch_time_comparison_test.ps1`
```powershell
LogCatMonitor -Output $output1 -OptionalParams "*:I"
```
`LogCatMonitor` is defined with only `[String] $Output` — no `$OptionalParams` parameter. PowerShell silently drops unknown named parameters, so the log level filter `*:I` is never applied and full verbose logcat is captured instead of Info-level only.

---

### B4 — `InitOutputDirs` ignores `-Packages` parameter everywhere
All run scripts call:
```powershell
InitOutputDirs -Output $output -Packages $packages
```
But `InitOutputDirs` is defined as:
```powershell
function InitOutputDirs {
    param ([String] $Output)
```
The `-Packages` argument is silently dropped. This appears to be a leftover from a previous version where per-package subdirectories were created. No harm currently but causes confusion.

---

### B5 — `gfxinfo` not reset between intervals in `debug_run_1.ps1`
```powershell
DumpsysServiceMonitor -Output $output -Packages $packages -Service gfxinfo -OptionalParams framestats
```
Without the `reset` suffix (compare to `"framestats reset"` used in `frames_draw_and_launch_time_comparison_test.ps1`), each gfxinfo dump accumulates data from all previous intervals. The per-interval data is not isolated, making time-series analysis incorrect for this run.

---

### B6 — Pause timing drift in `stress.ps1`
```powershell
Start-Sleep -s 25
& $Monitor
$sec = $sec + 30  # TODO: fix pause timing - remove hardcoded 20/30
```
The loop sleeps 25 s but advances the counter by 30, making each pause tick 5 s shorter than accounted for. A `$PauseDurationSeconds = 1800` pause finishes ~300 s (5 min) early.

---

### B7 — Divide-by-zero in `RunMonkey` when `$EventsCount = 0`
```powershell
[Int32] $eventsDelayMs = $DurationMs / $EventsCount
```
No guard against `$EventsCount = 0`. Throws an uncaught `RuntimeException` immediately.

---

## Design Issues

### D1 — Hardcoded absolute ADB path in all run scripts
```powershell
Set-Alias -Name adb -Value c:\Users\Bohdan\AppData\Local\Android\Sdk\platform-tools\adb
```
Breaks on any machine other than the original author's. Should resolve from `$env:ANDROID_HOME`, `$env:LOCALAPPDATA`, or require `adb` on `$PATH`.

---

### D2 — No ADB device selection (`-s <serial>`)
No script passes `-s <serial>` to any `adb` call. Behaviour is undefined when multiple devices or emulators are connected. ADB returns an error and silently skips the command.

---

### D3 — No timestamp in output directory (monitor.ps1)
`InitOutputDirs` creates `.\output\<name>\` with no timestamp subfolder. Bash version creates `.\output\<name>\<timestamp>\`. Re-running the same experiment appends data into the same files rather than creating a fresh run directory, mixing data from different runs.

---

### D4 — Monkey parameters passed as a string to native executable
```powershell
adb shell monkey $packagesParams -v -v $throttleParam $eventsParams $ignoreParams $EventsCount
```
In PowerShell, `$packagesParams` is a `[String]` like `"-p pkg1 -p pkg2"`. When expanded inline, PowerShell passes the entire string as **one argument** to the `adb` native process, not split by spaces. The command works incidentally because `adb shell` joins all its arguments and sends them to the device shell, which then re-splits — but this relies on undocumented ADB behaviour. The correct approach is a `[String[]]` array with splatting.

---

### D5 — Duplicate monitor call at pause boundary in `stress.ps1`
During a pause iteration, `$Monitor` is called inside the pause loop AND once more unconditionally at the end of every outer iteration:
```powershell
while ($sec -lt $PauseDurationSeconds) {
    Start-Sleep -s 25
    & $Monitor          # called here during pause
    ...
}
# ... then falls through to:
& $Monitor              # called again unconditionally
```
This produces a double monitor snapshot at every pause boundary, duplicating one data point per pause event.

---

### D6 — Monkey event distribution alternatives buried in comments (`workload.ps1`)
```powershell
#$eventsParams = "--pct-touch 15 --pct-motion 10 ..."
$eventsParams = "--pct-touch 20 --pct-motion 20 ..."
```
Alternative event distributions are toggled by commenting/uncommenting. These should be named presets in a config or parameter, not commented-out lines.

---

### D7 — `ReactNative` test defined but has no entry point (`native_cross_comparison_test.ps1`)
```powershell
$outputReactMultipleApps = "react_multiple_apps_test"
$packagesReactMultipleApps = "com.shinetext.shine", ...
```
Variables are declared but no test functions or `switch` cases exist for React Native. The `switch` at the bottom has no option to run it, so these variables are dead code.

---

### D8 — `RunNativeMultipleAppsTest` passes wrong output name to `InitOutputDirs`
```powershell
function RunNativeUsageDelaysTest {
    InitOutputDirs -Output $outputNativeMultipleApps ...  # should be $outputNativeUsageDelays
```
Usage-delays test data is written into the `multiple_apps_test` output directory, making results from both experiments indistinguishable.

---

### D9 — `stress.ps1` has no logging (unlike bash `runner.sh`)
The PowerShell runner uses `Write-Host` only for iteration count and pause state. There is no equivalent of the bash `info_log` function. No timestamps are recorded in the runner output, making it hard to correlate log lines with wall-clock time after the fact.

---

## Parity Gaps vs Bash

| Feature | PowerShell | Bash |
|---------|-----------|------|
| Output directory timestamp | ✗ missing | ✓ |
| `proc_tasks_monitor` | ✓ batched single `adb shell cat` | ✗ one call per PID |
| `dumpsys` optional params | ✓ `$OptionalParams` | ✗ missing |
| Structured logging with timestamps | ✗ | ✓ `logger.sh` |
| ADB path configuration | ✗ hardcoded absolute path | ✓ assumes `adb` on PATH |
| Script sourcing uses reliable path | ✗ broken `Current-Location` | ✓ `$(dirname "$0")` |
