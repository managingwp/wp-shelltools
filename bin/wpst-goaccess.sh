#!/bin/bash
# ------------------
# -- wpst-goacces.sh
# ------------------
SCRIPT_DIR="$( dirname "$0")"
source $SCRIPT_DIR/../lib/functions.sh

# -- Variables
TEST_LOG="$SCRIPT_DIR/../tests/wpst-goaccess-gpnginx.log"
BROWSER_LIST_FILE="$SCRIPT_DIR/browsers.list"
PLATFORM=""
FORMAT=""

#######################
# -- Functions
#######################

# -- usage
usage () {
    DETECT_LOGS=$(detect_logs)
    CHECK_GOACCESS=$(check_goaccess)
	USAGE=\
"Usage: wpst-goaccess [-domain domain.com|-all|-file <logfile>] [-p (gridpane|runcloud)] [options]
	
    This script will try and detect log files in common locations.
	
    Actions:
        -domain <domain>         - Domain name of log files to process.
        -domain-all <domain>       - Go through all logs for the domain.
        -all-logs             - Go through all domains logs on the platform.
        -file <logfile>          - Process a single log file.

    Options:
        -time <timerange>        - Select time range, format yyyy-mm-dd-hh-mm-ss,yyyy-mm-dd-hh-mm-ss (e.g. 2017-01-01-00-00-00,2017-01-01-23-59-59)
        -compile                 - Compile latest goaccess from source      
        -403                     - Don't show 403 requests.
        -test                    - Use test log files       
        -p|--platform            - Override detected platform (gridpane|runcloud|custom)
        -f|--format              - Override detected format, (nginx|ols|combined)
        -b|--browsers            - Use browsers.list
        -u                       - Log unknown user agents to unknown.log                 
	
    Help:
        -h            - Help		
        -d                       - Debug
        -dr                      - Dry Run
        

    Examples:

Version: $WPST_VERSION
-- $DETECT_LOGS
-- $CHECK_GOACCESS
    "
	echo "$USAGE"    
}

# ==================================================
# -- check_goaccess
# ==================================================
function check_goaccess () {
    _debug "===== Running "
	# -- Check if goaccess is installed
	_cexists goaccess
	_debug "\$CMD_EXISTS: $CMD_EXISTS"
	if [[ $CMD_EXISTS == "1" ]]; then
		 _error "goaccess is not installed"
		exit
	else
		_debug "goaccess is installed"
        # -- Get goaccess version
        GOACCESS_VERSION=$(goaccess -V | head -1 | awk '{print $3}')
        _debug "\$GOACCESS_VERSION: $GOACCESS_VERSION"
        
        # -- Check if goaccess is at least version 1.7.2    
        if [[ $GOACCESS_VERSION < "1.7.2" ]]; then            
            _warning "goaccess $GOACCESS_VERSION installed. Require version 1.7.2 or greater, some features might not be available"        
        else
            _success "goaccess $GOACCESS_VERSION installed"
        fi
    fi
}

