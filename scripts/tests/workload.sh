#!/bin/bash

SCRIPTS_DIR="$(dirname "${BASH_SOURCE[0]}")/../bash"
source "$SCRIPTS_DIR/adb.sh"
source "$SCRIPTS_DIR/workload.sh"

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

# --- ADB connection tests ----------------------------------------------------

test_adb_check_connection() {
    if adb_check_connection; then
        pass "adb_check_connection: device '$ADB_SERIAL' reachable"
    else
        fail "adb_check_connection: device '$ADB_SERIAL' not reachable"
    fi
}

test_adb_list_devices() {
    local out
    out=$(adb_list_devices)
    if [[ -n "$out" ]]; then
        pass "adb_list_devices: returned at least one serial"
    else
        fail "adb_list_devices: returned no output"
    fi
}

# --- run_monkey tests --------------------------------------------------------

test_run_monkey_no_events_no_crash() {
    # events=0 and duration=0 — must not divide by zero and must exit cleanly
    if run_monkey -p com.android.settings -e 0 -d 0 --event-preset mixed; then
        pass "run_monkey: events=0 duration=0 does not crash"
    else
        fail "run_monkey: events=0 duration=0 returned non-zero"
    fi
}

test_run_monkey_mixed_preset() {
    if run_monkey -p com.android.settings -e 10 -d 5000 --event-preset mixed; then
        pass "run_monkey: mixed preset runs 10 events on com.android.settings"
    else
        fail "run_monkey: mixed preset returned non-zero"
    fi
}

test_run_monkey_switches_preset() {
    if run_monkey -p com.android.settings -e 5 --event-preset switches; then
        pass "run_monkey: switches preset runs 5 events"
    else
        fail "run_monkey: switches preset returned non-zero"
    fi
}

test_run_monkey_unknown_preset() {
    # Must return non-zero and log an error — must NOT run monkey
    if run_monkey -p com.android.settings -e 5 --event-preset invalid_preset 2>/dev/null; then
        fail "run_monkey: unknown preset should return non-zero but returned 0"
    else
        pass "run_monkey: unknown preset correctly returns non-zero"
    fi
}

test_run_monkey_multiple_packages() {
    if run_monkey \
        -p com.android.settings \
        -p com.android.contacts \
        -e 10 \
        --event-preset mixed; then
        pass "run_monkey: multiple -p flags accepted"
    else
        fail "run_monkey: multiple -p flags returned non-zero"
    fi
}

# --- run_packages / kill_packages tests -------------------------------------

test_run_packages() {
    if run_packages com.android.settings com.android.contacts; then
        pass "run_packages: launched com.android.settings and com.android.contacts"
    else
        fail "run_packages: returned non-zero"
    fi
}

test_kill_packages() {
    if kill_packages com.android.settings com.android.contacts; then
        pass "kill_packages: stopped com.android.settings and com.android.contacts"
    else
        fail "kill_packages: returned non-zero"
    fi
}

# --- Main --------------------------------------------------------------------

select_device
echo ""

echo "=== ADB ==="
test_adb_check_connection
test_adb_list_devices

echo ""
echo "=== run_monkey ==="
test_run_monkey_no_events_no_crash
test_run_monkey_mixed_preset
test_run_monkey_switches_preset
test_run_monkey_unknown_preset
test_run_monkey_multiple_packages

echo ""
echo "=== run_packages / kill_packages ==="
test_run_packages
test_kill_packages

echo ""
summary
