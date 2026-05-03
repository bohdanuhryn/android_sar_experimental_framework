# Bash Scripts — Detailed Specification

Scripts live in `scripts/bash/`. Experiment entry points in `experiments/*.sh` source them.

---

## Conventions

- All functions accept named parameters (`-x | --long-name value`) unless they take a single obvious positional arg.
- ADB device targeting is controlled by a single exported variable `ADB_SERIAL`. When set, every `adb` invocation in every script uses `adb -s "$ADB_SERIAL"`. When unset, `adb` uses the only connected device (or errors if multiple are connected).
- Functions write nothing to stdout except via `log_*` helpers. Data written to files uses `>>` (append), never `>`.
- Every function returns a non-zero exit code on error and logs the reason via `log_error`.

---

## 1. `logger.sh`

Provides logging helpers used by all other scripts.

### Functions

#### `logger(level, context, message)`

Formats and prints one log line.

- Output format: `[LEVEL] context (ISO-8601 timestamp): message`
- Writes to stdout.
- If `LOG_FILE` is set, also appends to that path.

#### `log_info(context, message)`

Logs an informational message.

#### `log_warn(context, message)`

Logs a warning. Writes to stdout, stderr, and `LOG_FILE` (if set).

#### `log_error(context, message)`

Logs an error. Writes to stdout, stderr, and `LOG_FILE` (if set).

#### `log_debug(context, message)`

Logs a debug message. Only emits output when `DEBUG=1` is set in the environment.

### Environment variables consumed

| Variable   | Default | Description                                          |
|------------|---------|------------------------------------------------------|
| `LOG_FILE` | unset   | If set, all log output is also appended to this path |
| `DEBUG`    | unset   | Set to `1` to enable `log_debug` output              |

---

## 2. `adb.sh`

Centralizes ADB device management. All other scripts source this file instead of calling `adb` directly for device-sensitive operations. Guards against double-sourcing via `_ADB_SH_LOADED`.

Sources `logger.sh` internally — callers do not need to source `logger.sh` separately before `adb.sh`.

### Public functions

#### `adb_cmd(...args)`

Transparent wrapper around `adb`. When `ADB_SERIAL` is set, injects `-s "$ADB_SERIAL"` before all other arguments. When unset, calls `adb` as-is.

```bash
adb_cmd shell dumpsys meminfo   # → adb -s <serial> shell dumpsys meminfo
adb_cmd logcat -d               # → adb -s <serial> logcat -d
```

Returns the exit code of the underlying `adb` call. All other scripts call `adb_cmd` instead of `adb` directly.

#### `adb_check_connection()`

Validates that a usable device is available. Intended to be called once at the start of an experiment (called by `runner` automatically when using `runner.sh`).

- If `ADB_SERIAL` is set: checks that the exact serial appears in `adb devices` with state `device`. Logs an error and returns `1` if not found or not in `device` state.
- If `ADB_SERIAL` is unset: counts lines in `adb devices` with state `device`. Returns `1` with a descriptive error if the count is zero ("no device connected") or greater than one ("multiple devices — set ADB_SERIAL").
- Logs an info message and returns `0` on success.

#### `adb_list_devices()`

Prints the serial of every connected device that is in `device` state, one per line. Excludes `offline` and `unauthorized` entries, and strips the state suffix — serials only.

Used by experiment scripts and the GUI app to populate device selection.

```bash
$ adb_list_devices
emulator-5554
R3CN90FDEAJ
```

### Environment variables

| Variable     | Default | Description                                                                                                                                                                      |
|--------------|---------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `ADB_SERIAL` | unset   | Target device serial. When set, every `adb_cmd` call targets this device via `-s`. Set by the experiment script, `runner --serial`, or `emulator_set_serial` before any ADB call |

---

## 3. `logger.sh` + `adb.sh` sourcing order

Every script that uses ADB sources in this order:

```bash
source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/adb.sh"
```

`BASH_SOURCE[0]` is used instead of `$0` so that the path resolves to the script's own directory regardless of which entry-point script sourced it.

`runner.sh`, `monitor.sh`, and `workload.sh` all source both files.

---

## 4. `workload.sh`

Provides functions for generating workload on the target Android device. Sources `adb.sh` (and transitively `logger.sh`) — no additional sourcing needed by callers.

