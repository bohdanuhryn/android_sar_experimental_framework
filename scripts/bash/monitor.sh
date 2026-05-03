#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/adb.sh"

log_monitor() {
    log_info "monitor" "$1"
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
    adb_cmd bugreport "$path"
    log_monitor "Bug report saved to $path"
}

# Function to monitor dumpsys service
dumpsys_service_monitor() {
    local service=""
    local packages=()
    local options=""
    local path="$OUTPUT_DIR_PATH/dumpsys"

    while [[ $# -gt 0 ]]; do
        case $1 in
        -s | --service)
            service=$2
            shift 2
            ;;
        -p | --package)
            packages+=("$2")
            shift 2
            ;;
        -o | --options)
            options=$2
            shift 2
            ;;
        *)
            shift
            ;;
        esac
    done

    if [[ -z "$service" ]]; then
        log_error "dumpsys_service_monitor" "Service name is required (-s | --service)"
        return 1
    fi

    log_monitor "Monitoring dumpsys service: $service"
    mkdir -p "$path"

    if [[ ${#packages[@]} -gt 0 ]]; then
        for package in "${packages[@]}"; do
            local full_path="$path/$service-$package.txt"
            echo "$(date)" >> "$full_path"
            adb_cmd shell dumpsys "$service" "$package" $options >> "$full_path"
        done
    else
        local full_path="$path/$service.txt"
        echo "$(date)" >> "$full_path"
        adb_cmd shell dumpsys "$service" $options >> "$full_path"
    fi
    log_monitor "Dumpsys service $service saved to $path"
}

# Function to capture LogCat
logcat_monitor() {
    local path="$OUTPUT_DIR_PATH/logcat/logcat.txt"

    log_monitor "Capturing LogCat..."
    echo "$(date)" >> "$path"
    adb_cmd logcat -d -v monotonic >> "$path"
    adb_cmd logcat -c
    log_monitor "LogCat saved to $path"
}

# Function to monitor /proc tasks
proc_tasks_monitor() {
    local path="$OUTPUT_DIR_PATH/proctasks/proctasks.txt"

    log_monitor "Monitoring /proc tasks..."
    echo "$(date)" >> "$path"
    local dirs=$(adb_cmd shell ls /proc/ | grep '^[0-9]*$')

    for dir in $dirs; do
        adb_cmd shell cat "/proc/$dir/stat" >> "$path"
    done

    log_monitor "/proc tasks saved to $path"
}
