#!/bin/bash
# -- Created by Jordan - hello@managingwp.io - https://managingwp.io
# -- Version 1.0.3 -- Last Updated: 2023-08-23
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

# -- Where are we?
SCRIPT_DIR=$(dirname "$(realpath "$0")") # - Directory of this script

# -- Check if cron-shim.conf exists and source it
if [[ -f $SCRIPT_DIR/cron-shim.conf ]]; then
    echo "Found and sourcing $SCRIPT_DIR/cron-shim.conf"
    source $SCRIPT_DIR/cron-shim.conf
fi

# -- Default Settings
[[ -z $WP_CLI ]] && WP_CLI="/usr/local/bin/wp" # - Location of wp-cli
[[ -z $WP_ROOT ]] && WP_ROOT="" # - Path to WordPress, blank will try common directories.
[[ -z $CRON_CMD ]] && CRON_CMD="$WP_CLI cron event run --due-now" # - Command to run
[[ -z $HEARTBEAT_URL ]] && HEARTBEAT_URL="" # - Heartbeat monitoring URL, example https://uptime.betterstack.com/api/v1/heartbeat/23v123v123c12312 leave blank to disable or pass in via environment variable
[[ -z $POST_CRON_CMD ]] && POST_CRON_CMD="" # - Command to run after cron completes

# -- Logging Settings
[[ -z $LOG_TO_STDOUT ]] && LOG_TO_STDOUT="1" # - Log to stdout? 0 = no, 1 = yes
[[ -z $LOG_TO_SYSLOG ]] && LOG_TO_SYSLOG="1" # - Log to syslog? 0 = no, 1 = yes
[[ -z $LOG_TO_FILE ]] && LOG_TO_FILE="0" # - Log to file? 0 = no, 1 = yes
[[ -z $LOG_FILE ]] && LOG_FILE="" # Location for WordPress cron log file if LOG_TO_FILE="1", if left blank then ${WP_ROOT}/../wordpress-crons.log"
LOG="" # Clearing variable

# Check if running as root
[ "$(id -u)" -eq 0 ] && { echo "Error: This script should not be run as root." >&2; exit 1; }

# Check if wp-cli is installed
[[ $(command -v $WP_CLI) ]]  || { echo 'Error: wp-cli is not installed.' >&2; exit 1; }

# Check if $WP_ROOT exists and try common directories if it doesn't
if [[ $WP_ROOT == "" ]]; then
    # -- $WP_ROOT Not Detected, Try Common Directories
    if [[ ! -d "$WP_ROOT" ]]; then
        if [[ -d $SCRIPT_DIR/htdocs ]]; then
            WP_ROOT="$SCRIPT_DIR/htdocs"
        elif [[ -d $SCRIPT_DIR/public_html ]]; then
            WP_ROOT="$SCRIPT_DIR/public_html"
        else
            echo "Error: $WP_ROOT does not exist." >&2; exit 1;
        fi
    fi
fi

# Check if $LOG_TO_FILE is enabled and set the log file location
if [[ $LOG_TO_FILE == "1" ]];then
    if [[ $LOG_FILE == "" ]];then
        LOG_FILE="${WP_ROOT}/../wordpress-crons.log"
        echo "Logging to $LOG_FILE"
    fi
fi

# Check if $WP_ROOT contains a WordPress install
[[ WP_ROOT_INSTALL=$($WP_CLI --path=$WP_ROOT --skip-plugins --skip-themes core is-installed  2> /dev/null) ]] || { echo "Error: $WP_ROOT is not a WordPress install.\n$WP_ROOT_INSTALL " >&2; exit 1; }

# Get the domain name of the WordPress install
[[ DOMAIN_NAME=$($WP_CLI --path=$WP_ROOT --skip-plugins --skip-themes option get siteurl 2> /dev/null | grep -oP '(?<=//)[^/]+') ]] || { echo "Error: Could not get domain name: $DOMAIN_NAME"; exit 1; }

# -- Set $CRON_CMD with $WP_ROOT
CRON_CMD="$CRON_CMD --path=$WP_ROOT" # - Command to run

# ------------------
# --- Start Cron Job
# ------------------

# Log the start time
START_TIME=$(date +%s.%N)

# Log header
LOG="==================================================
== Cron job start in $WP_ROOT $(echo $START_TIME|date +"%Y-%m-%d %H:%M:%S")
==================================================
"

# Run $CRON_CMD
CRON_OUTPUT="$(eval $CRON_CMD)"

# Check if there was an error running $CRON_CMD
if [[ $? -ne 0 ]]; then
    LOG+="Error: $CRON_CMD - command failed: $CRON_OUTPUT" >&2
    LOG+="$CRON_OUTPUT"
    if [[ -n "$POST_CRON_CMD" ]]; then
        eval "$POST_CRON_CMD"
    fi
else
        LOG+="$CRON_OUTPUT"
        # Check if heartbeat monitoring is enabled and send a request to the heartbeat URL if it is and there are no errors
        if [[ -n "$HEARTBEAT_URL" ]] && [[ $? -eq 0 ]] ; then
        curl -I -s "$HEARTBEAT_URL" > /dev/null
        LOG+="\n==== Sent Heartbeat to $HEARTBEAT_URL"
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
        LOG+="$(eval "$POST_CRON_CMD")"
    fi

        # Write cron job completed time and cpu usage.
fi

LOG+="\n===============================================
== Cron job completed in $TIME_SPENT seconds with $CPU_USAGE% CPU usage.
===============================================
== Cron job End - $(echo $END_TIME | date +"%Y-%m-%d %H:%M:%S")
==============================================="

# --------------
# --- Logging
# --------------

# Check if logging to stdout is enabled
[[ $LOG_TO_STDOUT == "1" ]] && { echo "Logging to stdout";echo -e "$LOG"; }
# Check if logging to syslog is enabled
[[ $LOG_TO_SYSLOG == "1" ]] && { echo "Logging to syslog";echo -e "$LOG" | logger -t "wordpress-cron-$DOMAIN_NAME"; }
# Check if logging to log file is enabled
[[ $LOG_TO_FILE == "1" ]] && { echo "Logging to stdout";echo -e "$LOG" >> $LOG_FILE; }
