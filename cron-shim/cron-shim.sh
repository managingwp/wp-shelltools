#!/bin/bash
# -- Created by Jordan - hello@managingwp.io - https://managingwp.io
#
# Purpose: Run WordPress crons via wp-cli and log the output to stdout, syslog, or a file.
# Usage: Add the following to your crontab (replacing /path/to/wordpress with the path to your WordPress install):
# */5 * * * * /home/systemuser/cron-shim.sh
#
# -- Optional: Set the following environment variables to change the default behavior:
# -- This allows you to run multiple cron jobs with different settings
# -- And also overwrite cron-shim.sh with new versions without affecting your settings.
#
#  TODO - Provide an example of passing an evnironment variable
# Example: */5 * * * * /home/systemuser/cron-shim.sh

# -- Variables
VERSION="1.2.1"
PID_FILE="/tmp/cron-shim.pid"
SCRIPT_NAME=$(basename "$0") # - Name of this script
declare -A SITE_MAP # - Map of sites to run cron on

# -- Where are we?
SCRIPT_DIR=$(dirname "$(realpath "$0")") # - Directory of this script

# -- Default Settings
[[ -z $WP_CLI ]] && WP_CLI="/usr/local/bin/wp" # - Location of wp-cli
[[ -z $WP_ROOT ]] && WP_ROOT="" # - Path to WordPress, blank will try common directories.
[[ -z $CRON_CMD_SETTINGS ]] && CRON_CMD_SETTINGS="cron event run --due-now" # - Command to run
[[ -z $HEARTBEAT_URL ]] && HEARTBEAT_URL="" # - Heartbeat monitoring URL, example https://uptime.betterstack.com/api/v1/heartbeat/23v123v123c12312 leave blank to disable or pass in via environment variable
[[ -z $POST_CRON_CMD ]] && POST_CRON_CMD="" # - Command to run after cron completes
[[ -z $MONITOR_RUN ]] && MONITOR_RUN="0" # - Monitor the script run and don't execute again if existing PID exists or process is still running.
[[ -z $MONITOR_RUN_TIMEOUT ]] && MONITOR_RUN_TIMEOUT="300" # - Time in seconds to consider script is stuck.

# -- Logging Settings
[[ -z $LOG_TO_STDOUT ]] && LOG_TO_STDOUT="1" # - Log to stdout? 0 = no, 1 = yes
[[ -z $LOG_TO_SYSLOG ]] && LOG_TO_SYSLOG="1" # - Log to syslog? 0 = no, 1 = yes
[[ -z $LOG_TO_FILE ]] && LOG_TO_FILE="0" # - Log to file? 0 = no, 1 = yes
[[ -z $LOG_FILE ]] && LOG_FILE="cron-shim.log" # Location for WordPress cron log file if LOG_TO_FILE="1", if left blank then cron-shim.log"

# -- _log $message
function _log () {
    local MESSAGE="${*}"
    # -- Logging
    # Check if logging to stdout is enabled
    [[ $LOG_TO_STDOUT == "1" ]] && { echo -e "$MESSAGE"; }
    # Check if logging to syslog is enabled
    [[ $LOG_TO_SYSLOG == "1" ]] && { echo -e "$MESSAGE" | logger -t "wordpress-cron-$DOMAIN_NAME"; }
    # Check if logging to log file is enabled
    [[ $LOG_TO_FILE == "1" ]] && { echo -e "$MESSAGE" >> $LOG_FILE; }
}

# -- _time_spent $START_TIME $END_TIME
function _time_spent () {
    local START_TIME=$1
    local END_TIME=$2
    # check if bc installed otherwise use awk
    if [[ $(command -v bc) ]]; then
        TIME_SPENT=$(echo "$END_TIME - $START_TIME" | bc)
    else
        TIME_SPENT=$(echo "$END_TIME - $START_TIME" | awk '{printf "%f", $1 - $2}')
    fi
    echo "$TIME_SPENT"
}

# -- prune_old_logs
function prune_old_logs () {
    # -- Prune old logs
    _log "Starting log pruning"
    if [[ $LOG_TO_FILE == "1" ]]; then
        # -- Prune logs larger than 10MB
        if [[ $(stat -c %s "$LOG_FILE") -gt 10485760 ]]; then
            _log "-- Pruning $LOG_FILE"
            truncate -s 1M "$LOG_FILE"
            _log "-- Log file $LOG_FILE pruned"
        else
            _log "-- Log file $LOG_FILE is less than 10MB"
        fi
    else
        _log "-- Log file logging is disabled"
    fi
}

