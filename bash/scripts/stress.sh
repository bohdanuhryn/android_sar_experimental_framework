#!/bin/bash

# Function to run a stress test
run_stress_test() {
    local intervals_count=$1
    local cleaner=$2
    local workload_generator=$3
    local monitor=$4
    local workload_duration_ticks=${5:-0}
    local pause_duration_seconds=${6:-0}
    local on_time_action=${7:-""}
    local action_time=${8:-0}

    # Execute the cleaner command
    eval "$cleaner"

    local i=0
    while [[ $i -lt $intervals_count ]]; do
        echo "Monitor iteration #$i"

        # Execute OnTimeAction at specified intervals
        if [[ $i -gt 0 && $action_time -gt 0 && -n $on_time_action ]]; then
            local j=$((i % action_time))
            if [[ $j -eq 0 ]]; then
                eval "$on_time_action"
            fi
        fi

        # Handle workload duration and pauses
        if [[ $i -gt 0 && $workload_duration_ticks -gt 0 && $pause_duration_seconds -gt 0 ]]; then
            if (( i % workload_duration_ticks == 0 )); then
                echo "Pause begin for $pause_duration_seconds seconds"
                local sec=0
                while (( sec < pause_duration_seconds )); do
                    echo "Pause sec = $sec"
                    sleep 25  # Sleep for 25 seconds
                    eval "$monitor"
                    sec=$((sec + 30))  # TODO: Fix pause timing, remove hardcoded 20/30
                done
            else
                eval "$workload_generator"
            fi
        else
            eval "$workload_generator"
        fi

        # Run the monitor command
        eval "$monitor"

        i=$((i + 1))
    done
}

# Example usage:
# Uncomment and replace placeholder commands to test
# run_stress_test 10 "echo 'Cleaning...'" "echo 'Generating workload...'" "echo 'Monitoring...'" 5 10 "echo 'On-time action executed'" 3
