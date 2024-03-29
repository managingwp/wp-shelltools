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
VERSION="1.1.0"
PID_FILE="/tmp/cron-shim.pid"
SCRIPT_NAME=$(basename "$0") # - Name of this script

# -- Where are we?
SCRIPT_DIR=$(dirname "$(realpath "$0")") # - Directory of this script

# -- Default Settings
[[ -z $WP_CLI ]] && WP_CLI="/usr/local/bin/wp" # - Location of wp-cli
[[ -z $WP_ROOT ]] && WP_ROOT="" # - Path to WordPress, blank will try common directories.
[[ -z $CRON_CMD ]] && CRON_CMD="$WP_CLI cron event run --due-now" # - Command to run
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
    [[ $LOG_TO_STDOUT == "1" ]] && { echo "$MESSAGE"; }
    # Check if logging to syslog is enabled
    [[ $LOG_TO_SYSLOG == "1" ]] && { echo "$MESSAGE" | logger -t "wordpress-cron-$DOMAIN_NAME"; }
    # Check if logging to log file is enabled
    [[ $LOG_TO_FILE == "1" ]] && { echo "$MESSAGE" >> $LOG_FILE; }
}

# -- Check if cron-shim.conf exists and source it
if [[ -f $SCRIPT_DIR/cron-shim.conf ]]; then
    STARTUP_LOG+="Found and sourcing $SCRIPT_DIR/cron-shim.conf"
    source "$SCRIPT_DIR/cron-shim.conf"
fi



# -----------------------------------------------
# -- Checks
# -----------------------------------------------

# Log the start time
START_TIME=$(date +%s.%N)

# Log header
_log "==================================================================================================="
_log "== Cron Shim ${VERSION} - job start $(echo $START_TIME|date +"%Y-%m-%d_%H:%M:%S")"
_log "==================================================================================================="

# Check if $LOG_TO_FILE is enabled and set the log file location
[[ $LOG_TO_FILE == "1" ]] && _log "Logging to $LOG_FILE"

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
            _log "Error: $WP_ROOT does not exist." >&2; exit 1;
        fi
    fi
fi

# Check if $WP_ROOT contains a WordPress install
WP_ROOT_INSTALL=$($WP_CLI --path=$WP_ROOT --skip-plugins --skip-themes core is-installed  2> /dev/null)
[[ $? == 0 ]] && { _log "Success: $WP_ROOT is a WordPress install."; } || { _log "Error: $WP_ROOT is not a WordPress install - $WP_ROOT_INSTALL " >&2; exit 1; }

# -- Resolve $WP_ROOT to an absolute path
WP_ROOT=$(realpath "$WP_ROOT")

# Get the domain name of the WordPress install
DOMAIN_NAME=$($WP_CLI --path=$WP_ROOT --skip-plugins --skip-themes option get siteurl 2> /dev/null | grep -oP '(?<=//)[^/]+')
[[ $? == 0 ]] && { _log "Success: Domain name is $DOMAIN_NAME"; } || { _log "Error: Could not get domain name: $DOMAIN_NAME"; exit 1; }

# -- Set $CRON_CMD with $WP_ROOT
CRON_CMD="$CRON_CMD --path=$WP_ROOT" # - Command to run

# ===============================================
# --- Start Cron Job
# ===============================================

_log ""
_log "==================================================================================================="
_log ""

# Run $CRON_CMD
if [[ $MONITOR_RUN == "1" ]]; then
    _log "Monitoring script run for $MONITOR_RUN_TIMEOUT seconds.\n"
    _log "timeout ${MONITOR_RUN_TIMEOUT} $CRON_CMD\n"
    CRON_OUTPUT=$(timeout ${MONITOR_RUN_TIMEOUT} $CRON_CMD)
else
    _log "Running $CRON_CMD"
    CRON_OUTPUT="$(eval $CRON_CMD)"
fi

# Check if timeout occurred
if [ $? -eq 124 ]; then
    _log "Error: Timeout occurred after $MONITOR_RUN_TIMEOUT seconds during $CRON_CMD" >&2
    # Handle the timeout case, maybe some cleanup or a special message
fi

# Check if there was an error running $CRON_CMD
if [[ $? -ne 0 ]]; then
    _log "Error: $CRON_CMD - command failed: $CRON_OUTPUT" >&2
    _log "$CRON_OUTPUT"
    if [[ -n "$POST_CRON_CMD" ]]; then
        $(eval "$POST_CRON_CMD")
    fi
else
    _log "$CRON_OUTPUT"
    # Check if heartbeat monitoring is enabled and send a request to the heartbeat URL if it is and there are no errors
    if [[ -n "$HEARTBEAT_URL" ]] && [[ $? -eq 0 ]] ; then
        curl -I -s "$HEARTBEAT_URL" > /dev/null
        _log "\n==== Sent Heartbeat to $HEARTBEAT_URL"
    fi

    # Log the end time and CPU usage
    END_TIME=$(date +%s.%N)

    # check if bc installed otherwise use awk
    if [[ $(command -v bc) ]]; then
        TIME_SPENT=$(echo "$END_TIME - $START_TIME" | bc)
    else
        TIME_SPENT=$(echo "$END_TIME - $START_TIME" | awk '{printf "%f", $1 - $2}')
    fi
    # Get CPU Usage
    CPU_USAGE=$(ps -p $$ -o %cpu | tail -n 1)

    # POST_CRON_CMD
    if [[ -n "$POST_CRON_CMD" ]]; then
        _log "$(eval "$POST_CRON_CMD")"
    fi
fi

_log ""
_log "===================================================================================================
== Cron job completed in $TIME_SPENT seconds with $CPU_USAGE% CPU usage.
== Cron job End Time - $(echo $END_TIME | date +"%Y-%m-%d_%H:%M:%S")
==================================================================================================="
