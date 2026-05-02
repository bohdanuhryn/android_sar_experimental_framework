#!/bin/bash

[[ -n "${_EMULATOR_SH_LOADED:-}" ]] && return 0
_EMULATOR_SH_LOADED=1

source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/adb.sh"

# Starts an AVD.
#
# Parameters:
# -a | --avd      : AVD name (required)
# -h | --headless : Run without a GUI window (optional, default: false)
#
# Example:
# emulator_start --avd Pixel_8_API_34 --headless
emulator_start() {
    local context="emulator_start"
    local avd=""
    local headless=false

    while [[ $# -gt 0 ]]; do
        case $1 in
        -a | --avd)
            avd=$2
            shift 2
            ;;
        -h | --headless)
            headless=true
            shift
            ;;
        *)
            shift
            ;;
        esac
    done

    if [[ -z "$avd" ]]; then
        log_error "$context" "AVD name is required (-a | --avd)"
        return 1
    fi

    local args="-avd $avd"
    if [[ "$headless" == true ]]; then
        args="$args -no-window -no-audio"
    fi

    log_info "$context" "Starting emulator: $avd (headless=$headless)"
    emulator $args &
    log_info "$context" "Emulator process started (PID $!)"
}

# Blocks until the emulator has fully booted or the timeout is reached.
#
# Parameters:
# -t | --timeout : Max seconds to wait (optional, default: 120)
#
# Example:
# emulator_wait_ready --timeout 180
emulator_wait_ready() {
    local context="emulator_wait_ready"
    local timeout=120

    while [[ $# -gt 0 ]]; do
        case $1 in
        -t | --timeout)
            timeout=$2
            shift 2
            ;;
        *)
            shift
            ;;
        esac
    done

    log_info "$context" "Waiting for emulator to boot (timeout=${timeout}s)..."
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        local booted
        booted=$(adb_cmd shell getprop sys.boot_completed 2>/dev/null | tr -d '[:space:]')
        if [[ "$booted" == "1" ]]; then
            log_info "$context" "Emulator booted after ${elapsed}s"
            return 0
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done

    log_error "$context" "Emulator did not boot within ${timeout}s"
    return 1
}

# Detects the serial of the running emulator and exports ADB_SERIAL.
# Fails if zero or more than one emulator is connected.
emulator_set_serial() {
    local context="emulator_set_serial"
    local serials
    serials=$(adb devices | tail -n +2 | grep -v '^[[:space:]]*$' | grep $'\tdevice$' | awk '{print $1}' | grep '^emulator-')

    local count
    count=$(echo "$serials" | grep -c . || true)

    if [[ $count -eq 0 ]]; then
        log_error "$context" "No emulator device found in 'adb devices'"
        return 1
    elif [[ $count -gt 1 ]]; then
        log_error "$context" "Multiple emulators connected — set ADB_SERIAL manually"
        return 1
    fi

    export ADB_SERIAL="$serials"
    log_info "$context" "ADB_SERIAL set to $ADB_SERIAL"
}

# Gracefully shuts down the emulator targeted by ADB_SERIAL (or the only connected one).
emulator_stop() {
    local context="emulator_stop"
    log_info "$context" "Stopping emulator..."
    adb_cmd emu kill
    log_info "$context" "Emulator stopped"
}

# Prints available AVD names, one per line.
emulator_list_avds() {
    emulator -list-avds
}
