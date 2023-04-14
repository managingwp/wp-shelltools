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
	USAGE=\
"Usage: wpst-goaccess [-h|-d|-c|-dr|-f (nginx|ols)|-p [(gridpane|runcloud)] [-ld <log directory>|-l <log file>|-time <timerange>] [-domain domain.com|--all|-file <filename> [-p (gridpane|runcloud)]
	
    This script will try and detect log files in common locations, you can also
    specify the platform and format using the options below
	
    Commands
        -domain <domain>              - Domain name of log files to process
        -all                          - Go through all the logs versus a single log file
        -file <filename>              - Process a single file
        -time <timerange>             - Specify a time range to process
	
    Options:
        -h          - Help		
        -d          - Debug
        -dr         - Dry Run
        -p          - Specify platform (gridpane|runcloud)
        -f          - Override detected format, (nginx|ols)
        -t          - Use test log files

    "
	echo "$USAGE"
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
	if [[ $FORMAT == "GPNGINX" ]]; then
		LOG_FORMAT='[%d:%t %^] %h %^ - %v \"%r\" %s %b \"%R\" \"%u\"\'
		DATE_FORMAT='%d/%b/%Y'
		TIME_FORMAT='%H:%M:%S %Z'
	fi

	# GRIDPANE-OLS
	if [[ $FORMAT == "GPOLS" ]]; then
        LOG_FORMAT='[%d:%t %^] %h %^ - %v \"%r\" %s %b \"%R\" \"%u\"\'
        DATE_FORMAT='%d/%b/%Y'
        TIME_FORMAT='%H:%M:%S %Z'
    fi

    _debug "goaccess LOG_FORMAT = $LOG_FORMAT ## DATE_FORMAT = $DATE_FORMAT ## TIME_FORMAT = $TIME_FORMAT"
}

detect_logs () {
	echo "Detecting log files"
	# TODO figure out how to test and set the format better.

	# GRIDPANE-OLS
    if [[ -d /usr/local/lsws ]] && [[ -d /var/www/ ]]; then
        echo "Detected GridPane OLS logs"
        FORMAT="GPOLS"
        if [[ $ACTION == "ALL" ]]; then
            LOG_FILE_LOCATION="/var/www/*/logs"
            LOG_FILTER="*.access.log*gz"
        elif [[ $ACTION == "DOMAIN" ]]; then
            LOG_FILE_LOCATION="/var/www/$DOMAIN/logs"
            LOG_FILTER="*.access.log"
        elif [[ $ACTION == "FILE" ]]; then
			LOG_FILE_LOCATION="$FILE"
		fi
    elif [[ -d /var/log/nginx ]] && [[ -d /var/www/ ]]; then
        echo "Detected GridPane NGINX logs"
        FORMAT="GPNGINX"
        if [[ $ACTION == "ALL" ]]; then
            LOG_FILE_LOCATION="/var/log/nginx"
            LOG_FILTER="*.access.log*gz"
        elif [[ $ACTION == "DOMAIN" ]]; then
            LOG_FILE_LOCATION="/var/log/nginx"
            LOG_FILTER="*${DOMAIN}*.access.log"
        elif [[ $ACTION == "FILE" ]]; then
			LOG_FILE_LOCATION="$FILE"
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
	    elif [[ $ACTION == "FILE" ]]; then
			LOG_FILE_LOCATION="$FILE"		
		fi
	# NGINX
    elif [[ -d /var/log/nginx ]]; then
        echo "Detected GridPane Nginx logs"
		FORMAT="OLS"
    	LOG_FILE_LOCATION="/var/log/nginx"

		if [[ $ACTION == "ALL" ]]; then
		   	LOG_FILTER="*.access.log"
		elif [[ $ACTION == "DOMAIN" ]]; then
			LOG_FILTER="$DOMAIN.access.log"
		elif [[ $ACTION == "FILE" ]]; then
			LOG_FILE_LOCATION="$FILE"
		fi
    else
    	_error "Can't detect webserver logs"
    	exit
    fi

	_debug "FORMAT:$FORMAT LOG_FILE_LOCATION:$LOG_FILE_LOCATION LOG_FILTER:$LOG_FILTER"
}