### Workload functions

#### `run_monkey`

Launches Android Monkey on the target device.

**Parameters:**

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `-p` / `--packages` | string (repeatable) | — | Package name to target. Pass once per package |
| `-d` / `--duration` | integer (ms) | `0` | Total run duration. Combined with `--events` to compute `--throttle`. Omitted when `0` |
| `-e` / `--events` | integer | `0` | Total number of events. Combined with duration to compute inter-event delay |
| `-i` / `--ignore-errors` | bool | `true` | Adds `--ignore-crashes --ignore-timeouts --ignore-security-exceptions --kill-process-after-error` |
| `--event-preset` | string | `mixed` | Named event distribution preset (see below) |

**Event distribution presets:**

| Preset | Description | Distribution |
|--------|-------------|--------------|
| `mixed` | Touch, motion, navigation, minor app switches | touch 20, motion 20, trackball 15, nav 20, majornav 15, syskeys 0, appswitch 6, anyevent 0, flip 2, pinchzoom 2 |
| `gestures` | Touch and motion heavy, no app switches | touch 20, motion 15, trackball 15, nav 20, majornav 15, syskeys 5, anyevent 5, flip 2, pinchzoom 3 |
| `switches` | App switching only | appswitch 100, all others 0 |

An unknown preset name logs an error via `log_error` and returns `1`. New presets can be added to the `case` block without changing the function interface.

**Behavior:**
1. If both `duration > 0` and `events > 0`, compute `--throttle = duration / events`. Otherwise `--throttle` is omitted.
2. Build `-p pkg1 -p pkg2 ...` list via `printf -- '-p %s '`.
3. Log the full constructed Monkey command via `log_info`.
4. Call `adb_cmd shell monkey ...` and return its exit code.

---

#### `run_packages`

Launches the default launcher activity of each package.

**Parameters:** `"$@"` — package names as separate arguments.

**Behavior:**
- Logs each launch attempt via `log_info`.
- For each package: `adb_cmd shell monkey -p "$package" -c android.intent.category.LAUNCHER 1`.

---

#### `kill_packages`

Force-stops each package.

**Parameters:** `"$@"` — package names as separate arguments.

**Behavior:**
- Logs each stop attempt via `log_info`.
- For each package: `adb_cmd shell am force-stop "$package"`.

---

## 5. `monitor.sh`

Provides functions that collect system data from the device and append it to output files.

### Current state
Five functions: `init_output_dirs`, `logcat_monitor`, `dumpsys_service_monitor`, `proc_tasks_monitor`, `bug_reports_monitor`.

### Output directory contract

`init_output_dirs` must be called once before any monitor function. It sets the global `OUTPUT_DIR_PATH` used by all monitors. The layout it creates:

```
output/<name>/<YYYY-MM-DD_HH-MM-SS>/
├── logcat/
│   └── logcat.txt
├── dumpsys/
│   ├── meminfo.txt
│   ├── gfxinfo-<package>.txt
│   └── ...
├── proctasks/
│   └── proctasks.txt
├── batterystats/          (new)
│   └── batterystats.txt
└── bugReports/
```

Each monitor appends a timestamp separator line before each data snapshot so intervals can be distinguished during parsing:
```
=== 2025-01-15 14:32:00 ===
<data>
```

### Required functions

#### `init_output_dirs(name)`

Creates the output directory tree for one experiment run.

**Parameters:**
- `$1` — experiment name (used as directory name under `./output/`)

**Behavior:**
- Sets `OUTPUT_DIR_PATH="./output/$1/$(date +"%Y-%m-%d_%H-%M-%S")"`.
- Creates subdirectories: `logcat/`, `dumpsys/`, `proctasks/`, `batterystats/`, `bugReports/`.
- Logs the resolved path.

---

#### `dumpsys_service_monitor`

Collects output of `adb shell dumpsys <service>` and appends to a file.

**Parameters:**

| Flag | Type | Description |
|------|------|-------------|
| `-s` / `--service` | string | dumpsys service name (e.g. `gfxinfo`, `meminfo`, `procstats`) |
| `-p` / `--package` | string (repeatable) | Package to pass to the service. Omit for services that don't take a package |
| `-o` / `--options` | string | Extra flags appended after the package name (e.g. `framestats`, `reset`, `-c`, `framestats reset`) |

