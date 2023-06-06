#!/bin/bash
# ------------------
# -- wpst-goacces.sh
# ------------------
SCRIPT_DIR="$( dirname "$0")"
source $SCRIPT_DIR/../lib/functions.sh

# -- Variables
TEST_LOG="$SCRIPT_DIR/../tests/wpst-goaccess-gpnginx.log"
BROWSER_LIST_FILE="$SCRIPT_DIR/browsers.list"

#######################
# -- Functions
#######################

# -- usage
usage () {
	USAGE=\
"Usage: wpst-goaccess [-domain domain.com|-all|-file <logfile> [-p (gridpane|runcloud)]
	
    This script will try and detect log files in common locations.
	
    Commands
        -domain <domain>         - Domain name of log files to process
        -all                     - Go through all the logs versus a single log file
        -file <logfile>          - Process a single log file
        -time <timerange>        - Select time range, format yyyy-mm-dd-hh-mm-ss,yyyy-mm-dd-hh-mm-ss (e.g. 2017-01-01-00-00-00,2017-01-01-23-59-59)
        -compile                 - Compile latest goaccess from source      
        -test                    - Use test log files                        
	
    Options:
        -h          - Help		
        -d          - Debug
        -dr         - Dry Run
        -p          - Specify platform (gridpane|runcloud|custom)
        -f          - Override detected format, (nginx|ols|combined)
        -b          - Use browsers.list
        -u          - Log unknown user agents to unknown.log

    Examples:

Version: $WPST_VERSION
    "
	echo "$USAGE"
    check_goaccess_version
}

