#!/bin/bash

# Function to run the Android monkey tool
run_monkey() {
    local packages=($1)
    local duration_ms=${2:-0}
    local events_count=${3:-100}
    local ignore_errors=${4:-true}
    local enable_events=${5:-true}
    local enable_switches=${6:-true}

    local events_delay_ms=$((duration_ms / events_count))

    local packages_params=""
    if [ ${#packages[@]} -gt 0 ]; then
        packages_params="-p "$(printf " -p %s" "${packages[@]}")
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
    if [ "$enable_events" == "true" ] && [ "$enable_switches" == "true" ]; then
        events_params="--pct-touch 20 --pct-motion 20 --pct-trackball 15 --pct-nav 20 --pct-majornav 15 --pct-syskeys 0 --pct-appswitch 6 --pct-anyevent 0 --pct-flip 2 --pct-pinchzoom 2"
    elif [ "$enable_events" == "true" ]; then
        events_params="--pct-touch 20 --pct-motion 15 --pct-trackball 15 --pct-nav 20 --pct-majornav 15 --pct-syskeys 5 --pct-anyevent 5 --pct-flip 2 --pct-pinchzoom 3"
    elif [ "$enable_switches" == "true" ]; then
        events_params="--pct-touch 0 --pct-motion 0 --pct-trackball 0 --pct-nav 0 --pct-majornav 0 --pct-syskeys 0 --pct-appswitch 100 --pct-anyevent 0 --pct-flip 0 --pct-pinchzoom 0"
    fi

    echo "[Workload Generator] all params: $packages_params -v -v $throttle_param $events_params $ignore_params $events_count"

    adb shell monkey $packages_params -v -v $throttle_param $events_params $ignore_params $events_count
}

# Function to run specific packages
run_packages() {
    local packages=($1)
    for package in "${packages[@]}"; do
        adb shell monkey -p "$package" -c android.intent.category.LAUNCHER 1
    done
}

# Function to kill specific packages
kill_packages() {
    local packages=($1)
    for package in "${packages[@]}"; do
        adb shell am force-stop "$package"
    done
}

# Example usage:
# run_monkey "package1 package2" 1000 50 true true true
# run_packages "package1 package2"
# kill_packages "package1 package2"
