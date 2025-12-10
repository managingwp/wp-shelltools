#!/bin/bash

# =============================================================================
# Task Runner Script
# =============================================================================
VERSION="0.1.0"

# -----------------------------------------------------------------------------
# DEFAULT CONFIGURATION
# -----------------------------------------------------------------------------

# Script directory for locating default config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default config file locations (checked in order)
DEFAULT_CONFIG_PATHS=(
    "./cron-task-runner.conf"
    "$SCRIPT_DIR/cron-task-runner.conf"
    "/etc/cron-task-runner.conf"
    "$HOME/.config/cron-task-runner.conf"
)

# Log file path
LOG_FILE="/var/log/task_runner.log"
# Lock file path
LOCK_FILE="/tmp/task_runner.lock"
# Webhook configuration
WEBHOOK_ENABLED=false
WEBHOOK_URL=""

# Tasks array (can be populated from config file)
TASKS=()

# -----------------------------------------------------------------------------
# FUNCTIONS
# -----------------------------------------------------------------------------

# Find and load config file
find_config() {
    local config_file="$1"
    
    # If config file specified, use it
    if [[ -n "$config_file" ]]; then
        if [[ -f "$config_file" ]]; then
            echo "$config_file"
            return 0
        else
            return 1
        fi
    fi
    
    # Search default locations
    for path in "${DEFAULT_CONFIG_PATHS[@]}"; do
        if [[ -f "$path" ]]; then
            echo "$path"
            return 0
        fi
    done
    
    return 1
}

# Load configuration from file
load_config() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Config file not found: $config_file"
        return 1
    fi
    
    # Source the config file
    # shellcheck source=/dev/null
    source "$config_file"
    
    return 0
}

# Get current timestamp
timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

# Log message with timestamp
log() {
    local message="$1"
    echo "[$(timestamp)] $message" | tee -a "$LOG_FILE"
}

# Log error message
log_error() {
    local message="$1"
    echo "[$(timestamp)] ERROR: $message" | tee -a "$LOG_FILE" >&2
}

# Format duration in human-readable format
format_duration() {
    local seconds=$1
    if (( seconds >= 3600 )); then
        printf "%dh %dm %ds" $((seconds/3600)) $((seconds%3600/60)) $((seconds%60))
    elif (( seconds >= 60 )); then
        printf "%dm %ds" $((seconds/60)) $((seconds%60))
    else
        printf "%ds" $seconds
    fi
}

# Send webhook notification
send_webhook() {
    local status="$1"
    local message="$2"
    
    if [[ "$WEBHOOK_ENABLED" == true ]] && [[ -n "$WEBHOOK_URL" ]]; then
        curl -s -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"status\": \"$status\", \"message\": \"$message\", \"timestamp\": \"$(timestamp)\"}" \
            > /dev/null 2>&1
        
        if [[ $? -eq 0 ]]; then
            log "Webhook notification sent successfully"
        else
            log_error "Failed to send webhook notification"
        fi
    fi
}

# Acquire lock
acquire_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local pid=$(cat "$LOCK_FILE" 2>/dev/null)
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            log_error "Script is already running (PID: $pid). Exiting."
            exit 1
        else
            log "Stale lock file found. Removing and continuing."
            rm -f "$LOCK_FILE"
        fi
    fi
    
    echo $$ > "$LOCK_FILE"
    log "Lock acquired (PID: $$)"
}

# Release lock
release_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        rm -f "$LOCK_FILE"
        log "Lock released"
    fi
}

# Cleanup on exit
cleanup() {
    release_lock
}

# Run a single task
run_task() {
    local task_desc="$1"
    local task_cmd="$2"
    
    log "--- Starting task: $task_desc ---"
    local start_time=$(date +%s)
    
    # Run the command and capture output
    local output
    output=$(eval "$task_cmd" 2>&1)
    local exit_code=$?
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local duration_formatted=$(format_duration $duration)
    
    if [[ $exit_code -eq 0 ]]; then
        log "Task completed: $task_desc (Duration: $duration_formatted)"
        if [[ -n "$output" ]]; then
            echo "$output" >> "$LOG_FILE"
        fi
        return 0
    else
        log_error "Task failed: $task_desc (Exit code: $exit_code, Duration: $duration_formatted)"
        if [[ -n "$output" ]]; then
            echo "$output" >> "$LOG_FILE"
        fi
        return 1
    fi
}

# Print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    -h, --help              Show this help message
    -c, --config FILE       Path to config file
    -l, --log FILE          Set log file path (default: $LOG_FILE)
    -w, --webhook URL       Set webhook URL and enable webhook notifications
    --dry-run               Show tasks without executing them

Config file search order (if -c not specified):
    1. ./cron-task-runner.conf
    2. <script_dir>/cron-task-runner.conf
    3. /etc/cron-task-runner.conf
    4. ~/.config/cron-task-runner.conf

Environment Variables:
    WEBHOOK_ENABLED         Set to 'true' to enable webhooks
    WEBHOOK_URL             URL for webhook notifications

EOF
}

# -----------------------------------------------------------------------------
# MAIN
# -----------------------------------------------------------------------------

main() {
    local dry_run=false
    local config_file=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -c|--config)
                config_file="$2"
                shift 2
                ;;
            -l|--log)
                LOG_FILE="$2"
                shift 2
                ;;
            -w|--webhook)
                WEBHOOK_URL="$2"
                WEBHOOK_ENABLED=true
                shift 2
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Find and load config file
    local found_config
    found_config=$(find_config "$config_file")
    if [[ -n "$found_config" ]]; then
        load_config "$found_config"
        echo "Loaded config from: $found_config"
    elif [[ -n "$config_file" ]]; then
        echo "ERROR: Specified config file not found: $config_file" >&2
        exit 1
    fi
    
    # Dry run mode - just show tasks
    if [[ "$dry_run" == true ]]; then
        echo "Tasks that would be executed:"
        if [[ ${#TASKS[@]} -eq 0 ]]; then
            echo "  (no tasks defined)"
        else
            for task in "${TASKS[@]}"; do
                IFS='|' read -r desc cmd <<< "$task"
                echo "  - $desc: $cmd"
            done
        fi
        exit 0
    fi
    
    # Set up trap for cleanup
    trap cleanup EXIT INT TERM
    
    # Acquire lock
    acquire_lock
    
    # Start logging
    log "=========================================="
    log "Task Runner v${VERSION} Started"
    log "=========================================="
    
    local total_start_time=$(date +%s)
    local total_tasks=${#TASKS[@]}
    local successful_tasks=0
    local failed_tasks=0
    
    # Run each task
    for task in "${TASKS[@]}"; do
        IFS='|' read -r desc cmd <<< "$task"
        
        if run_task "$desc" "$cmd"; then
            ((successful_tasks++))
        else
            ((failed_tasks++))
        fi
    done
    
    local total_end_time=$(date +%s)
    local total_duration=$((total_end_time - total_start_time))
    local total_duration_formatted=$(format_duration $total_duration)
    
    # Summary
    log "=========================================="
    log "Task Runner Completed"
    log "Total tasks: $total_tasks"
    log "Successful: $successful_tasks"
    log "Failed: $failed_tasks"
    log "Total duration: $total_duration_formatted"
    log "=========================================="
    
    # Send webhook notification
    if [[ $failed_tasks -eq 0 ]]; then
        send_webhook "success" "All $total_tasks tasks completed successfully in $total_duration_formatted"
        exit 0
    else
        send_webhook "partial_failure" "$failed_tasks of $total_tasks tasks failed"
        exit 1
    fi
}

# Run main function
main "$@"