**Current bug:** the third positional argument (options like `"framestats"`) is absorbed into the packages array. Named flags fix this.

**Behavior:**
- If packages provided: for each package, append to `$OUTPUT_DIR_PATH/dumpsys/<service>-<package>.txt`.
- If no packages: append to `$OUTPUT_DIR_PATH/dumpsys/<service>.txt`.
- Separator line written before each snapshot.
- Calls `adb_cmd shell dumpsys "$service" ["$package"] [$options]`.

**Example calls:**
```bash
dumpsys_service_monitor -s gfxinfo -p com.android.chrome -p com.android.contacts -o "framestats reset"
dumpsys_service_monitor -s meminfo -o "-c"
dumpsys_service_monitor -s graphicsstats -o "framestats"
dumpsys_service_monitor -s batterystats
```

---

#### `logcat_monitor`

Dumps current logcat buffer to file and clears it.

**Parameters:** none.

**Current bug:** `adb logcat -c` is called immediately after `-d`, risking a race condition on slow connections.

**Behavior:**
1. Append separator + `adb_cmd logcat -d -v monotonic` to `logcat/logcat.txt`.
2. Wait for the dump to complete (the pipe must flush before clearing).
3. `adb_cmd logcat -c` to clear the buffer.

**Note:** logcat dump and clear are inherently sequential — the implementation must ensure step 1 fully completes before step 3.

---

#### `proc_tasks_monitor`

Reads `/proc/<pid>/stat` for all running processes and appends to file.

**Current bug:** one `adb shell cat` call per PID — very slow for hundreds of processes.

**Behavior:**
1. Get list of numeric PIDs: `adb_cmd shell ls /proc/ | grep '^[0-9]*$'`
2. Construct full paths: `/proc/<pid>/stat` for each PID.
3. Issue a **single** `adb_cmd shell cat /proc/1/stat /proc/2/stat ...` with all paths.
4. Append separator + output to `proctasks/proctasks.txt`.

**Constraint:** the argument list can exceed shell limits for devices with many processes. Batch into groups of 200 PIDs if needed.

---

#### `batterystats_monitor` *(new)*

Collects battery statistics.

**Parameters:** none.

**Behavior:**
- Append `adb_cmd shell dumpsys batterystats` to `batterystats/batterystats.txt`.
- Battery stats accumulate since last reset by default, which is correct for aging analysis.

---

#### `bug_reports_monitor`

Captures a full bug report.

**Parameters:** none.

**Behavior:**
- Calls `adb_cmd bugreport "$OUTPUT_DIR_PATH/bugReports"`.
- Intended for use at the start and end of an experiment, not every iteration (it is slow and produces large files).

---

#### `list_installed_packages()` *(new)*

Utility, not a monitor. Lists installed packages on the device. Used by the GUI app to populate the package selection list.

**Behavior:**
- `adb_cmd shell pm list packages` stripped of the `package:` prefix, one package per line.

---

## 6. `runner.sh`

The experiment orchestrator. Defines the `runner` function that is the entry point for every experiment script.

### Current state
One function `runner` with eight named parameters.

### Bug fixes required

| Bug | Location | Fix |
|-----|----------|-----|
| On-time action never fires | line 90: `$on_time_action` | Change to `$on_time_action_function` to match the variable declared at line 31 |
| Pause timing drift | line 105–107: sleep 25, increment 30 | Use the same value for both: `sleep 30; sec=$((sec + 30))` |
| Flag name mismatch | `-i / --intervals` parsed but variable named `iterations_count` | Rename flag to `-i / --iterations` |
| Empty eval | `eval ""` when function unset | Guard all `eval` calls with `[[ -n $var ]]` |
| Monitor called twice at pause boundary | end of each outer iteration | During a pause period, the final outer `eval "$monitor_function"` call should be skipped |