# ==================================================
# -- compile_goaccess
# ==================================================
function compile_goaccess () {
    _debug "===== Running compile_goaccess"
    
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

# ==================================================
# -- set_format
# ==================================================
function set_format () {
    _debug "===== Running set_format on $FORMAT"
    # Checking if format is overridden
    _debug "Checking if format is overridden"
    if [[ -n $SET_FORMAT ]]; then
        _debug "Format is overridden to $SET_FORMAT"
        FORMAT="$SET_FORMAT"
    fi
	if [[ $FORMAT == "combined" ]]; then
        _debug "Format is COMBINED"
        LOG_FORMAT="COMBINED"
    elif [[ $FORMAT == "ols" ]]; then
    	# -- Log Formats for goaccess
        # Default OLS
        # logformat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-agent}i\"
        # "192.168.0.1 - - [13/Sep/2022:16:28:40 -0400] "GET /request.html HTTP/2" 200 46479 "https://domain.com/referer.html" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/105.0.0.0 Safari/537.36"
        _debug "Setting OLS format"
		LOG_FORMAT='\"%h - - [%d:%t %^] \"%r\" %s %b \"%R\" \"%u\"'
		DATE_FORMAT='%d/%b/%Y'
		TIME_FORMAT='%H:%M:%S %Z'
	elif [[ $FORMAT == "nginx" ]]; then
        # Default NGINX
        # log_format we_log '[$time_local] $remote_addr $upstream_response_time $upstream_cache_status $http_host "$request" $status $body_bytes_sent $request_time "$http_referer" "$http_user_agent" "$http3"';
        # [14/Sep/2022:10:12:55 -0700] 129.168.0.1 - domain.com "GET /request.html HTTP/1.1" 200 47 1.538 "https://domain.com/referer.html" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/105.0.0.0 Safari/537.36"
	
        _debug "Setting NGINX format"
		LOG_FORMAT='[%d:%t %^] %h %^ - %v \"%r\" %s %b \"%R\" \"%u\"\'
		DATE_FORMAT='%d/%b/%Y'
    	TIME_FORMAT='%H:%M:%S %Z'
    elif [[ $FORMAT == "gpnginx" ]]; then
        # GRIDPANE-NGINX
        # ./common/logging.conf:log_format we_log '[$time_local] $remote_addr $upstream_response_time $upstream_cache_status $http_host "$request" $status $body_bytes_sent $request_time "$http_referer" "$http_user_agent"';
        # $request_time = seconds with a milliseconds resolution
        # [14/Apr/2023:06:30:32 -0500] 127.0.0.1 1.732 - domain.com "GET /?pwgc=1628918241 HTTP/2.0" 200 39563 1.731 "-" "Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm) Chrome/103.0.5060.134 Safari/537.36"
        # [27/Apr/2023:06:38:01 -0500] 2600:1700:4dce:28f0:ed74:ea35:b8e5:ece6 - - domain.com "GET /image.jpg HTTP/2.0" 304 0 0.000 "https://yahoo.com" "Mozilla/5.0 (iPhone; CPU iPhone OS 16_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/107.0.5304.66 Mobile/15E148 Safari/604.1"
	
        _debug "Setting GPNGINX format"    
		LOG_FORMAT='[%d:%t %^] %h %^ - %v \"%r\" %s %b %T \"%R\" \"%u\"\'
		DATE_FORMAT='%d/%b/%Y'
		TIME_FORMAT='%H:%M:%S %Z'
	# -- Not sure what this was for but doesn't work on GridPane currently
    elif [[ $FORMAT == "gpols" ]]; then
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

# ==================================================
# -- detect_logs
# ==================================================
function detect_logs () {
    _debug "===== Running detect_logs"

    # -- Check if $FORMAT is set
    if [[ -z $FORMAT ]]; then
        _debug "No format set, checking for log files"
        if [[ -d /usr/local/lsws ]] && [[ -f /root/grid.id ]]; then            
            FORMAT="ols"
            PLATFORM="gridpane"
            [[ $ACTION == "DOMAIN" ]] && { LOG_FILE_LOCATION="/var/www/$DOMAIN/logs"; LOG_FILTER="*.access.log"; }
            [[ $ACTION == "DOMAIN_ALL" ]] && { LOG_FILE_LOCATION="/var/www/$DOMAIN/logs"; LOG_FILTER="*.access.log*gz"; }
            [[ $ACTION == "ALL" ]] && { LOG_FILE_LOCATION="/var/www/*/logs"; LOG_FILTER="*.access.log"; }
            [[ $ACTION == "FILE" ]] && { LOG_FILE_LOCATION="$FILE"; }            
        elif [[ -d /var/log/nginx ]] && [[ -f /root/grid.id ]]; then            
            FORMAT="gpnginx"
            PLATFORM="gridpane"
            [[ $ACTION == "DOMAIN" ]] && { LOG_FILE_LOCATION="/var/log/nginx"; LOG_FILTER="$DOMAIN.access.log"; }
            [[ $ACTION == "DOMAIN_ALL" ]] && { LOG_FILE_LOCATION="/var/log/nginx"; LOG_FILTER="$DOMAIN.access.log*"; }
            [[ $ACTION == "ALL" ]] && { LOG_FILE_LOCATION="/var/log/nginx"; LOG_FILTER="*.access.log"; }            
            [[ $ACTION == "FILE" ]] && { LOG_FILE_LOCATION="$FILE"; }
        elif [[ -d /etc/nginx ]] && [[ -d /var/log/nginx ]]; then            
            FORMAT="nginx"
            PLATFORM="custom"
            [[ $ACTION == "DOMAIN" ]] && { LOG_FILE_LOCATION="/var/log/nginx"; LOG_FILTER="${DOMAIN}*access.log"; }
            [[ $ACTION == "DOMAIN_ALL" ]] && { LOG_FILE_LOCATION="/var/log/nginx"; LOG_FILTER="${DOMAIN}*access.log*"; }
            [[ $ACTION == "ALL" ]] && { LOG_FILE_LOCATION="/var/log/nginx"; LOG_FILTER="*access.log"; }            
            [[ $ACTION == "FILE" ]] && { LOG_FILE_LOCATION="$FILE"; }            
        elif [[ -d /usr/local/lsws ]]; then            
            FORMAT="ols"
            PLATFORM="custom"
            [[ $ACTION == "DOMAIN" ]] && { LOG_FILE_LOCATION="/usr/local/lsws/logs"; LOG_FILTER="$DOMAIN.access.log"; }
            [[ $ACTION == "DOMAIN_ALL" ]] && { LOG_FILE_LOCATION="/usr/local/lsws/logs"; LOG_FILTER="$DOMAIN.access.log*"; }
            [[ $ACTION == "ALL" ]] && { LOG_FILE_LOCATION="/usr/local/lsws/logs"; LOG_FILTER="*.access.log*"; }
            [[ $ACTION == "FILE" ]] && { LOG_FILE_LOCATION="$FILE"; }
        else
            echo "No logs detected"
            exit
        fi
    else
        echo "Format set to ${FORMAT^^}"
        FORMAT="${FORMAT^^}"
    fi
    echo "Platform: $PLATFORM - Format: $FORMAT"

	_debug "FORMAT:$FORMAT LOG_FILE_LOCATION:$LOG_FILE_LOCATION LOG_FILTER:$LOG_FILTER"
}

# ==================================================
# -- collect_logs
# ==================================================
collect_logs () {
    _debug "===== Running collect_logs"
    _debug "Collecting logs"
	local CATCMD="cat"
    local LOGCMD
    LOG_COLLECT_DATA=$(mktemp)

    # Collect logs
	_debug "Format: $FORMAT Log File Location:$LOG_FILE_LOCATION Log Filter: $LOG_FILTER Action: $ACTION TEMP: $LOG_COLLECT_DATA"    

    # -- Check if $LOG_FILE_LOCATION and $LOG_FILTER are set
    [[ -z $LOG_FILE_LOCATION ]] && { _error "No log file location set, exiting"; exit; }
    [[ -z $LOG_FILTER ]] && { _error "No log filter set, exiting"; exit; }    
    
    # -- Single Domain Action
	if [[ $ACTION == "DOMAIN" ]]; then
        # Get the single access log
        PROCESS_LOGS=($(find $LOG_FILE_LOCATION -type f -name "$LOG_FILTER"))        
        _debug "Running -- find $LOG_FILE_LOCATION -type f -name \"$LOG_FILTER\""

        # Process log
        [[ -z $PROCESS_LOGS ]] && { _error "No logs found, exiting"; exit; }
        [[ $PROCESS_LOGS[0] == *gz ]] && CATCMD="zcat" || CATCMD="cat"
        LOGCMD="$CATCMD ${PROCESS_LOGS[0]} > $LOG_COLLECT_DATA"
        if [[ $DRY_RUN == "1" ]]; then
            echo $LOGCMD
        else
            eval $LOGCMD
            echo $LOGCMD
        fi        
    # -- Domain Action
	elif [[ $ACTION == "DOMAIN_ALL" ]]; then
        # Get all logs into an array
        PROCESS_LOGS=($(find $LOG_FILE_LOCATION -type f -name "$LOG_FILTER"))        
        _debug "Running -- find $LOG_FILE_LOCATION -type f -name \"$LOG_FILTER\""
        
        # Go through each log and process it
        for LOG in "${PROCESS_LOGS[@]}"; do
            _debug "Processing $LOG"
            [[ $LOG == *gz ]] && CATCMD="zcat" || CATCMD="cat"
            LOGCMD="$CATCMD $LOG >> $LOG_COLLECT_DATA"
            if [[ $DRY_RUN == "1" ]]; then
                echo $LOGCMD
            else
                eval $LOGCMD
                echo $LOGCMD
            fi
        done
    # -- All Action
	elif [[ $ACTION == "ALL" ]]; then
        [[ -z $LOG_FILE_LOCATION ]] && { echo "No log file location set, exiting"; exit; }
		LOGCMD="cat ${LOG_FILE_LOCATION}/*.access.log > $LOG_COLLECT_DATA; zcat ${LOG_FILE_LOCATION}/${LOG_FILTER} >> $LOG_COLLECT_DATA"
        _debug "Running -- cat ${LOG_FILE_LOCATION}/*.access.log > $LOG_COLLECT_DATA; zcat ${LOG_FILE_LOCATION}/${LOG_FILTER} >> $LOG_COLLECT_DATA"
        if [[ $DRY_RUN == "1" ]]; then
			echo $LOGCMD            
		else
			eval $LOGCMD
            echo $LOGCMD
		fi
    fi
	LOG_DATA_FILE=$LOG_COLLECT_DATA
}

# ==================================================
# -- do_goaccess
# ==================================================
function do_goaccess () {
    _debug "===== Running do_goaccess"
    [[ $LOG_DATA_FILE == *.gz ]] && { CATCMD="zcat"; _debug "Detected gzip file, setting \$CAT_CMD to zcat"; } || { CATCMD="cat"; _debug "Detected non-gzip file, setting \$CAT_CMD to cat"; }
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
    if [[ $FORMAT == "combined" ]]; then
        _debug "Setting COMBINED format"
        GOACCESS_EXTRA+="--log-format='COMBINED' "
    else        
        GOACCESS_EXTRA+="--log-format='$LOG_FORMAT' --date-format='$DATE_FORMAT' --time-format='$TIME_FORMAT' "
    fi

    # -- Run goaccess
    _debug "Proceeding with do_goaccess \$ACTION: $ACTION \$FILE: $FILE \$FORMAT: $FORMAT \$DRY_RUN: $DRY_RUN \$UNKNOWN_UA: $UNKNOWN_UA \$TIME_SPEC: $TIME_SPEC \$BROWSER_LIST: $BROWSER_LIST"
    CMD="$CATCMD $LOG_DATA_FILE | goaccess ${GOACCESS_EXTRA}"
    _debug "CMD: $CMD"
    [[ $DRY_RUN == "1" ]] && { echo $CMD; } || { eval "$CMD"; echo "CMD: $CMD"; }
}

# ==================================================
# -- sed_logs
# ==================================================
function sed_logs() {
	_debug "===== Processing logs using custom time - $CUSTOM_TIME"
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

# ==================================================
# -- debug_run
# ==================================================
function debug_run () {
    _debug "===== Running debug_run"
    _debug "ACTION: $ACTION"
    _debug "PLATFORM: $PLATFORM"
    _debug "FORMAT: $FORMAT"
    _debug "DRY_RUN: $DRY_RUN"
    _debug "DEBUG_ON: $DEBUG_ON"
    _debug "LOG_DATA_FILE: $LOG_DATA_FILE"
    _debug "CUSTOM_TIME: $CUSTOM_TIME"
    _debug "TIME_SPEC: $TIME_SPEC"
    _debug "BROWSER_LIST: $BROWSER_LIST"
    _debug "UNKNOWN_UA: $UNKNOWN_UA"
    _debug "NO_403: $NO_403"
}

# ==================================================
# -- Process Args
# ==================================================
ALLARGS="$@"
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    -h|--help)
    ACTION="HELP"	
    shift # past argument
    ;;
    -p|--platform)
    PLATFORM="$2"	
    shift # past argument
    shift # past value
    ;;
	-f|--format)
	SET_FORMAT="${2^^}"	
	shift # past argument
	shift # past value
	;;
    -d|--debug)
    DEBUG_ON="1"
    shift # past argument
    ;;
    -dr|--dryrun)
    DRY_RUN="1"
    shift # past argument
    ;;
    -domain)
    ACTION="DOMAIN"
    DOMAIN="$2"    
    shift # past argument
    shift # past value
    ;;
    -domain-all)
    ACTION="DOMAIN_ALL"
    DOMAIN="$2"
    shift # past argument
    shift # past value
    ;;
	-all-logs)
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
    -403)
    NO_403="1"
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

