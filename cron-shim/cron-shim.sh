#!/usr/bin/env bash
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
VERSION="1.4.3"
PID_FILE="/tmp/cron-shim.pid"
SCRIPT_NAME=$(basename "$0") # -     Name of this script
declare -A SITE_MAP # - Map of sites to run cron on
SCRIPT_DIR=$(dirname "$(realpath "$0")") # - Directory of this script
START_TIME=$(date +%s.%N)

# =====================================
# -- Default Settings
# =====================================
[[ -z $WP_CLI ]] && WP_CLI="/usr/local/bin/wp" # - Location of wp-cli
[[ -z $PHP_BIN ]] && PHP_BIN=$(command -v php) # - Location of PHP binary
[[ -z $WP_ROOT ]] && WP_ROOT="" # - Path to WordPress, blank will try common directories.
[[ -z $CRON_CMD_SETTINGS ]] && CRON_CMD_SETTINGS="cron event run --due-now" # - Command to run
[[ -z $HEARTBEAT_URL ]] && HEARTBEAT_URL="" # - Heartbeat monitoring URL, example https://uptime.betterstack.com/api/v1/heartbeat/23v123v123c12312 leave blank to disable or pass in via environment variable
[[ -z $POST_CRON_CMD ]] && POST_CRON_CMD="" # - Command to run after cron completes
[[ -z $MONITOR_RUN ]] && MONITOR_RUN="0" # - Monitor the script run and don't execute again if existing PID exists or process is still running.
[[ -z $MONITOR_RUN_TIMEOUT ]] && MONITOR_RUN_TIMEOUT="300" # - Time in seconds to consider script is stuck.
[[ -z $CHECK_LOAD_AVERAGE ]] && CHECK_LOAD_AVERAGE="1" # - Check server load average before running? 0 = no, 1 = yes
[[ -z $MAX_LOAD_AVERAGE ]] && MAX_LOAD_AVERAGE="5.0" # - Maximum load average threshold. Don't run if load is above this value.
[[ -z $SCRIPT_ENABLED ]] && SCRIPT_ENABLED="1" # - Enable script execution? 0 = disabled, 1 = enabled

# =====================================
# -- Logging Settings
# =====================================
[[ -z $LOG_TO_STDOUT ]] && LOG_TO_STDOUT="1" # - Log to stdout? 0 = no, 1 = yes
[[ -z $LOG_TO_SYSLOG ]] && LOG_TO_SYSLOG="1" # - Log to syslog? 0 = no, 1 = yes
[[ -z $LOG_TO_FILE ]] && LOG_TO_FILE="0" # - Log to file? 0 = no, 1 = yes
[[ -z $LOG_FILE ]] && LOG_FILE="$SCRIPT_DIR/cron-shim.log" # Location for WordPress cron log file if LOG_TO_FILE="1", if left blank then cron-shim.log"
[[ -z $LOG_PRUNE_SIZE_MB ]] && LOG_PRUNE_SIZE_MB="10" # - Size in MB to prune log files when they exceed this size

# =====================================
# -- WP-CLI Opcache Settings
# =====================================
[[ -z $WP_CLI_OPCACHE ]] && WP_CLI_OPCACHE="0" # - Enable opcache for wp-cli? 0 = no, 1 = yes
[[ -z $WP_CLI_OPCACHE_DIR ]] && WP_CLI_OPCACHE_DIR="$SCRIPT_DIR/.opcache" # - Location for wp-cli opcache file cache


# -- Check if cron-shim.conf exists and source it
if [[ -f $SCRIPT_DIR/cron-shim.conf ]]; then    
    # Store original WP_CLI value to detect if it was changed by config
    WP_CLI_ORIGINAL="$WP_CLI"
    source "$SCRIPT_DIR/cron-shim.conf"
    CONF_LOADED="1"
    # Check if WP_CLI was modified by the config file
    [[ "$WP_CLI" != "$WP_CLI_ORIGINAL" ]] && WP_CLI_FROM_CONFIG="1"
fi

# =====================================
# -- _debug $message
# =====================================
function _debug () {
    # Write debug messages to stderr only, to avoid polluting stdout or file/syslog logs
    if [[ $DEBUG -gt 0 ]]; then
        local MSG
        MSG="\033[0;36mDEBUG: ${*}\033[0m"
        # Always to stderr
        echo -e "$MSG" >&2
        # Mirror to file only when enabled (never syslog/stdout)
        if [[ $LOG_TO_FILE == "1" && -n "$LOG_FILE" ]]; then
            # Strip color codes for file for readability
            echo -e "DEBUG: ${*}" >> "$LOG_FILE"
        fi
    fi
}

