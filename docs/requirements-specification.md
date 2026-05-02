# Requirements Specification — Android SAR Experimental Framework v2

## 1. Project Context

The framework automates stress testing of Android devices to study **software aging and rejuvenation (SAR)**. An experiment consists of N iterations; each iteration runs a workload (Android Monkey), then collects system metrics via ADB. Collected data feeds the `android_sar_dataset_generator` pipeline to produce time-series CSVs for statistical analysis.

---

## 2. Technology Recommendation — Configuration & Runner App

### Requirements for the app
- Build and persist experiment configuration (packages, iteration count, monitor selection, output directory, target device)
- Launch experiments and stream live terminal output into the UI
- Select connected ADB device from a list
- Cross-platform: macOS, Linux, Windows

### Options evaluated

| Option | Pros | Cons |
|--------|------|------|
| **Kotlin + Compose for Desktop** | Same language as dataset_generator; JVM ProcessBuilder for real-time output; single binary; mature tooling | Somewhat verbose UI code |
| Electron + React | Best terminal embedding (xterm.js + node-pty); rich UI ecosystem | Heavy bundle (~150 MB); two runtimes |
| Tauri + React | Small bundle; web frontend | Requires Rust for backend |
| Python + PyQt6 | Quick to build; QProcess streams output | Different language from rest of project |

**Recommendation: Kotlin + Compose for Desktop (JetBrains Multiplatform)**
Rationale: consistent with the existing Kotlin codebase, runs on all three platforms without extra runtimes, and `ProcessBuilder` / `Process.inputStream` gives direct real-time streaming of stdout/stderr into a composable text area. The app can be built in the same IntelliJ project workspace.

### Real-time terminal output in the app
`ProcessBuilder` with `redirectErrorStream(true)` and a coroutine reading `inputStream` line-by-line into a `StateFlow<String>` works well. The UI renders a scrollable `LazyColumn` of log lines — no external terminal emulator needed for this use case. A proper embedded terminal (e.g. JediTerm, which IntelliJ itself uses) can be added later if full ANSI rendering is required.

---

## 3. New Monitoring Factors

Based on `todo.txt` and Android Vitals documentation, the following factors are not yet captured by scripts:

| Factor | Source | Collection method |
|--------|--------|-------------------|
| **ANR (Application Not Responding)** | logcat tag `ActivityManager` | Filter `adb logcat -d` for `ANR in` lines |
| **Crashes / Exceptions** | logcat | Filter for `FATAL EXCEPTION`, `E AndroidRuntime` |
| **Battery Power** | `dumpsys batterystats` | `dumpsys_service_monitor "batterystats"` per interval, or Battery Historian export at end |
| **Wakelock abuse** | `dumpsys batterystats` | Same collection, post-processed |
| **Frozen frames** | `dumpsys gfxinfo <pkg> framestats` | Already collected; needs dedicated parser for frozen-frame threshold (>700 ms) |

Already collected but worth verifying completeness:
- Launch Time — logcat `ActivityManager: Displayed` lines ✓
- Frame timing — `gfxinfo framestats` ✓
- Memory (PSS, free, cached) — `meminfo -c` ✓
- Garbage Collector pauses — logcat `art` tag ✓
- Process stats — `/proc/<pid>/stat` ✓

---

## 4. Directory Structure

### Proposed structure
```
android_sar_experimental_framework/
├── app/                        # Compose Desktop config & runner app (new)
│   └── src/
├── scripts/
│   ├── bash/                   # macOS / Linux
│   │   ├── runner.sh
│   │   ├── monitor.sh
│   │   ├── workload.sh
│   │   └── logger.sh
│   └── powershell/             # Windows
│       ├── stress.ps1
│       ├── monitor.ps1
│       └── workload.ps1
├── experiments/                # Experiment definition files (new, replaces runs/)
│   ├── example.sh              # Bash entry point
│   ├── example.ps1             # PowerShell entry point
│   └── example.json            # Machine-readable config (consumed by app)
├── docs/
└── output/                     # gitignored
```

The `experiments/` directory replaces separate `bash/runs/` and `powershell/runs/` directories. Each experiment is defined once as a `.json` config; the app generates the corresponding `.sh` / `.ps1` invocation from it.

---

## 5. Cross-OS Script Parity