# ==================================================
# --- Check Arguments
# ==================================================
if [[ -n $TIME_SPEC ]]; then
    if [[ $TIME_SPEC != "min" && $TIME_SPEC != "hour" ]]; then
        echo "Error: Invalid time specification"
        exit
    fi
fi

# ==================================================
# --- Action
# ==================================================
if [[ -z $ACTION ]] || [[ $ACTION == "HELP" ]]; then
	usage
	_error "Error: No action specified"
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
    debug_run
	do_goaccess $ACTION $LOG_DATA_FILE
# ------------
# -- FILE
# ------------
elif [[ $ACTION == "FILE" ]]; then
    [[ -z $FILE ]] && usage && echo "Error: specify a file" && exit
    # -- Process logs on file
    _debug "Running for file $FILE"
    
    check_goaccess
    detect_logs
    LOG_DATA_FILE=$FILE    
    set_format
    [[ ! -z $CUSTOM_TIME ]] && sed_logs $CUSTOM_TIME
    debug_run
    do_goaccess $ACTION $LOG_DATA_FILE
# ------------
# -- ALL
# ------------
elif [[ $ACTION == "ALL" ]]; then
    # -- Process logs on all domains
    _debug "Running for all domains"

    check_goaccess
    detect_logs
    set_format
    collect_logs
    [[ ! -z $CUSTOM_TIME ]] && sed_logs $CUSTOM_TIME
    debug_run
    do_goaccess $ACTION $LOG_DATA_FILE
elif [[ $ACTION == "TEST" ]]; then
    # -- Process logs on all domains test
    _debug "Running for test"    
    
    # -- Run
    check_goaccess
    LOG_DATA_FILE=$TEST_LOG
    set_format
    debug_run
    do_goaccess $ACTION $LOG_DATA_FILE
elif [[ $ACTION == "COMPILE" ]]; then
    _debug "Compiling goaccess"
    compile_goaccess
else
    echo "Error: Invalid action"
    exit
fi