function seconds_to_human_readable (){
    local SECONDS HOURS MINUTES SECS
    local SECONDS_ARG=$1
    SECONDS=$(printf "%.0f" $SECONDS_ARG)  # Round the input to the nearest integer        
    HOURS=$((SECONDS/3600%24))
    MINUTES=$((SECONDS/60%60))
    SECS=$((SECONDS%60))
    printf "%02dh %02dm %02ds\n" $DAYS $HOURS $MINUTES $SECS
}

# -----------------------------------------------
# -- Checks
# -----------------------------------------------

# Log the start time
START_TIME=$(date +%s.%N)



# Log header
_log "==================================================================================================="
_log "== Cron Shim ${VERSION} - job start $(echo $START_TIME|date +"%Y-%m-%d_%H:%M:%S")"
_log "==================================================================================================="


# -- Check if cron-shim.conf exists and source it
if [[ -f $SCRIPT_DIR/cron-shim.conf ]]; then
    _log "Found and sourcing $SCRIPT_DIR/cron-shim.conf"
    source "$SCRIPT_DIR/cron-shim.conf"
else
    _log "No $SCRIPT_DIR/cron-shim.conf found."
fi

# Check if $LOG_TO_FILE is enabled and set the log file location
[[ $LOG_TO_FILE == "1" ]] && _log "Logging to $LOG_FILE"

# Prune old logs
prune_old_logs

# -- Starting
_log "Starting $SCRIPT_NAME $VERSION in $SCRIPT_DIR on $(hostname)"

# -- Log where we're logging
[[ $LOG_TO_STDOUT == "1" ]] && _log "Logging to - stdout"
[[ $LOG_TO_SYSLOG == "1" ]] && _log "Logging to - syslog"
[[ $LOG_TO_FILE == "1" ]] && _log "Logging to - $LOG_FILE"

# Check if the PID file exists
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p $PID > /dev/null 2>&1; then
        _log "Error: Script is already running with PID $PID."        
        exit 1
    else
        _log "Warning: PID file exists but process is not running. Cleaning up and continuing."
        rm -f "$PID_FILE"
    fi
fi

# Create a new PID file
echo $$ > "$PID_FILE"

# Setup a trap to remove the PID file on script exit
trap "rm -f '$PID_FILE'; exit" INT TERM EXIT

# Check if running as root
[ "$(id -u)" -eq 0 ] && { _log "Error: This script should not be run as root." >&2; exit 1; }

# Check if wp-cli is installed
[[ $(command -v $WP_CLI) ]]  || { _log 'Error: wp-cli is not installed.' >&2; exit 1; }

# Check if $WP_ROOT exists and try common directories if it doesn't
if [[ $WP_ROOT == "" ]]; then
    # -- $WP_ROOT Not Detected, Try Common Directories
    _log "Warning: \$WP_ROOT not set, trying common directories."
    WP_ROOT_CHECK=( "$SCRIPT_DIR/htdocs" "$SCRIPT_DIR/public_html")
    WP_ROOT_CHECK+=("../htdocs" "../public_html" "../../htdocs" "../../public_html" "../../../htdocs" "../../../public_html")
    WP_ROOT_CHECK+=("$HOME/htdocs" "$HOME/public_html" "$HOME/www")
    for DIR in "${WP_ROOT_CHECK[@]}"; do
        if [[ -d $DIR ]]; then
            WP_ROOT="$DIR"
            break
        fi
    done
    if [[ ! -d "$WP_ROOT" ]]; then
        if [[ -d $SCRIPT_DIR/htdocs ]]; then
            WP_ROOT="$SCRIPT_DIR/htdocs"
        elif [[ -d $SCRIPT_DIR/public_html ]]; then
            WP_ROOT="$SCRIPT_DIR/public_html"
        else
            _log "Error: \$WP_ROOT does not exist." >&2; exit 1;
        fi
    fi
fi

_log "Success: \$WP_ROOT set to $WP_ROOT"

# Check if $WP_ROOT contains a WordPress install
WP_ROOT_INSTALL=$($WP_CLI --path=$WP_ROOT --skip-plugins --skip-themes core is-installed  2> /dev/null)
WP_ROOT_INSTALL_EXIT=$?
if [[ $WP_ROOT_INSTALL_EXIT == 0 ]]; then
    _log "Success: $WP_ROOT is a WordPress install - $WP_ROOT_INSTALL - $WP_ROOT_INSTALL_EXIT"
