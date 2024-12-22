#!/bin/bash

# Parameters:
# -i | --iterations: Number of iterations to run
# -c | --cleaner: Command to clean up before starting the test
# -w | --workload: Command to generate workload
# -m | --monitor: Command to monitor the system
# -d | --workload-duration: Duration of workload execution
# -p | --pause-duration: Duration of pause between workloads
# -a | --on-time-action: Command to execute at specified intervals
# -t | --action-time: Interval to execute the on-time action
#

# Example usage:
# runner -i 10 -c "echo 'Cleaning up...'" -w "echo 'Generating workload...'" -m "echo 'Monitoring...'" -d 3 -p 5 -a "echo 'On-time action...'" -t 2

info_log() {
    echo "[INFO] runner ($(date)): $1"
}

runner() {
    local iterations_count=0
    local cleaner_function=""
    local workload_function=""
    local monitor_function=""
    local workload_duration_ticks=0
    local pause_duration_seconds=0
    local on_time_action_function=""
    local action_time=0

    # Parse the command-line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
        -i | --intervals)
            iterations_count=$2
            shift 2
            ;;
        -c | --cleaner)
            cleaner_function=$2
            shift 2
            ;;
        -w | --workload)
            workload_function=$2
            shift 2
            ;;
        -m | --monitor)
            monitor_function=$2
            shift 2
            ;;
        -d | --workload-duration)
            workload_duration_ticks=$2
            shift 2
            ;;
        -p | --pause-duration)
            pause_duration_seconds=$2
            shift 2
            ;;
        -a | --on-time-action)
            on_time_action_function=$2
            shift 2
            ;;
        -t | --action-time)
            action_time=$2
            shift 2
            ;;
        *)
            echo "Unknown parameter: $1" >&2
            exit 1
            ;;
        esac
    done

    info_log "Starting the test with $iterations_count iterations"

    # Execute the cleaner command
    if [[ -n $cleaner_function ]]; then
        info_log "Cleaning up..."
        eval "$cleaner_function"
    fi

    # Execute the workload command
    i=0
    while [[ $i -lt $iterations_count ]]; do
        info_log "Interval $i"

        # Execute OnTimeAction at specified intervals
        if [[ $i -gt 0 && $action_time -gt 0 && -n $on_time_action ]]; then
            local j=$((i % action_time))
            if [[ $j -eq 0 ]]; then
                info_log "On-time action"
                eval "$on_time_action"
            fi
        fi

        # Handle workload duration and pauses
        if [[ $i -gt 0 && $workload_duration_ticks -gt 0 && $pause_duration_seconds -gt 0 ]]; then
            if ((i % workload_duration_ticks == 0)); then
                info_log "Pause begin for $pause_duration_seconds seconds"
                local sec=0
                while ((sec < pause_duration_seconds)); do
                    info_log "Pause sec = $sec"
                    sleep 25 # Sleep for 25 seconds
                    eval "$monitor_function"
                    sec=$((sec + 30)) # TODO: Fix pause timing, remove hardcoded 20/30
                done
            else
                info_log "Workload begin"
                eval "$workload_function"
                info_log "Workload end"
            fi
        else
            info_log "Workload begin"
            eval "$workload_function"
            info_log "Workload end"
        fi

        # Run the monitor command
        info_log "Monitoring..."
        eval "$monitor_function"

        i=$((i + 1))
    done
}