# =====================================
# -- _log $message
# =====================================
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

# =====================================
# -- _time_spent $START_TIME $END_TIME
# =====================================
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

# =====================================
# -- prune_old_logs
# =====================================
function prune_old_logs () {
    # -- Prune old logs
    _log " ++ Starting log pruning"
    if [[ $LOG_TO_FILE == "1" ]]; then
        # Convert MB to bytes (MB * 1024 * 1024)
        LOG_PRUNE_SIZE_BYTES=$((LOG_PRUNE_SIZE_MB * 1024 * 1024))
        # -- Prune logs larger than configured size
        if [[ $(stat -c %s "$LOG_FILE") -gt $LOG_PRUNE_SIZE_BYTES ]]; then
            _log " ++ Pruning $LOG_FILE (larger than ${LOG_PRUNE_SIZE_MB}MB)"
            truncate -s 1M "$LOG_FILE"
            _log " ++ Log file $LOG_FILE pruned"
        else
            _log " ++ Log file $LOG_FILE is less than ${LOG_PRUNE_SIZE_MB}MB"
        fi
    else
        _log " ++ Log file logging is disabled"
    fi
}

# =====================================
# -- seconds_to_human_readable $SECONDS
# =====================================
function seconds_to_human_readable (){
    local SECONDS HOURS MINUTES SECS
    local SECONDS_ARG=$1
    SECONDS=$(printf "%.0f" $SECONDS_ARG)  # Round the input to the nearest integer
    HOURS=$((SECONDS/3600%24))
    MINUTES=$((SECONDS/60%60))
    SECS=$((SECONDS%60))
    printf "%02dh %02dm %02ds\n" $DAYS $HOURS $MINUTES $SECS
}

# =====================================
# =====================================
# -- _wp_cli_opcache $@
# =====================================
function _wp_cli_opcache () {
    # Use unified debug handler (stderr + optional file mirror)
    _debug "$PHP_BIN -d opcache.file_cache=$WP_CLI_OPCACHE_DIR -d opcache.file_cache_only=1 $WP_CLI_REAL ${*}"
    # Execute without eval to avoid argument injection surprises
    $PHP_BIN -d opcache.file_cache="$WP_CLI_OPCACHE_DIR" -d opcache.file_cache_only="1" "$WP_CLI_REAL" "$@"
}

# =====================================
# -- check_load_average
# =====================================
function check_load_average () {
    if [[ $CHECK_LOAD_AVERAGE == "1" ]]; then
        # Get 1-minute load average
    local LOAD_AVERAGE
    LOAD_AVERAGE=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | sed 's/^ *//')
        _log " ++ Current 1-minute load average: $LOAD_AVERAGE"
        
        # Compare load average with threshold using awk for floating point comparison
    local LOAD_CHECK
    LOAD_CHECK=$(echo "$LOAD_AVERAGE $MAX_LOAD_AVERAGE" | awk '{if ($1 > $2) print "high"; else print "ok"}')
        
        if [[ $LOAD_CHECK == "high" ]]; then
            _log "Warning: Server load average ($LOAD_AVERAGE) is above threshold ($MAX_LOAD_AVERAGE). Skipping cron execution."
            return 1
        else
            _log " ++ Server load average ($LOAD_AVERAGE) is within acceptable range (threshold: $MAX_LOAD_AVERAGE)"
            return 0
        fi
    else
        _log " ++ Load average checking is disabled"
        return 0
    fi
}

# =============================================================================
# -- Main Script
# =============================================================================

# =====================================
# -- Debug settings
# =====================================
if [[ -z $DEBUG ]]; then
    DEBUG="0" # - Debug mode? 0 = no, 1 = yes
    _log " ++ Debug mode not enabled, DEBUG = $DEBUG"
else
    _log " ++ Debug mode enabled, DEBUG = $DEBUG"
fi
[[ $DEBUG == 2 ]] && set -x

# Log header
_log "==================================================================================================="
_log "== Cron Shim Start - Version ${VERSION} -  $(echo $START_TIME|date +"%Y-%m-%d_%H:%M:%S")"
_log "== Starting $SCRIPT_NAME $VERSION in $SCRIPT_DIR on $(hostname)"
_log "==================================================================================================="

# Check if $CONF_LOADED is enabled
[[ $CONF_LOADED == "1" ]] && _log " ++ Loaded configuration file $SCRIPT_DIR/cron-shim.conf"

