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
    echo "Usage: wpst-goaccess [-d|-c] [-f (nginx|ols) [-domain domain.com|--all]"
	echo ""
	echo "This script will try and detect log files in common locations, you can also"
	echo "specify the platform and format using the options below"
	echo ""
	echo "  Commands"
	echo "    -domain <domain>              - Domain name of log files to process"
    echo "    -all                          - Go through all the logs versus a single domain"
	echo ""
    echo "  Options:"
	echo "    -ld         - Specify directory of log files"
	echo "    -l          - Specify log file"
	echo "    -p          - Specify platform (gridpane|runcloud)"
    echo "    -f          - Override detected format, (nginx|ols)"
    echo "    -c          - Process compressed log files"
    echo "    -d          - Debug"
    echo "    -dr         - Dry Run"
    echo ""
}

# -- check_goaccess
check_goaccess () {
	_debug "Checking if goaccess is installed"
	_cexists goaccess
	_debug "\$CMD_EXISTS: $CMD_EXISTS"
	if [[ $CMD_EXISTS == "1" ]]; then
		_error "goaccess is not installed"
		exit
	else
		_debug "Confirmed goaccess is installed"
	fi
}

# -- set_format
set_format () {
	# Formats for goaccess
	# OLS
	# logformat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-agent}i\"
	# "192.168.0.1 - - [13/Sep/2022:16:28:40 -0400] "GET /request.html HTTP/2" 200 46479 "https://domain.com/referer.html" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/105.0.0.0 Safari/537.36"
	if [[ $FORMAT == "OLS" ]]; then
		LOG_FORMAT='\"%h - - [%d:%t %^] \"%r\" %s %b \"%R\" \"%u\"'
		DATE_FORMAT='%d/%b/%Y'
		TIME_FORMAT='%H:%M:%S %Z'
	fi

	# NGINX
	# log_format we_log '[$time_local] $remote_addr $upstream_response_time $upstream_cache_status $http_host "$request" $status $body_bytes_sent $request_time "$http_referer" "$http_user_agent" "$http3"';
	# [14/Sep/2022:10:12:55 -0700] 129.168.0.1 - domain.com "GET /request.html HTTP/1.1" 200 47 1.538 "https://domain.com/referer.html" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/105.0.0.0 Safari/537.36"
	if [[ $FORMAT == "NGINX" ]]; then
		LOG_FORMAT='[%d:%t %^] %h %^ - %v \"%r\" %s %b \"%R\" \"%u\"\'
		DATE_FORMAT='%d/%b/%Y'
    	TIME_FORMAT='%H:%M:%S %Z'
    fi

	# GRIDPANE-NGINX
	# ./common/logging.conf:log_format we_log '[$time_local] $remote_addr $upstream_response_time $upstream_cache_status $http_host "$request" $status $body_bytes_sent $request_time "$http_referer" "$http_user_agent"';
	# [14/Apr/2023:06:30:32 -0500] 127.0.0.1 1.732 - domain.com "GET /?pwgc=1628918241 HTTP/2.0" 200 39563 1.731 "-" "Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm) Chrome/103.0.5060.134 Safari/537.36"
	if [[ $FORMAT == "GRIDPANE-NGINX" ]]; then
		LOG_FORMAT='[%d:%t %^] %h %^ - %v \"%r\" %s %b \"%R\" \"%u\"\'
		DATE_FORMAT='%d/%b/%Y'
		TIME_FORMAT='%H:%M:%S %Z'
	fi

	# GRIDPANE-OLS
	if [[ $FORMAT == "GRIDPANE-OLS" ]]; then
        LOG_FORMAT='[%d:%t %^] %h %^ - %v \"%r\" %s %b \"%R\" \"%u\"\'
        DATE_FORMAT='%d/%b/%Y'
        TIME_FORMAT='%H:%M:%S %Z'
    fi

    _debug "goaccess LOG_FORMAT = $LOG_FORMAT ## DATE_FORMAT = $DATE_FORMAT ## TIME_FORMAT = $TIME_FORMAT"
}

detect_logs () {
	echo "Detecting log files"

	# GRIDPANE-OLS
    if [[ -d /usr/local/lsws ]] && [[ -d /var/www/ ]]; then
        echo "Detected GridPane OLS logs"
        FORMAT="OLS"
        if [[ $ACTION == "ALL" ]]; then
            LOG_FILE_LOCATION="/var/www/*/logs"
            LOG_FILTER="*.access.log*gz"
        elif [[ $ACTION == "DOMAIN" ]]; then
            LOG_FILE_LOCATION="/var/www/$DOMAIN/logs"
            LOG_FILTER="*.access.log"
        fi
    elif [[ -d /var/log/nginx ]] && [[ -d /var/www/ ]]; then
        echo "Detected GridPane NGINX logs"
        FORMAT="NGINX"
        if [[ $ACTION == "ALL" ]]; then
            LOG_FILE_LOCATION="/var/log/nginx"
            LOG_FILTER="*.access.log*gz"
        elif [[ $ACTION == "DOMAIN" ]]; then
            LOG_FILE_LOCATION="/var/log/nginx"
            LOG_FILTER="*${DOMAIN}*.access.log"
        fi
	# OLS
    elif [[ -d /usr/local/lsws ]]; then
        echo "Detected OLS logs"
    	FORMAT="OLS"
    	if [[ $ACTION == "ALL" ]]; then
    		LOG_FILE_LOCATION="/var/www/*/logs"
    		LOG_FILTER="*.access.log*gz"
    	elif [[ $ACTION == "DOMAIN" ]]; then
	    	LOG_FILE_LOCATION="/var/www/$DOMAIN/logs"
	    	LOG_FILTER="*.access.log"
	    fi
	# NGINX
    elif [[ -d /var/log/nginx ]]; then
        echo "Detected GridPane Nginx logs"
    	LOG_FILE_LOCATION="/var/log/nginx"

		if [[ $ACTION == "ALL" ]]; then
		   	LOG_FILTER="*.access.log"
		elif [[ $ACTION == "DOMAIN" ]]; then
			LOG_FILTER="$DOMAIN.access.log"
		fi
    else
    	_error "Can't detect webserver logs"
    	exit
    fi
}

# -- do_goaccess
do_goaccess () {
	_debug "Format: $FORMAT Log File Location:$LOG_FILE_LOCATION Log Filter: $LOG_FILTER"

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
    -platform)
    PLATFORM="$2"
    shift # past argument
    shift # past value
    ;;
	-f|--format)
	FORMAT="$2"
	shift # past argument
	shift # past value
	;;
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
    -domain)
    ACTION="DOMAIN"
    DOMAIN="$2"
    DCMD+="ACTION=DOMAIN DOMAIN=$2 "
    shift # past argument
    shift # past value
    ;;
	-all)
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
	echo "Error: No action specified"
    exit
else
    if [[ $ACTION == "DOMAIN" ]] && [[ -z $DOMAIN ]]; then
        usage
        echo "Error: specify a domain"
        exit
    fi
	_debug "goaccess arguments - ${*}"
	check_goaccess
	detect_logs
	set_format
	do_goaccess $ACTION
fi