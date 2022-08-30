#!/bin/bash
# v0.0.2

# -- Variables
VERSION="0.0.2"
SCRIPT="attackscan.sh"
OLS_LOG_DIR="/var/log/ols"
NGINX_LOG_DIR="/var/log/nginx"

# -- _error
_error () {
        echo "## ERROR $@"
}

# -- usage
usage () {
        echo "$SCRIPT [-top <number>|-scan]"
        echo "Version: $VERSION"
        echo ""
        echo "Commands"
        echo " -top      -Show top number of requests, defaults to 10 unless specified"
        echo " -scan     -Scan for common attack requests that return a 200 status code"
        echo ""
        echo "Examples"
        echo "   $SCRIPT -top 20"
        echo "   $SCRIPT -scan"
}

# -- top-ols $SERVER $LOGS $LINES
top () {
        SERVER=$1
        LOGS=$2
        LINES=$3
        echo "Server: $SERVER - Logs: $LOGS - Lines: $LINES"
        if [[ $SERVER == "ols" ]]; then
                LOG_FILES=($(ls ${LOGS}/*.access.log))
            for SITE in "${LOG_FILES[@]}"; do
                echo "** Parsing ${SITE} for top ${LINES} requests"
                cat ${SITE} | awk {' print $7 '} | sort | uniq -c | sort -nr | head -n ${LINES}
                echo "======================"
        done
    fi
}

# -- main
if [[ -z $1 ]]; then
        usage
        exit 1
fi

# -- logs to process
if [[ -d $OLS_LOG_DIR ]]; then
        echo " -- Found OLS logs at /var/log/ols"
        SERVER="ols"
        LOGS="/var/log/ols"
elif [[ -d /var/log/nginx ]]; then
        echo " -- Found Nginx logs at /var/log/nginx"
        server="nginx"
        LOGS="/var/log/nginx"
else
        _error "Didn't find any logs"
    exit 1
fi

# -- top command
if [[ $1 == "-top" ]]; then
        # -- lines to output
    LINES=""
    if [[ -n $2 ]]; then
        LINES="$2"
    else
        LINES="10"
    fi
    echo " -- Showing top $LINES requests per log file"
        top $SERVER $LOGS $LINES
# -- scan command
elif [[ $1 == "-scan" ]]; then
        echo " - Running a scan for common attack requests"

        scan ols
fi
