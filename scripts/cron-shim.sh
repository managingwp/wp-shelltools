#!/bin/bash
# -- Created by Jordan - hello@managingwp.io - https://managingwp.io

# Set up the necessary variables
WP_CLI="/usr/local/bin/wp" # - Location of wp-cli
WP_ROOT="/path/to/wordpress" # - Path to WordPress
LOG_TO_SYSLOG="0" # - Log to syslog? 0 = no, 1 = yes
LOG_TO_FILE="0" # - Log to file? 0 = no, 1 = yes
LOG_FILE="${WP_ROOT}/wordpress-crons.log" # Location for wordpress cron.
HEARTBEAT_URL="https://betteruptime.com/api/v1/heartbeat/v25v234v4634b636v3" # - Heartbeat monitoring URL
POST_CRON_CMD="" # - Command to run after cron completes

# Check if wp-cli is installed
[[ $(command -v $WP_CLI) ]]  || { echo 'Error: wp-cli is not installed.' >&2; exit 1; }

# Check if $WP_ROOT exists
[[ -d "$WP_ROOT" ]] || { echo "Error: $WP_ROOT does not exist." >&2; exit 1; }

# Check if $WP_ROOT contains a WordPress install
[[ $(wp --skip-plugins --skip-themes core is-installed --path=$WP_ROOT 2> /dev/null) ]] || { echo "Error: $WP_ROOT is not a WordPress install." >&2; exit 1; }

# Log the start time
START_TIME=$(date +%s.%N)

# Run WordPress crons due now and log the output
CRON_OUTPUT=$($WP_CLI --skip-plugins --skip-theme cron event run --due-now --path=$WP_ROOT 2>&1)

# Check if there was an error running wp-cli command
if [[ $? -ne 0 ]]; then
    echo "Error: wp-cli command failed" >&2
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
TIME_SPENT=$(echo "$END_TIME - $START_TIME" | bc)
CPU_USAGE=$(ps -p $$ -o %cpu | tail -n 1)

# Check if logging to syslog is enabled
if [[ $LOG_TO_SYSLOG == "1" ]]; then
    logger -t "wordpress-crons" "Cron job completed in $TIME_SPENT seconds with $CPU_USAGE% CPU usage. \nOutput: $CRON_OUTPUT"
elif [[ $LOG_TO_FILE == "1" ]]; then
    # Log to file in the WordPress install directory
    echo "$(date +"%Y-%m-%d %H:%M:%S") - WordPress crons completed in $TIME_SPENT seconds with $CPU_USAGE% CPU usage. \nOutput: $CRON_OUTPUT" >> $LOG_FILE
fi