# -- collect_logs
collect_logs () {
	local CATCMD="cat"
	_debug "Format: $FORMAT Log File Location:$LOG_FILE_LOCATION Log Filter: $LOG_FILTER"
	LOG_COLLECT_DATA=$(mktemp)
	if [[ $ACTION == "DOMAIN" ]]; then
		if [[ $DRY_RUN == "1" ]]; then
			ls -al ${LOG_FILE_LOCATION}/${LOG_FILTER}
		else
			cat ${LOG_FILE_LOCATION}/${LOG_FILTER} > $LOG_COLLECT_DATA
		fi
	elif [[ $ACTION == "ALL" ]]; then
		if [[ $DRY_RUN == "1" ]]; then
			ls -al ${LOG_FILE_LOCATION}/${LOG_FILTER}
		else
			cat ${LOG_FILE_LOCATION}/*.access.log > $LOG_COLLECT_DATA; zcat ${LOG_FILE_LOCATION}/${LOG_FILTER} >> $LOG_COLLECT_DATA
		fi
	elif [[ $ACTION == "FILE" ]]; then
		if [[ $DRY_RUN == "1" ]]; then
			ls -al ${LOG_FILE_LOCATION}
		else
			[[ $LOG_FILE_LOCATION == "*.gz" ]] && CATCMD="zcat"
			$CATCMD ${LOG_FILE_LOCATION} > $LOG_COLLECT_DATA
		fi
	fi
	LOG_DATA_FILE=$LOG_COLLECT_DATA
}

# -- do_goaccess
do_goaccess () {
	_debug "Format: $FORMAT Log File Location:$LOG_FILE_LOCATION Log Filter: $LOG_FILTER Log Data: $LOG_DATA_FILE"

	if [[ $ACTION == "DOMAIN" ]]; then
		if [[ $DRY_RUN == "1" ]]; then
			ls -al ${LOG_FILE_LOCATION}
			echo "cat ${LOG_FILE_LOCATION}/${LOG_FILTER} | goaccess --log-format='$LOG_FORMAT' --date-format='$DATE_FORMAT' --time-format='$TIME_FORMAT'"
		else
			cat $LOG_DATA_FILE | goaccess --log-format="${LOG_FORMAT}" --date-format="$DATE_FORMAT" --time-format="$TIME_FORMAT"
		fi
	elif [[ $ACTION == "ALL" ]]; then
		if [[ $DRY_RUN == "1" ]]; then
			ls -al ${LOG_FILE_LOCATION}/${LOG_FILTER}
			echo "cat $LOG_DATA_FILE | goaccess --log-format='$LOG_FORMAT' --date-format='$DATE_FORMAT' --time-format='$TIME_FORMAT'"
		else
			cat $LOG_DATA_FILE | goaccess --log-format="$LOG_FORMAT" --date-format="$DATE_FORMAT" --time-format="$TIME_FORMAT"
		fi
	elif [[ $ACTION == "FILE" ]]; then
		[[ $LOG_FILE_LOCATION == "*.gz" ]] && CATCMD="zcat"
		if [[ $DRY_RUN == "1" ]]; then
			ls -al ${LOG_FILE_LOCATION}
			echo "cat $LOG_DATA_FILE | goaccess --log-format='$LOG_FORMAT' --date-format='$DATE_FORMAT' --time-format='$TIME_FORMAT'"
		else
			cat $LOG_DATA_FILE | goaccess --log-format="$LOG_FORMAT" --date-format="$DATE_FORMAT" --time-format="$TIME_FORMAT"
		fi
	elif [[ $ACTION == "TEST" ]]; then
		[[ $LOG_FILE_LOCATION == "*.gz" ]] && CATCMD="zcat"
		if [[ $DRY_RUN == "1" ]]; then
			ls -al ${LOG_FILE_LOCATION}
			echo "cat ${LOG_FILE_LOCATION} | goaccess --log-format='$LOG_FORMAT' --date-format='$DATE_FORMAT' --time-format='$TIME_FORMAT'"
		else
			$CATCMD ${LOG_FILE_LOCATION} | goaccess --log-format="$LOG_FORMAT" --date-format="$DATE_FORMAT" --time-format="$TIME_FORMAT"
		fi
	else
		echo "No action specified"
		exit
	fi
}

function sed_logs() {
	_debug "Processing logs using custom time - $CUSTOM_TIME"
	SED_LOG=$(mktemp)
    if [[ ! $CUSTOM_TIME =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2},[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}$ ]]; then
        echo "Error: Please provide dates in the format yyyy-mm-dd-hh-mm-ss,yyyy-mm-dd-hh-mm-ss"
        return 1
    fi
    
    local start_date=$(date -d "${1%-*}" +"%d\/%b\/%Y:%H:%M:%S")
    local end_date=$(date -d "${1#*-}" +"%d\/%b\/%Y:%H:%M:%S")
    sed -n "/$start_date/,/$end_date/ p" $LOG_DATA_FILE > $SED_LOG
	LOG_DATA=$SED_LOG
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
    -h)
    ACTION="HELP"
	DCMD+="ACTION=$2 "
    shift # past argument
    ;;
    -platform)
    PLATFORM="$2"
	DCMD+="PLATFORM=$2 "
    shift # past argument
    shift # past value
    ;;
	-f|--format)
	FORMAT="$2"
	DCMD+="FORMAT=$2 "
	shift # past argument
	shift # past value
	;;
    -d|--debug)
    DEBUG_ON="1"
    DCMD+="DEBUG_ON=1 "
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
    DCMD+="ACTION=DOMAIN DOMAIN=$2"
    shift # past argument
    shift # past value
    ;;
	-all)
    ACTION="ALL"
    DCMD+="ACTION=ALL "
    shift # past argument
    ;;
	-file)
    ACTION="FILE"
	FILE="$2"
    DCMD+="ACTION=FILE FILE=$2 "
    shift # past argument
	shift # past value
    ;;
	-t)
    ACTION="TEST"
	FILE="$2"
    DCMD+="ACTION=TEST FILE=$2"
    shift # past argument
	shift # past value
    ;;
	-time)
	CUSTOM_TIME="$2"
	DCMD+="CUSTOM_TIME=$2"
	shift # past argument
	shift # past value
	;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

_debug "Running wpst-goaccess $DCMD"
_debug_all "${*}"

if [[ -z $ACTION ]] || [[ $ACTION == "HELP" ]]; then
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
	collect_logs
	[[ $CUSTOM_TIME ]] && sed_logs $CUSTOM_TIME
	do_goaccess $ACTION $LOG_DATA_FILE
fi