The Bash and PowerShell implementations have drifted. The following features exist in PowerShell but are missing from Bash:

| Feature | PowerShell | Bash |
|---------|-----------|------|
| `gfxinfo reset` after collection | ✓ `OptionalParams "framestats reset"` | ✗ no optional params support in `dumpsys_service_monitor` |
| Batched `/proc` stat reads | ✓ single `adb shell cat` with all paths | ✗ one `adb shell cat` per PID (very slow) |
| ADB device selection (`-s`) | ✗ | ✗ |

Both versions need ADB device targeting added (`-s <serial>`) to support multi-device labs.

---

## 6. Bash Script Issues and Improvements

### runner.sh
1. **Bug — on-time action never fires**: variable is stored as `on_time_action_function` but referenced as `$on_time_action` (different name). The block at line 90 never executes.
2. **Bug — pause timing drift**: loop sleeps 25 s but increments counter by 30 — each tick is 5 s short. The TODO comment acknowledges this.
3. **Flag inconsistency**: `-i` is documented as `--intervals` but the variable is named `iterations_count`; semantically these are iterations, not intervals.
4. **No guard on empty workload/monitor**: `eval ""` runs silently rather than being skipped.

### monitor.sh
5. **Bug — `dumpsys_service_monitor` drops optional params**: the function signature takes `$@` as packages, so extra args like `"framestats"` get treated as package names. PowerShell version has a dedicated `OptionalParams` parameter. Bash version needs the same.
6. **Race condition in `logcat_monitor`**: `adb logcat -c` (clear) runs immediately after `-d` (dump). On a slow connection the clear can outrace the dump completion.
7. **Slow `/proc` collection**: `proc_tasks_monitor` shells into the device once per PID. A single `adb shell cat /proc/1/stat /proc/2/stat ...` call (as done in PowerShell) is 10–100× faster for hundreds of processes.
8. **Global mutable `OUTPUT_DIR_PATH`**: makes it impossible to run two experiments in the same shell session without re-sourcing.
9. **No ADB device selection**: all `adb` calls lack `-s <serial>`, so behaviour is undefined when multiple devices are connected.

### workload.sh
10. **Bug — double `-p` flag**: `packages_params="-p "$(printf " -p %s" "${packages[@]}")"` produces `-p  -p pkg1 -p pkg2` — the leading `-p` is duplicated, causing Monkey to fail parsing.
11. **Inconsistent argument style**: `run_packages` and `kill_packages` accept a plain string `$1` and re-split it, while `run_monkey` uses named flags. All three should use a consistent pattern.

### General
12. **Hardcoded ADB path in PowerShell runs**: `Set-Alias -Name adb -Value c:\Users\Bohdan\...` must be replaced with a configurable path or PATH resolution.
13. **No ADB connection validation**: none of the scripts check `adb devices` before starting, so failures are silent until a data file is found empty.
14. **No experiment config file format**: all parameters (packages, iteration counts, monitor selection) are hardcoded in each run script. A JSON/YAML config format would allow the app to drive experiments without generating shell code.

---

## 7. App Feature Requirements

### F1 — Device selection
- List connected ADB devices (`adb devices`)
- Allow user to select target device; pass `-s <serial>` to all ADB calls
- Show device model and Android version in the list

### F2 — Experiment configuration
- Select monitored packages (input list or browse installed packages via `adb shell pm list packages`)
- Set iteration count, workload duration, pause duration, on-time action interval
- Toggle individual monitors on/off: logcat, gfxinfo, meminfo, graphicsstats, procstats, batterystats, proctasks, bugreport
- Set optional params per monitor (e.g. `framestats`, `reset`, `-c`)
- Select output directory
- Save / load configuration as JSON

### F3 — Experiment execution
- Generate and invoke the appropriate shell script for the host OS
- Stream stdout/stderr in real-time into a scrollable log pane
- Show per-iteration progress (current / total)
- Allow stopping the experiment gracefully (SIGINT / Stop-Process)

### F4 — Output browsing
- Show collected output directory tree after experiment completes
- Display file sizes and timestamps

---

## 8. Out of Scope (v2)

- Automated analysis or visualization of collected data (handled by `android_sar_dataset_generator`)
- Wireless ADB pairing UI
- Multi-device parallel experiments
