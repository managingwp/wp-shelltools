#!/bin/bash
# ------------------
# -- wpst-goacces.sh
# ------------------

# -----------
# -- Includes
# -----------
. $(dirname "$0")/functions.sh

# ------------
# -- Variables
# ------------
DEBUG_ON="0"

# ------------
# -- Functions
# ------------

usage () {
    echo "Usage: goaccess [-d|-c] [--domain domain.com|--all]"
	echo ""
	echo "  Commands"
	echo "    -domain <domain>      - Domain name of log files to process"
    echo "    -all                  - Go through all the logs versus a single domain"
	echo ""
    echo "  Options:"
    echo "    -c|--compress        - Process compressed log files"
    echo "    -d|--debug           - Debug"
    echo "    -dr                  - Dry Run"
    echo ""
}

do_goaccess () {	
	_debug "Checking if goaccess is installed"
	_cexists goaccess
	_debug "\$CMD_EXISTS: $CMD_EXISTS"
	if [[ $CMD_EXISTS == "1" ]]; then
		_error "goaccess is not installed"
		return 1
	else
		_debug "Confirmed goaccess is installed"
	fi
		
	# Formats for goaccess
	# OLS
	# logformat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-agent}i\"
	# "192.168.0.1 - - [13/Sep/2022:16:28:40 -0400] "GET /request.html HTTP/2" 200 46479 "https://domain.com/referer.html" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/105.0.0.0 Safari/537.36"
	OLS_LOG_FORMAT='\"%h - - [%d:%t %^] \"%r\" %s %b \"%R\" \"%u\"'
	OLS_DATE_FORMAT='%d/%b/%Y'
	OLS_TIME_FORMAT='%H:%M:%S %Z'
	
	# NGINX
	# log_format we_log '[$time_local] $remote_addr $upstream_response_time $upstream_cache_status $http_host "$request" $status $body_bytes_sent $request_time "$http_referer" "$http_user_agent" "$http3"';
	# [14/Sep/2022:10:12:55 -0700] 129.168.0.1 - domain.com "GET /request.html HTTP/1.1" 200 47 1.538 "https://domain.com/referer.html" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/105.0.0.0 Safari/537.36"
    NGINX_LOG_FORMAT='[%d:%t %^] %h %^ - %v \"%r\" %s %b \"%R\" \"%u\"\'
    NGINX_DATE_FORMAT='%d/%b/%Y'
    NGINX_TIME_FORMAT='%H:%M:%S %Z'

    _debug "goaccess arguments - $ACTION"
    _debug "goaccess LOG_FORMAT = $LOG_FORMAT ## DATE_FORMAT = $DATE_FORMAT ## TIME_FORMAT = $TIME_FORMAT"
    # -- Check args.

	_debug "Detecting log files"    
    if [[ -d /usr/local/lsws ]]; then
    	WEB_SERVER="OLS"
        LOG_FORMAT=$OLS_LOG_FORMAT
        DATE_FORMAT=$OLS_DATE_FORMAT
        TIME_FORMAT=$OLS_TIME_FORMAT
    	if [[ $ACTION == "ALL" ]]; then
    		LOG_FILE_LOCATION="/var/www/*/logs"
    		LOG_FILTER="*.access.log*gz"
    	elif [[ $ACTION == "DOMAIN" ]]; then
	    	LOG_FILE_LOCATION="/var/www/$DOMAIN/logs"
	    	LOG_FILTER="*.access.log"
	    fi
    elif [[ -d /var/log/nginx ]]; then
    	WEB_SERVER="NGINX"
        LOG_FORMAT=$NGINX_LOG_FORMAT
        DATE_FORMAT=$NGINX_DATE_FORMAT
        TIME_FORMAT=$NGINX_TIME_FORMAT
    	LOG_FILE_LOCATION="/var/log/nginx"

		if [[ $ACTION == "ALL" ]]; then
		   	LOG_FILTER="*.access.log"
		elif [[ $ACTION == "DOMAIN" ]]; then
			LOG_FILTER="$DOMAIN.access.log"
		fi
    else
    	_error "Can't detect webserver logs"
    fi
    
	_debug "Webserver detected as $WEB_SERVER"

	if [[ $ACTION == "DOMAIN" ]]; then
		if [[ $DRY_RUN == "1" ]]; then
			ls -al ${LOG_FILE_LOCATION}/${LOG_FILTER}
			echo "cat ${LOG_FILE_LOCATION}/${LOG_FILTER} | goaccess --log-format='$LOG_FORMAT' --date-format='$DATE_FORMAT' --time-format='$TIME_FORMAT'"
		else
			cat ${LOG_FILE_LOCATION}/${LOG_FILTER} | goaccess --log-format="${LOG_FORMAT}" --date-format="$DATE_FORMAT" --time-format="$TIME_FORMAT"
		fi
	elif [[ $ACTION == "ALL" ]]; then
		if [[ $DRY_RUN == "1" ]]; then
			ls -al ${LOG_FILE_LOCATION}/${LOG_FILTER}
			echo "zcat ${LOG_FILE_LOCATION}/${LOG_FILTER} | goaccess --log-format='$LOG_FORMAT' --date-format='$DATE_FORMAT' --time-format='$TIME_FORMAT'"
		else
			( cat ${LOG_FILE_LOCATION}/*.access.log; zcat ${LOG_FILE_LOCATION}/${LOG_FILTER} ) | goaccess --log-format="$LOG_FORMAT" --date-format="$DATE_FORMAT" --time-format="$TIME_FORMAT"
		fi
	fi
}

# ---------------
# -- Main Program
# ---------------
DCMD=""
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    -d|--debug)
    DEBUG_ON="1"
    DCMD+="DEBUG_ON=1 "
    shift # past argument
    ;;
    -c|--compess)
	DCMD+="COMPRESS_FILES=1 "
    COMPRESS_FILES="1"
    shift # past argument
    ;;
    -dr)
    DRY_RUN="1"
    DCMD+="DRY_RUN=1 "
    shift # past argument
    ;;
    --domain)
    ACTION="DOMAIN"
    DOMAIN="$2"
    DCMD+="ACTION=DOMAIN DOMAIN=$2 "
    shift # past argument
    shift # past value
    ;;
	--all)
    ACTION="ALL"
    DCMD+="ACTION=ALL "
    shift # past argument
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

_debug "Running wpst-goaccess $DCMD"
_debug_all $@

if [[ -z $ACTION ]]; then
	usage
else
	do_goaccess $ACTION
fi