# Check if script is enabled
if [[ $SCRIPT_ENABLED != "1" ]]; then
    _log "Script is disabled (SCRIPT_ENABLED=$SCRIPT_ENABLED). Exiting without running cron."
    exit 0
fi

# Check if $LOG_TO_FILE is enabled and set the log file location
[[ $LOG_TO_FILE == "1" ]] && _log " ++ Logging to $LOG_FILE"

# Prune old logs
prune_old_logs

# -- Log where we're logging
[[ $LOG_TO_STDOUT == "1" ]] && _log " ++ Logging to - stdout"
[[ $LOG_TO_SYSLOG == "1" ]] && _log " ++ Logging to - syslog"
[[ $LOG_TO_FILE == "1" ]] && _log " ++ Logging to - $LOG_FILE"

# Check if the PID file exists
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p $PID > /dev/null 2>&1; then
        _log "Error: Script is already running with PID $PID."
        exit 1
    else
        _log " ++ Warning: PID file exists but process is not running. Cleaning up and continuing."
        rm -f "$PID_FILE"
    fi
fi

# Create a new PID file
echo $$ > "$PID_FILE"
_log " ++ PID file created at $PID_FILE"

# Setup a trap to remove the PID file on script exit
# Use single quotes so variables are expanded when the trap executes, not now
trap 'rm -f "$PID_FILE"; exit' INT TERM EXIT

# Check if running as root
[ "$(id -u)" -eq 0 ] && { _log "Error: This script should not be run as root." >&2; exit 1; }
_log " ++ Running as $(whoami)"

# Check if wp-cli is installed
if [[ $(command -v $WP_CLI) ]]; then
    _log " ++ wp-cli found at $WP_CLI"
else
    # If WP_CLI wasn't set via config, try alternative paths
    if [[ $CONF_LOADED != "1" ]] || [[ -z ${WP_CLI_FROM_CONFIG:-} ]]; then
        _log " ++ wp-cli not found at $WP_CLI, searching alternative paths..."
        WP_CLI_PATHS=("/usr/bin/wp" "/usr/local/bin/wp" "/opt/wp-cli/wp" "$HOME/.composer/vendor/bin/wp" "/usr/share/wp-cli/wp")
        WP_CLI_FOUND=""
        
        for WP_PATH in "${WP_CLI_PATHS[@]}"; do
            if [[ -x "$WP_PATH" ]]; then
                WP_CLI="$WP_PATH"
                WP_CLI_FOUND="1"
                _log " ++ wp-cli found at alternative path: $WP_CLI"
                break
            fi
        done
        
        if [[ -z $WP_CLI_FOUND ]]; then
            _log "Error: wp-cli not found in any of the following paths: ${WP_CLI_PATHS[*]}" >&2
            exit 1
        fi
    else
        _log "Error: wp-cli is not installed at $WP_CLI (configured path)" >&2
        exit 1
    fi
fi

# Check server load average before proceeding
if ! check_load_average; then
    _log "Exiting due to high server load. Cron execution skipped."
    exit 0
fi

# Check if wp-cli opcache is enabled
if [[ $WP_CLI_OPCACHE == 1 ]]; then
    _log " ++ Setting up opcache for wp-cli"
    if [[ -n $PHP_BIN ]]; then
        [[ $(command -v $PHP_BIN) ]]  || { _log 'Error: \$PHP_BIN is not installed.' >&2; exit 1; }
        _log " ++ \$PHP_BIN found at $PHP_BIN"
        _log " ++ wp-cli wrapper setup with opcache"
    WP_CLI_REAL="$WP_CLI"
    # Do not splice script args into the wrapper; it can inject stray tokens like /dev/null
    WP_CLI="_wp_cli_opcache"
    _log " ++ wp-cli opcache enabled as $WP_CLI"
        
        # Clear opcache folder
        if [[ -d $WP_CLI_OPCACHE_DIR ]]; then
            _log " ++ Clearing opcache folder $WP_CLI_OPCACHE_DIR"
            rm -rf "$WP_CLI_OPCACHE_DIR"            
        fi
        # Create opcache folder
        if [[ ! -d $WP_CLI_OPCACHE_DIR ]]; then
            _log " ++ Creating opcache folder $WP_CLI_OPCACHE_DIR"
            mkdir -p "$WP_CLI_OPCACHE_DIR"
        fi
    else
        _log "Error: \$PHP_BIN is not set." >&2
        exit 1
    fi
fi

