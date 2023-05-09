#!/bin/bash
# -- Created by Jordan - hello@managingwp.io - https://managingwp.io

# Set up the necessary variables
WP_CLI="/usr/local/bin/wp" # - Location of wp-cli
WP_ROOT="/path/to/wordpress" # - Path to WordPress
LOG_TO_SYSLOG="1" # - Log to syslog? 0 = no, 1 = yes
LOG_TO_FILE="0" # - Log to file? 0 = no, 1 = yes
LOG_FILE="${WP_ROOT}/wordpress-crons.log" # Location for wordpress cron.
HEARTBEAT_URL="https://betteruptime.com/api/v1/heartbeat/v25v234v4634b636v3" # - Heartbeat monitoring URL
POST_CRON_CMD="" # - Command to run after cron completes
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Check if wp-cli is installed
[[ $(command -v $WP_CLI) ]]  || { echo 'Error: wp-cli is not installed.' >&2; exit 1; }

# Check if $WP_ROOT exists
if [[ ! -d "$WP_ROOT" ]]; then
    if [[ -d $SCRIPT_DIR/htdocs ]]; then
        WP_ROOT=$SCRIPT_DIR/htdocs
    elif [[ -d $SCRIPT_DIR/public_html ]]; then
        WP_ROOT=$SCRIPT_DIR/public_html
    else
        echo "Error: $WP_ROOT does not exist." >&2; exit 1;
    fi
fi

# Check if $WP_ROOT contains a WordPress install
[[ WP_ROOT_INSTALL=$(wp --path=$WP_ROOT --skip-plugins --skip-themes core is-installed  2> /dev/null) ]] || { echo "Error: $WP_ROOT is not a WordPress install.\n$WP_ROOT_INSTALL " >&2; exit 1; }

# Get the domain name of the WordPress install
DOMAIN_NAME=$($WP_CLI --path=$WP_ROOT --skip-plugins --skip-themes option get siteurl 2> /dev/null | grep -oP '(?<=//)[^/]+')
[[ $? -ne 0 ]] && { echo "Error: Could not get domain name.\n$DOMAIN_NAME"; exit 1; }

# Log the start time
START_TIME=$(date +%s.%N)

# Run WordPress crons due now and log the output
CRON_OUTPUT=$($WP_CLI --skip-plugins --skip-themes cron event run --due-now --path=$WP_ROOT 2>&1)

# Check if there was an error running wp-cli command
if [[ $? -ne 0 ]]; then
    echo "Error: wp-cli command failed" >&2
    echo "$CRON_OUTPUT"
    if [[ -n "$POST_CRON_CMD" ]]; then
        eval "$POST_CRON_CMD"
    fi
    exit 1
fi

# Check if heartbeat monitoring is enabled and send a request to the heartbeat URL if it is and there are no errors
if [[ -n "$HEARTBEAT_URL" ]] && [[ $? -eq 0 ]] ; then
    curl -I -s "$HEARTBEAT_URL" > /dev/null
fi

# Log the end time and CPU usage
END_TIME=$(date +%s.%N)

# check if bc installed otherwise use awk
if [[ $(command -v bc) ]]; then
    TIME_SPENT=$(echo "$END_TIME - $START_TIME" | bc)
else
    TIME_SPENT=$(echo "$END_TIME - $START_TIME" | awk '{printf "%f", $1 - $2}')
fi
CPU_USAGE=$(ps -p $$ -o %cpu | tail -n 1)

# Check if logging to syslog is enabled
if [[ $LOG_TO_SYSLOG == "1" ]]; then
    echo -e "Cron job completed in $TIME_SPENT seconds with $CPU_USAGE% CPU usage. \nOutput: $CRON_OUTPUT" | logger -t "wordpress-crons-$DOMAIN_NAME"
elif [[ $LOG_TO_FILE == "1" ]]; then
    # Log to file in the WordPress install directory
    echo "$(date +"%Y-%m-%d %H:%M:%S") - WordPress crons completed in $TIME_SPENT seconds with $CPU_USAGE% CPU usage. \nOutput: $CRON_OUTPUT" >> $LOG_FILE
fi
