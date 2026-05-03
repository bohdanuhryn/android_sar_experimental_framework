#!/bin/bash

SCRIPTS_DIR="$(dirname "${BASH_SOURCE[0]}")/../bash"
source "$SCRIPTS_DIR/adb.sh"
source "$SCRIPTS_DIR/monitor.sh"

# --- Helpers -----------------------------------------------------------------

PASS=0
FAIL=0

pass() { echo "[PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "[FAIL] $1"; FAIL=$((FAIL + 1)); }

summary() {
    echo ""
    echo "Results: $PASS passed, $FAIL failed"
    [[ $FAIL -eq 0 ]]
}

# --- Device selection --------------------------------------------------------

select_device() {
    local devices
    devices=$(adb_list_devices)
    local count
    count=$(echo "$devices" | grep -c . || true)

    if [[ $count -eq 0 ]]; then
        echo "No ADB devices connected. Connect a device or start an emulator and re-run."
        exit 1
    fi

    if [[ $count -eq 1 ]]; then
        export ADB_SERIAL="$devices"
        echo "Using device: $ADB_SERIAL"
        return 0
    fi

    echo "Multiple devices found:"
    local i=1
    while IFS= read -r serial; do
        echo "  $i) $serial"
        i=$((i + 1))
    done <<< "$devices"

    local choice
    read -rp "Select device number [1-$count]: " choice
    export ADB_SERIAL=$(echo "$devices" | sed -n "${choice}p")
    echo "Using device: $ADB_SERIAL"
}

# --- Setup / teardown --------------------------------------------------------

TEST_OUTPUT_DIR=""

setup() {
    init_output_dirs "test_monitor"
    TEST_OUTPUT_DIR="$OUTPUT_DIR_PATH"
}

teardown() {
    echo "Teardown does nothing since test output is useful for debugging."
    # [[ -n "$TEST_OUTPUT_DIR" ]] && rm -rf "$TEST_OUTPUT_DIR"
}

# --- init_output_dirs tests --------------------------------------------------

test_init_output_dirs_creates_directories() {
    local dirs=("logcat" "dumpsys" "proctasks" "bugReports")
    local missing=()
    for d in "${dirs[@]}"; do
        [[ -d "$TEST_OUTPUT_DIR/$d" ]] || missing+=("$d")
    done
    if [[ ${#missing[@]} -eq 0 ]]; then
        pass "init_output_dirs: all subdirectories created"
    else
        fail "init_output_dirs: missing directories: ${missing[*]}"
    fi
}

test_init_output_dirs_sets_output_dir_path() {
    if [[ -n "$OUTPUT_DIR_PATH" && -d "$OUTPUT_DIR_PATH" ]]; then
        pass "init_output_dirs: OUTPUT_DIR_PATH set and exists ($OUTPUT_DIR_PATH)"
    else
        fail "init_output_dirs: OUTPUT_DIR_PATH not set or directory missing"
    fi
}

# --- dumpsys_service_monitor tests -------------------------------------------

test_dumpsys_no_service_returns_error() {
    if dumpsys_service_monitor 2>/dev/null; then
        fail "dumpsys_service_monitor: missing -s should return non-zero"
    else
        pass "dumpsys_service_monitor: missing -s correctly returns non-zero"
    fi
}

test_dumpsys_meminfo_creates_file() {
    dumpsys_service_monitor -s meminfo
    if [[ -f "$TEST_OUTPUT_DIR/dumpsys/meminfo.txt" ]]; then
        pass "dumpsys_service_monitor: meminfo.txt created"
    else
        fail "dumpsys_service_monitor: meminfo.txt not found"
    fi
}

test_dumpsys_meminfo_has_separator() {
    if grep -q "=== Recording" "$TEST_OUTPUT_DIR/dumpsys/meminfo.txt"; then
        pass "dumpsys_service_monitor: separator line present in meminfo.txt"
    else
        fail "dumpsys_service_monitor: separator line missing in meminfo.txt"
    fi
}

test_dumpsys_meminfo_appends_on_second_call() {
    dumpsys_service_monitor -s meminfo
    local lines_after
    lines_after=$(wc -l < "$TEST_OUTPUT_DIR/dumpsys/meminfo.txt")
    if [[ $lines_after -gt 1 ]]; then
        pass "dumpsys_service_monitor: second call appends (file has $lines_after lines)"
    else
        fail "dumpsys_service_monitor: file did not grow after second call"
    fi
}

test_dumpsys_gfxinfo_with_package_creates_file() {
    dumpsys_service_monitor -s gfxinfo -p com.android.settings
    if [[ -f "$TEST_OUTPUT_DIR/dumpsys/gfxinfo-com.android.settings.txt" ]]; then
        pass "dumpsys_service_monitor: per-package file gfxinfo-com.android.settings.txt created"
    else
        fail "dumpsys_service_monitor: per-package file not found"
    fi
}

test_dumpsys_multiple_packages_create_separate_files() {
    dumpsys_service_monitor -s gfxinfo -p com.android.settings -p com.android.contacts
    local missing=()
    [[ -f "$TEST_OUTPUT_DIR/dumpsys/gfxinfo-com.android.settings.txt" ]] || missing+=("gfxinfo-com.android.settings.txt")
    [[ -f "$TEST_OUTPUT_DIR/dumpsys/gfxinfo-com.android.contacts.txt" ]] || missing+=("gfxinfo-com.android.contacts.txt")
    if [[ ${#missing[@]} -eq 0 ]]; then
        pass "dumpsys_service_monitor: separate file created per package"
    else
        fail "dumpsys_service_monitor: missing files: ${missing[*]}"
    fi
}

test_dumpsys_options_not_treated_as_package() {
    dumpsys_service_monitor -s gfxinfo -p com.android.settings -o reset
    if [[ ! -f "$TEST_OUTPUT_DIR/dumpsys/gfxinfo-reset.txt" ]]; then
        pass "dumpsys_service_monitor: -o value not used as package name"
    else
        fail "dumpsys_service_monitor: -o value was incorrectly treated as a package"
    fi
}

# --- logcat_monitor tests ----------------------------------------------------

test_logcat_creates_file() {
    logcat_monitor
    if [[ -f "$TEST_OUTPUT_DIR/logcat/logcat.txt" ]]; then
        pass "logcat_monitor: logcat.txt created"
    else
        fail "logcat_monitor: logcat.txt not found"
    fi
}

test_logcat_has_separator() {
    if grep -q "=== Recording" "$TEST_OUTPUT_DIR/logcat/logcat.txt"; then
        pass "logcat_monitor: separator line present"
    else
        fail "logcat_monitor: separator line missing"
    fi
}

test_logcat_appends_on_second_call() {
    local lines_before
    lines_before=$(wc -l < "$TEST_OUTPUT_DIR/logcat/logcat.txt")
    logcat_monitor
    local lines_after
    lines_after=$(wc -l < "$TEST_OUTPUT_DIR/logcat/logcat.txt")
    if [[ $lines_after -gt $lines_before ]]; then
        pass "logcat_monitor: second call appends (before=$lines_before after=$lines_after)"
    else
        fail "logcat_monitor: file did not grow after second call"
    fi
}

# --- proc_tasks_monitor tests ------------------------------------------------

test_proc_tasks_creates_file() {
    proc_tasks_monitor
    if [[ -f "$TEST_OUTPUT_DIR/proctasks/proctasks.txt" ]]; then
        pass "proc_tasks_monitor: proctasks.txt created"
    else
        fail "proc_tasks_monitor: proctasks.txt not found"
    fi
}

test_proc_tasks_has_separator() {
    if grep -q "=== Recording" "$TEST_OUTPUT_DIR/proctasks/proctasks.txt"; then
        pass "proc_tasks_monitor: separator line present"
    else
        fail "proc_tasks_monitor: separator line missing"
    fi
}

test_proc_tasks_has_content() {
    local lines
    lines=$(wc -l < "$TEST_OUTPUT_DIR/proctasks/proctasks.txt")
    if [[ $lines -gt 2 ]]; then
        pass "proc_tasks_monitor: file has content ($lines lines)"
    else
        fail "proc_tasks_monitor: file has too few lines ($lines) — PID collection may have failed"
    fi
}

# --- Main --------------------------------------------------------------------

select_device
echo ""

echo "=== init_output_dirs ==="
setup
test_init_output_dirs_creates_directories
test_init_output_dirs_sets_output_dir_path

echo ""
echo "=== dumpsys_service_monitor ==="
test_dumpsys_no_service_returns_error
test_dumpsys_meminfo_creates_file
test_dumpsys_meminfo_has_separator
test_dumpsys_meminfo_appends_on_second_call
test_dumpsys_gfxinfo_with_package_creates_file
test_dumpsys_multiple_packages_create_separate_files
test_dumpsys_options_not_treated_as_package

echo ""
echo "=== logcat_monitor ==="
test_logcat_creates_file
test_logcat_has_separator
test_logcat_appends_on_second_call

echo ""
echo "=== proc_tasks_monitor ==="
test_proc_tasks_creates_file
test_proc_tasks_has_separator
test_proc_tasks_has_content

teardown
echo ""
summary