### Required parameters

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `-i` / `--iterations` | integer | required | Total number of iterations |
| `-c` / `--cleaner` | function name | `""` | Called once before the loop starts |
| `-w` / `--workload` | function name | `""` | Called each active iteration |
| `-m` / `--monitor` | function name | `""` | Called after each iteration (workload or pause) |
| `-d` / `--workload-duration` | integer (ticks) | `0` | Number of active iterations before triggering a pause. `0` = no pauses |
| `-p` / `--pause-duration` | integer (seconds) | `0` | Duration of each pause in seconds. `0` = no pauses |
| `-a` / `--on-time-action` | function name | `""` | Called every `-t` iterations (starting from iteration 1) |
| `-t` / `--action-time` | integer (ticks) | `0` | Interval for on-time action. `0` = disabled |
| `-s` / `--serial` | string | `""` | ADB device serial. Sets `ADB_SERIAL` before any ADB call |

### Execution flow

```
runner called
│
├── [if --serial set] export ADB_SERIAL
├── adb_check_connection()          ← abort if device not available
├── [if cleaner set] cleaner()
│
└── for i in 0..iterations-1:
    │
    ├── [if i > 0 && action_time > 0 && i % action_time == 0]
    │       on_time_action()
    │
    ├── [if workload_duration > 0 && pause_duration > 0 && i > 0 && i % workload_duration == 0]
    │   │   # pause period
    │   └── while elapsed < pause_duration:
    │           sleep <interval>
    │           monitor()
    │
    └── [else]
        │   # active iteration
        ├── workload()
        └── monitor()
```

**Note on pause:** during a pause period, monitor is called inside the pause loop at regular intervals. The outer-level monitor call after the if/else block is **skipped** for pause iterations to avoid the double-call bug.

### Interrupt handling *(new)*

`runner` installs a `trap` for `SIGINT` and `SIGTERM`:
```bash
trap '_runner_cleanup' INT TERM
```
`_runner_cleanup` logs the interrupted iteration number, calls the monitor one final time to capture state at the moment of interruption, then exits with code 130.

### Exit codes

| Code | Meaning |
|------|---------|
| `0` | All iterations completed normally |
| `1` | Invalid parameters or ADB check failed |
| `130` | Interrupted by SIGINT/SIGTERM |

---

## 7. Experiment script conventions (`experiments/*.sh`)

Each experiment file is a thin configuration layer, not a logic layer. Its structure:

```bash
#!/bin/bash
source "$(dirname "$0")/../scripts/bash/logger.sh"
source "$(dirname "$0")/../scripts/bash/adb.sh"
source "$(dirname "$0")/../scripts/bash/runner.sh"
source "$(dirname "$0")/../scripts/bash/workload.sh"
source "$(dirname "$0")/../scripts/bash/monitor.sh"

# --- Configuration ---
packages=("com.example.app1" "com.example.app2")
interval_duration_ms=$((30 * 1000))
interval_events_count=60

# --- Callbacks ---
cleaner() { ... }
workload() { ... }
monitors() { ... }

# --- Run ---
init_output_dirs "my_experiment"
runner \
    -i 400 \
    -c "cleaner" \
    -w "workload" \
    -m "monitors" \
    -d 100 \
    -p 1800 \
    -a "restart_packages" \
    -t 200
```

No logic beyond defining callbacks and calling `runner`. Error handling and orchestration belong in `runner.sh`.

---

## 8. Summary of new files and functions

| File | New functions |
|------|--------------|
| `adb.sh` *(new)* | `adb_cmd`, `adb_check_connection`, `adb_list_devices` |
| `logger.sh` | `log_warn`, `log_error`, `log_debug` |
| `workload.sh` | `restart_packages` |
| `monitor.sh` | `batterystats_monitor`, `list_installed_packages` |

## 9. Summary of bug fixes

| # | File | Issue |
|---|------|-------|
| 1 | `runner.sh` | On-time action variable name mismatch — action never fires |
| 2 | `runner.sh` | Pause timing drift — sleep 25 / increment 30 |
| 3 | `runner.sh` | Monitor called twice at each pause boundary |
| 4 | `runner.sh` | `-i` flag named `--intervals`, should be `--iterations` |
| 5 | `monitor.sh` | `dumpsys_service_monitor` swallows optional params as package names |
| 6 | `monitor.sh` | `logcat_monitor` race condition between dump and clear |
| 7 | `monitor.sh` | `proc_tasks_monitor` issues one ADB call per PID |
| 8 | `workload.sh` | Double `-p` flag in Monkey command |
| 9 | `workload.sh` | `run_packages` / `kill_packages` re-split string instead of using array |
| 10 | `workload.sh` | Division by zero when `events_count=0` |