# Check if $WP_ROOT exists and try common directories if it doesn't
if [[ $WP_ROOT == "" ]]; then
    # -- $WP_ROOT Not Detected, Try Common Directories
    _log " ++ Warning: \$WP_ROOT not set, trying common directories."
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
_log " ++ \$WP_ROOT set to $WP_ROOT"

# Check if $WP_ROOT contains a WordPress install
$WP_CLI --path="$WP_ROOT" --skip-plugins --skip-themes core is-installed 2>/dev/null
WP_ROOT_INSTALL_EXIT=$?
if [[ $WP_ROOT_INSTALL_EXIT == 0 ]]; then
    _log " ++ $WP_ROOT is a WordPress install - $WP_ROOT_INSTALL_EXIT"
else
    _log "Error: $WP_ROOT is not a WordPress install - $WP_ROOT_INSTALL_EXIT"
    exit 1
fi

# -- Resolve $WP_ROOT to an absolute path
WP_ROOT=$(realpath "$WP_ROOT")
_log " ++ Resolved \$WP_ROOT to $WP_ROOT"

# Get the domain name of the WordPress install
DOMAIN_NAME=$($WP_CLI --path=$WP_ROOT --skip-plugins --skip-themes option get siteurl 2> /dev/null | grep -oP '(?<=//)[^/]+')
DOMAIN_NAME_EXIT=$?
if [[ $DOMAIN_NAME_EXIT == 0 ]]; then
    _log " ++ Domain name is $DOMAIN_NAME"
else
    _log "Error: Could not get domain name: $DOMAIN_NAME" >&2
    exit 1
fi

# Check if site is a multisite
MULTISITE=$($WP_CLI --path=$WP_ROOT --skip-plugins --skip-themes config get MULTISITE 2> /dev/null)
MULTISITE_EXIT=$?
if [[ $MULTISITE_EXIT ==  0 ]]; then
    WP_MULTISITE="1"
    _log " ++ Success: Multi-site detected - $MULTISITE_EXIT - $MULTISITE"
else
    WP_MULTISITE="0"
    _log " ++ Success: Single site detected"
fi

# ===============================================
# --- Start Cron Job Queue
# ===============================================

_log "=================================================="
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

_log "=================================================="
_log "- Starting queue run for $DOMAIN_NAME"
# Check if multi-site is enabled and run cron for all sites
if [[ $WP_MULTISITE == "1" ]]; then
    _log "-- Multi-site detected, running cron for all sites."
    JOB_RUN="multi"
    # Request only the fields we need to simplify parsing
    MULTISITE_SITES_EXEC=$($WP_CLI --path=$WP_ROOT site list --fields=blog_id,url --format=csv 2> /dev/null)
    MULTISITE_SITES_EXIT=$?
    # Strip header row if present (WP-CLI CSV output typically includes it)
    MULTISITE_SITES=$(echo "$MULTISITE_SITES_EXEC" \
        | sed '/^DEBUG:/d' \
        | awk 'NR==1 && $0 ~ /^blog_id,?url/ {next} {print}')
    if [[ $MULTISITE_SITES_EXIT -ne 0 ]]; then
        _log "Error: Could not get multi-site list: $MULTISITE_SITES" >&2
        exit 1
    fi
    while IFS=, read -r SITE_ID SITE_URL; do
        # Skip header/blank lines just in case
        [[ -z "$SITE_ID" || "$SITE_ID" == "blog_id" ]] && continue
        _log "  - Processing site ID: $SITE_ID, URL: $SITE_URL"
        JOB_RUN_COUNT=$((JOB_RUN_COUNT+1))
        SITE_MAP[$SITE_URL]=$SITE_ID
        # Preserve order for deterministic processing and resume support
        SITE_LIST+=("$SITE_URL")
    done <<< "$MULTISITE_SITES"
else
    _log "-- Single instance detected running $CRON_CMD"
    JOB_RUN="single"
    JOB_RUN_COUNT=1
    SITE_MAP[$DOMAIN_NAME]="1"
fi
_log "=================================================="
_log ""

# Run $CRON_CMD queue
_log "=================================================="
_log "Cron queue type:$JOB_RUN count: $JOB_RUN_COUNT"
_log "=================================================="

