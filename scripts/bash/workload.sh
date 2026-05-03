#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/adb.sh"

# Function to run the Android monkey tool.
#
# Parameters:
# -p | --packages: List of packages to run the monkey on
# -d | --duration: Duration of the monkey execution in milliseconds
# -e | --events: Number of events to generate
# -i | --ignore-errors: Ignore errors during monkey execution
# -ee | --enable-events: Enable events in the monkey execution
# -es | --enable-switches: Enable app switches in the monkey execution
#
# Example usage:
# run_monkey "package1 package2" 1000 50 true true true

run_monkey() {
    local packages=()
    local duration_ms=0
    local events_count=0
    local ignore_errors=true
    local event_preset="mixed"

    while [[ $# -gt 0 ]]; do
        case $1 in
        -p | --packages)
            packages+=("$2")
            shift 2
            ;;
        -d | --duration)
            duration_ms=$2
            shift 2
            ;;
        -e | --events)
            events_count=$2
            shift 2
            ;;
        -i | --ignore-errors)
            ignore_errors=$2
            shift 2
            ;;
        --event-preset)
            event_preset=$2
            shift 2
            ;;
        *)
            shift
            ;;
        esac
    done

    local events_delay_ms=0
    if [[ $duration_ms -gt 0 && $events_count -gt 0 ]]; then
        events_delay_ms=$((duration_ms / events_count))
    fi

    local packages_params=""
    if [[ ${#packages[@]} -gt 0 ]]; then
        packages_params=$(printf -- '-p %s ' "${packages[@]}")
    fi

    local throttle_param=""
    if [ $events_delay_ms -gt 0 ]; then
        throttle_param="--throttle $events_delay_ms"
    fi

    local ignore_params=""
    if [ "$ignore_errors" == "true" ]; then
        ignore_params="--ignore-crashes --ignore-timeouts --ignore-security-exceptions --kill-process-after-error"
    fi

    local events_params=""
    case "$event_preset" in
    mixed)
        events_params="--pct-touch 20 --pct-motion 20 --pct-trackball 15 --pct-nav 20 --pct-majornav 15 --pct-syskeys 0 --pct-appswitch 6 --pct-anyevent 0 --pct-flip 2 --pct-pinchzoom 2"
        ;;
    gestures)
        events_params="--pct-touch 20 --pct-motion 15 --pct-trackball 15 --pct-nav 20 --pct-majornav 15 --pct-syskeys 5 --pct-anyevent 5 --pct-flip 2 --pct-pinchzoom 3"
        ;;
    switches)
        events_params="--pct-touch 0 --pct-motion 0 --pct-trackball 0 --pct-nav 0 --pct-majornav 0 --pct-syskeys 0 --pct-appswitch 100 --pct-anyevent 0 --pct-flip 0 --pct-pinchzoom 0"
        ;;
    *)
        log_error "run_monkey" "Unknown event preset: '$event_preset'. Valid values: mixed, gestures, switches"
        return 1
        ;;
    esac

    echo "[Workload Generator] all params: $packages_params -v -v $throttle_param $events_params $ignore_params $events_count"

    adb_cmd shell monkey $packages_params -v -v $throttle_param $events_params $ignore_params $events_count
}

run_packages() {
    local packages=($1)
    for package in "${packages[@]}"; do
        adb_cmd shell monkey -p "$package" -c android.intent.category.LAUNCHER 1
    done
}

kill_packages() {
    local packages=($1)
    for package in "${packages[@]}"; do
        adb_cmd shell am force-stop "$package"
    done
}
