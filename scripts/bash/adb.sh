#!/bin/bash

[[ -n "${_ADB_SH_LOADED:-}" ]] && return 0
_ADB_SH_LOADED=1

source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"

adb_cmd() {
    if [[ -n "${ADB_SERIAL:-}" ]]; then
        adb -s "$ADB_SERIAL" "$@"
    else
        adb "$@"
    fi
}

adb_check_connection() {
    local context="adb_check_connection"
    local devices
    devices=$(adb devices | tail -n +2 | grep -v '^[[:space:]]*$')

    if [[ -n "${ADB_SERIAL:-}" ]]; then
        if ! echo "$devices" | grep -q "^${ADB_SERIAL}"$'\t'"device$"; then
            log_error "$context" "Device '$ADB_SERIAL' not found or not in 'device' state"
            return 1
        fi
    else
        local count
        count=$(echo "$devices" | grep -c $'\tdevice$' || true)
        if [[ "$count" -eq 0 ]]; then
            log_error "$context" "No ADB device connected"
            return 1
        elif [[ "$count" -gt 1 ]]; then
            log_error "$context" "Multiple devices connected — set ADB_SERIAL to target one"
            return 1
        fi
    fi

    log_info "$context" "ADB connection OK"
}

adb_list_devices() {
    adb devices | tail -n +2 | grep $'\tdevice$' | awk '{print $1}'
}