# -- check_goaccess
check_goaccess () {
	# -- Check if goaccess is installed
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

# -- check_goaccess_version
check_goaccess_version () {
    # -- Get goaccess version
    _debug "Getting goaccess version"
    GOACCESS_VERSION=$(goaccess -V | awk '{print $3}')
    _debug "\$GOACCESS_VERSION: $GOACCESS_VERSION"
    
    # -- Check if goaccess is at least version 1.7.2
    _debug "Checking if goaccess is at least version 1.7.2"
    if [[ $GOACCESS_VERSION < "1.7.2" ]]; then
        _warning "goaccess is not at least version 1.7.2, some features might not be available"        
    else
        _debug "Confirmed goaccess is at least version 1.7.2"
    fi
}

# -- compile_goaccess
function compile_goaccess () {
    _debug "Running compile_goaccess"
    
    # Check if goaccess is already installed
    _debug "Checking if goaccess is installed"
    _cexists goaccess
    _debug "\$CMD_EXISTS: $CMD_EXISTS"

    # If goaccess is installed, exit
    if [[ $CMD_EXISTS == "0" ]]; then
        _debug "goaccess is already installed"
        exit
    fi

    # Grab latest tar file using curl and place in /tmp
    _debug "Downloading latest goaccess tar file"
    curl -o /tmp/goaccess-1.7.2.tar.gz https://tar.goaccess.io/goaccess-1.7.2.tar.gz
    _debug "Extracting tar file"
    tar -xzvf /tmp/goaccess-1.7.2.tar.gz -C /tmp
    _debug "Changing directory to /tmp/goaccess-1.7.2"
    cd /tmp/goaccess-1.7.2
    
    # Compile goaccess
    _debug "Running ./configure --enable-utf8 --enable-geoip=mmdb"
    ./configure --enable-utf8 --enable-geoip=mmdb
    _debug "Running make"
    make
    _debug "Running make install"
    make install
}


# -- set_format
set_format () {
    _debug "Running set_format on $FORMAT"
	if [[ $FORMAT == "COMBINED" ]]; then
        _debug "Format is COMBINED"
        LOG_FORMAT="COMBINED"
    elif [[ $FORMAT == "OLS" ]]; then
    	# -- Log Formats for goaccess
        # Default OLS
        # logformat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-agent}i\"
        # "192.168.0.1 - - [13/Sep/2022:16:28:40 -0400] "GET /request.html HTTP/2" 200 46479 "https://domain.com/referer.html" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/105.0.0.0 Safari/537.36"    
        _debug "Setting OLS format"
		LOG_FORMAT='\"%h - - [%d:%t %^] \"%r\" %s %b \"%R\" \"%u\"'
		DATE_FORMAT='%d/%b/%Y'
		TIME_FORMAT='%H:%M:%S %Z'
	elif [[ $FORMAT == "NGINX" ]]; then
        # Default NGINX
        # log_format we_log '[$time_local] $remote_addr $upstream_response_time $upstream_cache_status $http_host "$request" $status $body_bytes_sent $request_time "$http_referer" "$http_user_agent" "$http3"';
        # [14/Sep/2022:10:12:55 -0700] 129.168.0.1 - domain.com "GET /request.html HTTP/1.1" 200 47 1.538 "https://domain.com/referer.html" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/105.0.0.0 Safari/537.36"
	
        _debug "Setting NGINX format"
		LOG_FORMAT='[%d:%t %^] %h %^ - %v \"%r\" %s %b \"%R\" \"%u\"\'
		DATE_FORMAT='%d/%b/%Y'
    	TIME_FORMAT='%H:%M:%S %Z'
    elif [[ $FORMAT == "GPNGINX" ]]; then
        # GRIDPANE-NGINX
        # ./common/logging.conf:log_format we_log '[$time_local] $remote_addr $upstream_response_time $upstream_cache_status $http_host "$request" $status $body_bytes_sent $request_time "$http_referer" "$http_user_agent"';
        # $request_time = seconds with a milliseconds resolution
        # [14/Apr/2023:06:30:32 -0500] 127.0.0.1 1.732 - domain.com "GET /?pwgc=1628918241 HTTP/2.0" 200 39563 1.731 "-" "Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm) Chrome/103.0.5060.134 Safari/537.36"
        # [27/Apr/2023:06:38:01 -0500] 2600:1700:4dce:28f0:ed74:ea35:b8e5:ece6 - - domain.com "GET /image.jpg HTTP/2.0" 304 0 0.000 "https://yahoo.com" "Mozilla/5.0 (iPhone; CPU iPhone OS 16_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/107.0.5304.66 Mobile/15E148 Safari/604.1"
	
        _debug "Setting GPNGINX format"    
		LOG_FORMAT='[%d:%t %^] %h %^ - %v \"%r\" %s %b %T \"%R\" \"%u\"\'
		DATE_FORMAT='%d/%b/%Y'
		TIME_FORMAT='%H:%M:%S %Z'
	elif [[ $FORMAT == "GPOLS" ]]; then
        # GRIDPANE-OLS
        _debug "Setting GPOLS format"
        LOG_FORMAT='[%d:%t %^] %h %^ - %v \"%r\" %s %b \"%R\" \"%u\"\'
        DATE_FORMAT='%d/%b/%Y'
        TIME_FORMAT='%H:%M:%S %Z'
    else
        echo "No format set, exiting"
        exit
    fi

    _debug "goaccess LOG_FORMAT = $LOG_FORMAT ## DATE_FORMAT = $DATE_FORMAT ## TIME_FORMAT = $TIME_FORMAT"
}

# -- detect_logs
function detect_logs () {
	echo "Detecting log files"

    # -- Check if $FORMAT is set
    if [[ -z $FORMAT ]]; then
        echo "No format set, checking for log files"
        if [[ -d /usr/local/lsws ]] && [[ -f /root/grid.id ]]; then
            echo "Detected GridPane OLS logs"
            FORMAT="GPOLS"
            [[ $ACTION == "ALL" ]] && { LOG_FILE_LOCATION="/var/www/*/logs"; LOG_FILTER="*.access.log*gz"; }
            [[ $ACTION == "DOMAIN" ]] && { LOG_FILE_LOCATION="/var/www/$DOMAIN/logs"; LOG_FILTER="*.access.log*gz"; }
            [[ $ACTION == "FILE" ]] && { LOG_FILE_LOCATION="$FILE"; }
        elif [[ -d /var/log/nginx ]] && [[ -f /root/grid.id ]]; then
            echo "Detected GridPane NGINX logs"
            FORMAT="GPNGINX"
            [[ $ACTION == "ALL" ]] && { LOG_FILE_LOCATION="/var/log/nginx"; LOG_FILTER="*.access.log*gz"; }
            [[ $ACTION == "DOMAIN" ]] && { LOG_FILE_LOCATION="/var/log/nginx"; LOG_FILTER="*.access.log*gz"; }
            [[ $ACTION == "FILE" ]] && { LOG_FILE_LOCATION="$FILE"; }
        elif [[ -d /etc/nginx ]] && [[ -d /var/log/nginx ]]; then
            echo "Detected NGINX logs"
            FORMAT="NGINX"
        elif [[ -d /usr/local/lsws ]]; then
            echo "Detected OLS logs"
            FORMAT="NGINX"
        else
            echo "No logs detected"
            exit
        fi
    else
        echo "Format set to ${FORMAT^^}"
        FORMAT="${FORMAT^^}"
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
			echo "cat ${LOG_FILE_LOCATION}/${LOG_FILTER} > $LOG_COLLECT_DATA"
		else
			cat ${LOG_FILE_LOCATION}/${LOG_FILTER} > $LOG_COLLECT_DATA
		fi
	elif [[ $ACTION == "ALL" ]]; then
		if [[ $DRY_RUN == "1" ]]; then
			echo "cat ${LOG_FILE_LOCATION}/*.access.log > $LOG_COLLECT_DATA; zcat ${LOG_FILE_LOCATION}/${LOG_FILTER} >> $LOG_COLLECT_DATA"
		else
			cat ${LOG_FILE_LOCATION}/*.access.log > $LOG_COLLECT_DATA; zcat ${LOG_FILE_LOCATION}/${LOG_FILTER} >> $LOG_COLLECT_DATA
		fi
	elif [[ $ACTION == "FILE" ]]; then
		if [[ $DRY_RUN == "1" ]]; then
			echo "$CATCMD ${LOG_FILE_LOCATION} > $LOG_COLLECT_DATA"
		else
			[[ $LOG_FILE_LOCATION == "*.gz" ]] && CATCMD="zcat"
			$CATCMD ${LOG_FILE_LOCATION} > $LOG_COLLECT_DATA
		fi
	fi
	LOG_DATA_FILE=$LOG_COLLECT_DATA
}

# -- do_goaccess
function do_goaccess () {
    _debug "Running do_goaccess"
    local $CMD
    local $GOACCESS_EXTRA

    # -- Set  Timespec    
    if [[ -n $TIME_SPEC ]]; then
        _debug "Setting time spec to $TIME_SPEC"
        GOACCESS_EXTRA+="--hour-spec='$TIME_SPEC' "
    fi

    # -- add browser-file
    if [[ -n $BROWSER_LIST ]]; then
        if [[ -f $BROWSER_LIST_FILE ]]; then
            _debug "Setting browser file to $BROWSER_LIST_FILE"
            GOACCESS_EXTRA+="--browsers-file='$BROWSER_LIST_FILE' "
        else
            echo "Browser list file not found, exiting"
            exit
        fi
    fi

    # -- Output unknown user agents
    if [[ $UNKNOWN_UA == "1" ]]; then
        _debug "Setting unknown user agents to be logged into /tmp/unknown.log"
        GOACCESS_EXTRA+="--unknowns-log='/tmp/unknown.log' "
    fi
    
    # -- If log format is combined
    if [[ $FORMAT == "COMBINED" ]]; then
        _debug "Setting COMBINED format"
        GOACCESS_EXTRA+="--log-format='COMBINED' "
    else        
        GOACCESS_EXTRA+="--log-format='$LOG_FORMAT' --date-format='$DATE_FORMAT' --time-format='$TIME_FORMAT' "
    fi

    # -- Run goaccess
    _debug "Proceeding with do_goaccess \$ACTION: $ACTION \$FILE: $FILE \$FORMAT: $FORMAT \$DRY_RUN: $DRY_RUN \$UNKNOWN_UA: $UNKNOWN_UA \$TIME_SPEC: $TIME_SPEC \$BROWSER_LIST: $BROWSER_LIST"
    [[ $LOG_FILE_LOCATION == "*.gz" ]] && CATCMD="zcat" || CATCMD="cat"
    CMD="$CATCMD $LOG_DATA_FILE | goaccess ${GOACCESS_EXTRA}"
    _debug "CMD: $CMD"
    [[ $DRY_RUN == "1" ]] && { echo $CMD; } || { eval "$CMD"; echo "CMD: $CMD"; }
}


# -- sed_logs
function sed_logs() {
	_debug "Processing logs using custom time - $CUSTOM_TIME"
	SED_LOG=$(mktemp)
	if ! [[ $CUSTOM_TIME =~ ^[0-9]{2}/(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)/[0-9]{4}:[0-9]{2}:[0-9]{2}:[0-9]{2},[0-9]{2}/(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)/[0-9]{4}:[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
    	echo "Error: Please provide dates in the format dd/Mon/yyyy:hh:mm:ss"
    	exit 1
	fi

	local EDATE=$(echo $CUSTOM_TIME | cut -d, -f1)
	local SDATE=$(echo $CUSTOM_TIME | cut -d, -f2)
    local START_DATE=$(date -d "$(echo "$SDATE" | sed 's/\// /g;s/:/ /')" +%s | xargs -I{} date -d "@{}" +'%d\/%b\/%Y:%H:%M:%S')
	local END_DATE=$(date -d "$(echo "$EDATE" | sed 's/\// /g;s/:/ /')" +%s | xargs -I{} date -d "@{}" +'%d\/%b\/%Y:%H:%M:%S')

	if [[ $DRY_RUN == "1" ]]; then
		echo "sed -n \"/$START_DATE/,/$END_DATE/ p\" $LOG_DATA_FILE > $SED_LOG"
	else
		sed -n "/$START_DATE/,/$END_DATE/ p" $LOG_DATA_FILE > $SED_LOG
	fi	
	LOG_DATA_FILE=$SED_LOG
}


########################################
# -- Main 
########################################
ALLARGS="$@"
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    -h)
    ACTION="HELP"	
    shift # past argument
    ;;
    -p|--platform)
    PLATFORM="$2"	
    shift # past argument
    shift # past value
    ;;
	-f|--format)
	FORMAT="${2^^}"	
	shift # past argument
	shift # past value
	;;
    -d|--debug)
    DEBUG_ON="1"
    shift # past argument
    ;;
    -dr)
    DRY_RUN="1"
    shift # past argument
    ;;
    -domain)
    ACTION="DOMAIN"
    DOMAIN="$2"    
    shift # past argument
    shift # past value
    ;;
	-all)
    ACTION="ALL"
    shift # past argument
    ;;
	-file)
    ACTION="FILE"
	FILE="$2"
    shift # past argument
	shift # past value
    ;;
    -compile)
    ACTION="COMPILE"
    shift # past argument
    ;;
	-test)
    ACTION="TEST"	
    shift # past argument
    ;;
	-time)
	CUSTOM_TIME="$2"
	shift # past argument
	shift # past value
	;;
    -timespec)
    TIME_SPEC="$2"
    shift # past argument
    shift # past value
    ;;
    -b|--browser-list)
    BROWSER_LIST="1"
    shift # past argument
    ;;
    -u|--unknown-ua)
    UNKNOWN_UA="1"
    shift # past argument
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

# -- Debugging
_debug "\$ALLARGS: $ALLARGS"
_debug "============="
_debug "\$ACTION: $ACTION"
_debug "\$PLATFORM: $PLATFORM"
_debug "\$FORMAT: $FORMAT"
_debug "\$DOMAIN: $DOMAIN"
_debug "\$FILE: $FILE"
_debug "\$TIME_SPEC: $TIME_SPEC"
_debug "\$CUSTOM_TIME: $CUSTOM_TIME"
_debug "\$BROWSER_LIST: $BROWSER_LIST"
_debug "\$DRY_RUN: $DRY_RUN"
_debug "\$DEBUG_ON: $DEBUG_ON"
_debug "============="

# ----------------------------#
# --- Check Arguments
# ----------------------------#
if [[ -n $TIME_SPEC ]]; then
    if [[ $TIME_SPEC != "min" && $TIME_SPEC != "hour" ]]; then
        echo "Error: Invalid time specification"
        exit
    fi
fi

# --- Action

if [[ -z $ACTION ]] || [[ $ACTION == "HELP" ]]; then
	usage
	echo "Error: No action specified"
    exit
elif [[ $ACTION == "DOMAIN" ]]; then
    [[ -z $DOMAIN ]] && usage && echo "Error: specify a domain" && exit
    _debug "Running for domain $DOMAIN"
    
    # -- Process logs on domain
	check_goaccess
	detect_logs
	set_format
	collect_logs
	[[ ! -z $CUSTOM_TIME ]] && sed_logs $CUSTOM_TIME
	do_goaccess $ACTION $LOG_DATA_FILE
elif [[ $ACTION == "FILE" ]]; then
    [[ -z $FILE ]] && usage && echo "Error: specify a file" && exit
    _debug "Running for file $FILE"

    # -- Process logs on file
    check_goaccess
    detect_logs
    LOG_DATA_FILE=$FILE
    set_format    
    [[ ! -z $CUSTOM_TIME ]] && sed_logs $CUSTOM_TIME
    do_goaccess $ACTION $LOG_DATA_FILE
elif [[ $ACTION == "ALL" ]]; then
    _debug "Running for all domains"

    # -- Process logs on all domains
    check_goaccess
    detect_logs
    set_format
    collect_logs
    do_goaccess $ACTION $LOG_DATA_FILE
elif [[ $ACTION == "TEST" ]]; then
    _debug "Running for test"

    # -- Process logs on all domains
    check_goaccess
    LOG_DATA_FILE=$TEST_LOG
    [[ -z $FORMAT ]] && FORMAT="GPNGINX"
    set_format
    do_goaccess $ACTION $LOG_DATA_FILE
elif [[ $ACTION == "COMPILE" ]]; then
    _debug "Compiling goaccess"
    compile_goaccess
else
    echo "Error: Invalid action"
    exit
fi