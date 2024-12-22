#!/bin/bash

# Function to initialize output directories
init_output_dirs() {
    local output=$1

    mkdir -p "./output/$output/logcat"
    mkdir -p "./output/$output/dumpsys"
    mkdir -p "./output/$output/proctasks"
    # Uncomment the line below if "bugReports" is needed
    # mkdir -p "./output/$output/bugReports"
}

# Function to capture a bug report
bug_reports_monitor() {
    local output=$1
    local path="./output/$output/bugReports"

    echo "Running bug report..."
    mkdir -p "$path"
    adb bugreport "$path"
}

# Function to monitor dumpsys service
dumpsys_service_monitor() {
    local output=$1
    local service=$2
    shift 2
    local packages=("$@") # Remaining arguments are packages
    local path="./output/$output/dumpsys"

    echo "Monitoring dumpsys service: $service"
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
}

# Function to capture LogCat
logcat_monitor() {
    local output=$1
    local path="./output/$output/logcat/logcat.txt"

    echo "Capturing LogCat..."
    echo "$(date)" >> "$path"
    adb logcat -d -v monotonic >> "$path"
    adb logcat -c
}

# Function to monitor /proc tasks
proc_tasks_monitor() {
    local output=$1
    local path="./output/$output/proctasks/proctasks.txt"

    echo "Monitoring /proc tasks..."
    echo "$(date)" >> "$path"
    local dirs=$(adb shell ls /proc/ | grep '^[0-9]*$')

    for dir in $dirs; do
        adb shell cat "/proc/$dir/stat" >> "$path"
    done
}

# Example usage
# Uncomment the following lines and adjust the parameters as needed
# init_output_dirs "test_output"
# bug_reports_monitor "test_output"
# dumpsys_service_monitor "test_output" "battery" "com.example.app1" "com.example.app2"
# logcat_monitor "test_output"
# proc_tasks_monitor "test_output"
