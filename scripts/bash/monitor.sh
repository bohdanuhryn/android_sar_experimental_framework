#!/bin/bash

source "$(dirname "$0")/logger.sh"

log_monitor() {
    info_log "monitor" "$1"
}

OUTPUT_DIR_NAME="default"
OUTPUT_DIR_TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
OUTPUT_DIR_PATH="./output/$OUTPUT_DIR_NAME/$OUTPUT_DIR_TIMESTAMP"

# Function to initialize output directories.
#
# Arguments:
#   $1: Output directory name
init_output_dirs() {
    OUTPUT_DIR_NAME=$1
    OUTPUT_DIR_TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
    OUTPUT_DIR_PATH="./output/$OUTPUT_DIR_NAME/$OUTPUT_DIR_TIMESTAMP"

    mkdir -p "$OUTPUT_DIR_PATH/logcat"
    mkdir -p "$OUTPUT_DIR_PATH/dumpsys"
    mkdir -p "$OUTPUT_DIR_PATH/proctasks"
    mkdir -p "$OUTPUT_DIR_PATH/bugReports"

    log_monitor "Output directories initialized in $OUTPUT_DIR_PATH"
}

# Function to capture a bug report
bug_reports_monitor() {
    local path="$OUTPUT_DIR_PATH/bugReports"

    log_monitor "Running bug report..."
    mkdir -p "$path"
    adb bugreport "$path"
    log_monitor "Bug report saved to $path"
}

# Function to monitor dumpsys service
dumpsys_service_monitor() {
    local service=$1
    shift 1
    local packages=("$@") # Remaining arguments are packages
    local path="$OUTPUT_DIR_PATH/dumpsys"

    log_monitor "Monitoring dumpsys service: $service"
    mkdir -p "$path"

    if [[ ${#packages[@]} -gt 0 ]]; then
        for package in "${packages[@]}"; do
            local filename="$service-$package.txt"
            local full_path="$path/$filename"
            echo "$(date)" >> "$full_path"
            adb shell dumpsys "$service" "$package" >> "$full_path"
        done
    else
        local filename="$service.txt"
        local full_path="$path/$filename"
        echo "$(date)" >> "$full_path"
        adb shell dumpsys "$service" >> "$full_path"
    fi
    log_monitor "Dumpsys service $service saved to $path"
}

# Function to capture LogCat
logcat_monitor() {
    local path="$OUTPUT_DIR_PATH/logcat/logcat.txt"

    log_monitor "Capturing LogCat..."
    echo "$(date)" >> "$path"
    adb logcat -d -v monotonic >> "$path"
    adb logcat -c
    log_monitor "LogCat saved to $path"
}

# Function to monitor /proc tasks
proc_tasks_monitor() {
    local path="$OUTPUT_DIR_PATH/proctasks/proctasks.txt"

    log_monitor "Monitoring /proc tasks..."
    echo "$(date)" >> "$path"
    local dirs=$(adb shell ls /proc/ | grep '^[0-9]*$')

    for dir in $dirs; do
        adb shell cat "/proc/$dir/stat" >> "$path"
    done

    log_monitor "/proc tasks saved to $path"
}
