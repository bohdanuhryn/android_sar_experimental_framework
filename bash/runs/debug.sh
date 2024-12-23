#!/bin/bash

# Include external scripts
source "$(dirname "$0")/../scripts/logger.sh"
source "$(dirname "$0")/../scripts/runner.sh"
source "$(dirname "$0")/../scripts/workload.sh"
source "$(dirname "$0")/../scripts/monitor.sh"

# Variables
packages=("com.google.android.calendar" "com.android.contacts")
interval_duration_ms=$((30 * 1000))  # 30 seconds in milliseconds
interval_events_count=60

cleaner() {
    adb logcat -c
}

workload() {
    # kill_packages "${packages[@]}"
    # run_packages "${packages[@]}"
    run_monkey \
        "$(printf " -p %s" "${packages[@]}")" \
        -d "$interval_duration_ms" \
        -e "$interval_events_count" \
        -i "true" \
        -ee "true" \
        -es "true"
}

monitors() {
    # dumpsys_service_monitor "cpuinfo"
    # dumpsys_service_monitor "meminfo"
    # dumpsys_service_monitor "procstats"
    # dumpsys_service_monitor "batterystats"
    # dumpsys_service_monitor "gfxinfo" "${packages[@]}" "framestats"
    # dumpsys_service_monitor "meminfo" "" "-c"
    # dumpsys_service_monitor "graphicsstats" "" "framestats"
    # logcat_monitor
    echo "No monitors enabled"
}

# Initialize output directories
init_output_dirs "debug"

# Run the stress test
runner \
    -i 1 \
    -c "cleaner" \
    -w "workload" \
    -m "monitors"