else 
    _log "Error: $WP_ROOT is not a WordPress install - $WP_ROOT_INSTALL - $WP_ROOT_INSTALL_EXIT" >&2
    exit 1
fi

# -- Resolve $WP_ROOT to an absolute path
WP_ROOT=$(realpath "$WP_ROOT")

# Get the domain name of the WordPress install
DOMAIN_NAME=$($WP_CLI --path=$WP_ROOT --skip-plugins --skip-themes option get siteurl 2> /dev/null | grep -oP '(?<=//)[^/]+')
DOMAIN_NAME_EXIT=$?
if [[ $DOMAIN_NAME_EXIT == 0 ]]; then
    _log "Success: Domain name is $DOMAIN_NAME"
else
    _log "Error: Could not get domain name: $DOMAIN_NAME" >&2
    exit 1
fi

# Check if site is a multisite
MULTISITE=$($WP_CLI --path=$WP_ROOT --skip-plugins --skip-themes wp config get MULTISITE 2> /dev/null)
MULTISITE_EXIT=$?
if [[ $MULTISITE_EXIT ==  1 ]]; then
    WP_MULTISITE="1"
    _log "Success: Multi-site detected - $MULTISITE_EXIT - $MULTISITE"
else
    WP_MULTISITE="0"
    _log "Success: Single site detected"
fi

# ===============================================
# --- Start Cron Job Queue
# ===============================================

_log "==================================================================================================="
_log ""

# Gather cron run data.
JOB_RUN_SITES_TIME=()
JOB_RUN=""
JOB_RUN_COUNT=0
CRON_ERROR=""
CRON_ERROR_COUNT=0
CRON_TIMEOUT_COUNT=0
SITE_ID=""
MULTISITE_SITES=""
COUNTER=0

_log "==================================================================================================="
_log "- Starting queue run for $DOMAIN_NAME"
# Check if multi-site is enabled and run cron for all sites
if [[ $WP_MULTISITE == "1" ]]; then
    _log "-- Multi-site detected, running cron for all sites."        
    JOB_RUN="multi"
    MULTISITE_SITES=$($WP_CLI --path=$WP_ROOT site list --format=csv 2> /dev/null | tail -n +2)
    while IFS=, read -r SITE_ID SITE_URL _; do
        _log "  - Processing site ID: $SITE_ID, URL: $SITE_URL"
        JOB_RUN_COUNT=$((JOB_RUN_COUNT+1))
        SITE_MAP[$SITE_URL]=$SITE_ID
    done <<< "$MULTISITE_SITES"
else
    _log "-- Single instance detected running $CRON_CMD"    
    JOB_RUN="single"
    JOB_RUN_COUNT=1
    SITE_MAP[$DOMAIN_NAME]="1"    
fi
_log "==================================================================================================="
_log ""

# Run $CRON_CMD queue
_log "==================================================================================================="
_log "Cron queue type:$JOB_RUN count: $JOB_RUN_COUNT"
_log "==================================================================================================="

