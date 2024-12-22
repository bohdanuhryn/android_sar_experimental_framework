#!/bin/bash

# Define aliases
alias adb="/c/Users/Bohdan/AppData/Local/Android/Sdk/platform-tools/adb"

# Include external scripts (assumed to be converted to Bash)
source "$(dirname "$0")/../scripts/runner.sh"
source "$(dirname "$0")/../scripts/workload.sh"
source "$(dirname "$0")/../scripts/monitor.sh"
source "$(dirname "$0")/../scripts/logger.sh"

# Variables
output="debug_run_1"
packages=("com.google.android.calendar" "com.android.contacts")
interval_duration_ms=$((30 * 1000))  # 30 seconds in milliseconds
interval_events_count=60

cleaner() {
    adb logcat -c
}

workload() {
    #kill_packages "${packages[@]}"
    #run_packages "${packages[@]}"
    #run_monkey "${packages[@]}" "$interval_duration_ms" "$interval_events_count"
    echo "Debug workload generator"
}

monitors() {
    # Uncomment to enable monitoring of additional services
    # dumpsys_service_monitor "$output" "cpuinfo"
    # dumpsys_service_monitor "$output" "meminfo"
    # dumpsys_service_monitor "$output" "procstats"
    # dumpsys_service_monitor "$output" "batterystats"
    #dumpsys_service_monitor "$output" "gfxinfo" "${packages[@]}" "framestats"
    #dumpsys_service_monitor "$output" "meminfo" "" "-c"
    #dumpsys_service_monitor "$output" "graphicsstats" "" "framestats"
    #logcat_monitor "$output"
    echo "Debug monitor"
}

# Initialize output directories
init_output_dirs "$output"

# Run the stress test
runner \
    -i 30 \
    -c "cleaner" \
    -w "workload" \
    -m "monitors"