# Build ordered iteration list and resume position
ITERATION_SITES=()
if [[ $JOB_RUN == "multi" ]]; then
    # State file location (can be overridden via CRON_SHIM_STATE_FILE env var)
    STATE_FILE_DEFAULT="$SCRIPT_DIR/.cron-shim.${DOMAIN_NAME}.state"
    STATE_FILE="${CRON_SHIM_STATE_FILE:-$STATE_FILE_DEFAULT}"

    START_INDEX=0
    if [[ -f "$STATE_FILE" ]]; then
        LAST_SITE=$(cat "$STATE_FILE" 2>/dev/null)
        if [[ -n "$LAST_SITE" ]]; then
            for i in "${!SITE_LIST[@]}"; do
                if [[ "${SITE_LIST[$i]}" == "$LAST_SITE" ]]; then
                    START_INDEX=$((i+1))
                    break
                fi
            done
            # If last site was the final element, start fresh and clear state
            if [[ $START_INDEX -ge ${#SITE_LIST[@]} ]]; then
                _log " ++ State indicates previous run finished at end of list. Clearing state and starting from beginning."
                rm -f "$STATE_FILE"
                START_INDEX=0
            else
                _log " ++ Resuming multisite processing from index $START_INDEX (after $LAST_SITE)"
            fi
        fi
    fi
    # Slice the list from START_INDEX to end
    if [[ ${#SITE_LIST[@]} -gt 0 ]]; then
        ITERATION_SITES=("${SITE_LIST[@]:$START_INDEX}")
    fi
else
    # Single site processing
    ITERATION_SITES=("$DOMAIN_NAME")
fi

for SITE in "${ITERATION_SITES[@]}"; do
    COUNTER=$((COUNTER + 1))
    _log "=================================================="
    _log "- Running cron job $COUNTER/$JOB_RUN_COUNT for $DOMAIN_NAME - $SITE ${SITE_MAP[$SITE]}"
    _log "=================================================="
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
    # Update state to the last processed site (multisite only)
    if [[ $JOB_RUN == "multi" ]]; then
        echo "$SITE" > "$STATE_FILE"
    fi
done
END_TIME=$(date +%s.%N)

# Check if heartbeat monitoring is enabled and send a request to the heartbeat URL if it is and there are no errors
if [[ $CRON_ERROR == "1" ]]; then
    _log "Error: Cron job failed with $CRON_ERROR_COUNT errors."
else
    _log "Success: Cron job completed with $CRON_ERROR_COUNT errors."
    if [[ -n "$HEARTBEAT_URL" ]]; then
        # Send heartbeat to Uptime Kuma or similar services.
        # -sS: silent but show errors, -o: discard body, -w: print only HTTP code
        CURL_HTTP_CODE=$(curl -sS -o /dev/null -w "%{http_code}" "$HEARTBEAT_URL" 2>/dev/null || echo "000")
        # Treat any 2xx as success
        if [[ "$CURL_HTTP_CODE" =~ ^2[0-9]{2}$ ]]; then
            _log "\n==== Sent Heartbeat to $HEARTBEAT_URL on $(echo $START_TIME|date +"%Y-%m-%d_%H:%M:%S") CODE: $CURL_HTTP_CODE"
        else
            _log "\n==== Error: Failed to send heartbeat to $HEARTBEAT_URL on $(echo $START_TIME|date +"%Y-%m-%d_%H:%M:%S") CODE: $CURL_HTTP_CODE"
        fi
    fi
fi

# If multisite and we processed through the end of the list this run, clear the state file
if [[ $JOB_RUN == "multi" && ${#ITERATION_SITES[@]} -gt 0 ]]; then
    rm -f "$STATE_FILE" 2>/dev/null || true
fi

# POST_CRON_CMD
if [[ -n "$POST_CRON_CMD" ]]; then
    _log "$(eval "$POST_CRON_CMD")"
fi
TIME_SPENT="$(_time_spent $START_TIME $END_TIME)"

# -- Print out the time spent on the each queue item.
_log "=================================================="
_log "Cron queue run time for $DOMAIN_NAME"
for JOB_RUN_SITE_TIME in "${JOB_RUN_SITES_TIME[@]}"; do
    _log "$JOB_RUN_SITE_TIME"
done
_log "=================================================="

_log ""
_log "===================================================================================================
== Cron run completed in $TIME_SPENT seconds / $(seconds_to_human_readable "$TIME_SPENT") / with $CPU_USAGE% CPU usage.
== Cron Errors: $CRON_ERROR_COUNT Cron Timeouts: $CRON_TIMEOUT_COUNT
== Cron Shim Stop - Version ${VERSION} - $(echo $START_TIME|date +"%Y-%m-%d_%H:%M:%S")
==================================================================================================="
[[ $DEBUG == "2" ]] && set +x