for SITE in "${!SITE_MAP[@]}"; do
    COUNTER=$((COUNTER + 1))
    _log "==================================================================================================="
    _log "- Running cron job $COUNTER/$JOB_RUN_COUNT for $DOMAIN_NAME - $SITE ${SITE_MAP[$site]}"
    _log "==================================================================================================="
    if [[ $JOB_RUN == "multi" ]]; then
        CRON_CMD="$WP_CLI --path=$WP_ROOT --url=$SITE $CRON_CMD_SETTINGS"
    else
        CRON_CMD="$WP_CLI --path=$WP_ROOT $CRON_CMD_SETTINGS"        
    fi

    QUEUE_START_TIME=$(date +%s.%N)
    _log "-- Starting $QUEUE_START_TIME"
    CRON_EXIT_CODE=""
    
    if [[ $MONITOR_RUN == "1" ]]; then
        _log "-- Monitoring script run for $MONITOR_RUN_TIMEOUT seconds.\n"
        _log "-- timeout ${MONITOR_RUN_TIMEOUT} $CRON_CMD\n"
        CRON_OUTPUT="$(timeout ${MONITOR_RUN_TIMEOUT} $CRON_CMD 2>&1)"
        CRON_EXIT_CODE=$?
    else
        _log "-- Running $CRON_CMD"
        # Log stdout and stderr to seperate variables and run the command        
        CRON_STDOUT=$(mktemp)
        CRON_STDERR=$(mktemp)
        
        $CRON_CMD >"$CRON_STDOUT" 2>"$CRON_STDERR"
        CRON_EXIT_CODE=$?

        CRON_OUTPUT=""
        while IFS= read -r LINE; do
            CRON_OUTPUT+="    - $LINE\n"
        done < "$CRON_STDOUT"
        
        while IFS= read -r LINE; do
            CRON_OUTPUT+="    !! $LINE\n"
        done < "$CRON_STDERR"
        
        rm "$CRON_STDOUT" "$CRON_STDERR"
    fi

    # Check if timeout occurred
    if [ $? -eq 124 ]; then
        _log "-- Error: Timeout occurred after $MONITOR_RUN_TIMEOUT seconds during $CRON_CMD" >&2
        # Handle the timeout case, maybe some cleanup or a special message
        CRON_TIMEOUT_COUNT=$((CRON_TIMEOUT_COUNT+1))
    fi

    # Log the end time
    QUEUE_END_TIME=$(date +%s.%N)
    QUEUE_TIME_SPENT="$(_time_spent $QUEUE_START_TIME $QUEUE_END_TIME)"

    # Check if there was an error running $CRON_CMD
    if [[ $CRON_EXIT_CODE -ne 0 ]]; then
        CRON_ERROR="1"
        CRON_ERROR_COUNT=$((CRON_ERROR_COUNT+1))
        _log "Error: $CRON_CMD - command failed: $CRON_OUTPUT" >&2
        _log "$CRON_OUTPUT"
        if [[ -n "$POST_CRON_CMD" ]]; then
            eval "$POST_CRON_CMD"
        fi
    else
        _log "$CRON_OUTPUT"
        # Log the end time and CPU usage        
    fi

    # If $CRON_OUTPUT is empty, log the exit code
    if [[ -z "$CRON_OUTPUT" ]]; then
        _log "Error: Cron output is empty. Exit code: $CRON_EXIT_CODE" >&2
    fi

    # Get CPU Usage
    _log "-- Ending - $QUEUE_END_TIME"
    QUEUE_CPU_USAGE=$(ps -p $$ -o %cpu | tail -n 1)
    _log ">>>> Cron job completed in $QUEUE_TIME_SPENT seconds with $QUEUE_CPU_USAGE% CPU usage."
    JOB_RUN_SITES_TIME+=("- $DOMAIN_NAME - $CRON = Time:$QUEUE_TIME_SPENT CPU: $QUEUE_CPU_USAGE")
done
END_TIME=$(date +%s.%N)

# Check if heartbeat monitoring is enabled and send a request to the heartbeat URL if it is and there are no errors
if [[ $CRON_ERROR == "1" ]]; then
    _log "Error: Cron job failed with $CRON_ERROR_COUNT errors."
else
    _log "Success: Cron job completed with $CRON_ERROR_COUNT errors."
    if [[ -n "$HEARTBEAT_URL" ]]; then        
        curl -I -s "$HEARTBEAT_URL" > /dev/null
        _log "\n==== Sent Heartbeat to $HEARTBEAT_URL"
    fi
fi

# POST_CRON_CMD
if [[ -n "$POST_CRON_CMD" ]]; then
    _log "$(eval "$POST_CRON_CMD")"
fi
TIME_SPENT="$(_time_spent $START_TIME $END_TIME)"

# -- Print out the time spent on the each queue item.
_log "==================================================================================================="
_log "Cron queue run time for $DOMAIN_NAME"
for JOB_RUN_SITE_TIME in "${JOB_RUN_SITES_TIME[@]}"; do
    _log "$JOB_RUN_SITE_TIME"
done
_log "==================================================================================================="

_log ""
_log "===================================================================================================
== Cron run completed in $TIME_SPENT seconds / $(seconds_to_human_readable "$TIME_SPENT") / with $CPU_USAGE% CPU usage.
== Cron Errors: $CRON_ERROR_COUNT Cron Timeouts: $CRON_TIMEOUT_COUNT 
== Cron run End Time - $(echo $END_TIME | date +"%Y-%m-%d_%H:%M:%S")
==================================================================================================="
