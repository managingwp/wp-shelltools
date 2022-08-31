#!/bin/bash
# -- Variables
VERSION="0.0.3"
SCRIPT="attackscan.sh"
OLS_LOG_DIR="/var/log/ols"
NGINX_LOG_DIR="/var/log/nginx"

# -- _error
_error () {
        echo "## ERROR $@"
}

# -- usage
usage () {
        echo "$SCRIPT [-top <lines>|-scan]"
        echo "Version: $VERSION"
		echo ""
		echo "Parses Nginx and OLS web server access logs to find top number of requests and common attack requests for WordPress."
        echo ""
        echo "Commands:"
        echo " -top         -List top number of requests from the webserver access log."
        echo " -scan        -List common attack requests that return a 200 status code, by IP address."
		echo ""
		echo "Options:"
		echo " <lines>   -How many lines to show, if not specified defaults to 10"
        echo ""
        echo "Examples"
        echo "   $SCRIPT -top 20"
        echo "   $SCRIPT -scan"
        echo ""
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
        elif [[ $SERVER == "nginx" ]]; then
        	LOG_FILES=($(ls ${LOGS}/*.access.log))
            for SITE in "${LOG_FILES[@]}"; do
                echo "** Parsing ${SITE} for top ${LINES} requests"
                cat ${SITE} | awk {' print $8 '} | sort | uniq -c | sort -nr | head -n ${LINES}
                echo "======================"
            done        
        else
        	_error "Something went wrong"        
		fi
}

scan () {
	SERVER=$1
	LOGS=$2
	LINES=$3
	
	echo "Server: $SERVER - Logs: $LOGS - Lines: $LINES" 
	if [[ $SERVER == "ols" ]]; then
		LOG_FILES=($(ls ${LOGS}/*.access.log))
		for SITE in "${LOG_FILES[@]}"; do
			 echo "** Parsing ${SITE}"
             cat ${SITE} | awk {' print $7 "," $1 "," $9 '} | sed 's/"//' | grep -v "redirect_to" | grep "200" | egrep -e "xmlrpc|wp-login" | sort | uniq -c | sort -nr | head -n ${LINES}
             echo "======================"
        done
	elif [[ $SERVER == "nginx" ]]; then
        LOG_FILES=($(ls ${LOGS}/*.access.log))
        for SITE in "${LOG_FILES[@]}"; do
             echo "** Parsing ${SITE}"
             cat ${SITE} | awk {' print $3 "," $8 "," $10 '} | sed 's/"//' | grep -v "redirect_to" | grep "200" | egrep -e "xmlrpc|wp-login" | sort | uniq -c | sort -nr | head -n ${LINES}
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
        SERVER="nginx"
        LOGS="/var/log/nginx"
else
        _error "Didn't find any logs"
    exit 1
fi

# -- lines
LINES=""
if [[ -n $2 ]]; then
	LINES="$2"
else
	LINES="10"
fi

# -- top command
if [[ $1 == "-top" ]]; then
    echo " -- Showing top $LINES requests per log file"
    top $SERVER $LOGS $LINES
# -- scan command
elif [[ $1 == "-scan" ]]; then
    echo " - Running a scan for common attack requests"
	scan $SERVER $LOGS $LINES
fi

