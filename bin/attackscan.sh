#!/bin/bash
#!/bin/bash
# ------------------
# -- wpst-goacces.sh
# ------------------
SCRIPT_DIR="$( dirname "$0")"
source $SCRIPT_DIR/../lib/functions.sh
OLS_LOG_DIR="/var/log/ols"
NGINX_LOG_DIR="/var/log/nginx"

# -- detect_server
function detect_server () {
    # -- logs to process
    if [[ -d $OLS_LOG_DIR ]]; then
            echo " -- Found OLS logs at /var/log/ols"
            SERVER="ols"
            LOGS="/var/log/ols"
            $(ls ${LOGS}/*.access.log)
            [[ $? -eq 0 ]] && LOG_SEARCH="*.access.log"
            $(ls ${LOGS}/*.access_log)
            [[ $? -eq 0 ]] && LOG_SEARCH="*.access_log"
    elif [[ -d $NGINX_LOG_DIR ]]; then
            echo " -- Found Nginx logs at /var/log/nginx"
            SERVER="nginx"
            LOGS="/var/log/nginx"
            LOG_FILES=($(find ${LOGS} -name "*.access.log"))
            [[ $? -eq 0 ]] && LOG_SEARCH="*.access.log"
            LOG_FILES=($(find ${LOGS} -name "*.access_log"))
            [[ $? -eq 0 ]] && LOG_SEARCH="*.access_log"                           
    else
        _error "Didn't find any log directories, use -d to specify a directory"
        exit 1
    fi
    
    [[ ! $LOG_SEARCH ]] && _error "Didn't find any log files to process"
}

# -- usage
usage () {
    USAGE=\
"attackscan [-top <lines>|-scan]
        
Parses Nginx and OLS web server access logs to find top number of requests and common attack requests for WordPress.
    
    Commands:
        -top <lines>     - List top number of requests from the webserver access log.
        -scan           - List common attack requests that return a 200 status code, by IP address.

    Options:
        -rp             - Request position in the log file. Default: OLS: 7, Nginx: 6
        -d              - Debug mode
        -dir <dir>      - Directory to scan for logs. Detected: /var/log/ols or /var/log/nginx

    Examples:
        attackscan -top 20
        attackscan -scan

Version: - $WPST_VERSION - $SCRIPT_DIR
"
    echo "$USAGE"
}

# -- top-ols $SERVER $LOGS $LINES
function top () {
    SERVER="$1"
    LOGS="$2"
    LINES="$3"
    echo " -- Server: $SERVER - Logs: $LOGS - Lines: $LINES"
    if [[ $SERVER == "ols" ]]; then
        _debug "Running top for OLS on $LOG_FILES"

        # -- pos
        [[ $POS ]] || POS="6"
        _debug "\$POS: $POS"

        for SITE in "${LOG_FILES[@]}"; do
            echo " -- Parsing ${SITE} for top ${LINES} requests"
            CMD="cat ${SITE} | awk {' print \$${POS} '} | sort | uniq -c | sort -nr | head -n ${LINES}"
            _debug "CMD: $CMD"
            eval $CMD
            echo "======================"
        done   
    elif [[ $SERVER == "nginx" ]]; then
        # -- pos
        [[ $POS ]] || POS="7"
        _debug "\$POS: $POS"

        _debug "Running top for nginx on $LOG_FILES"
        for SITE in "${LOG_FILES[@]}"; do
            echo " -- Parsing ${SITE} for top ${LINES} requests"
            CMD="cat ${SITE} | awk {' print \$${POS} '} | sort | uniq -c | sort -nr | head -n ${LINES}"
            _debug "CMD: $CMD"
            eval $CMD
            echo "======================"
        done        
    else
        _error "Something went wrong"        
    fi
}

# -- scan $SERVER $LOGS $LINES
function scan () {
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

############################
# -- Main Script Logic
############################
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
    -top)
    ACTION="TOP"
    LINES="$2"
    shift # past argument
    shift # past value
    ;;
    -scan)
    ACTION="SCAN"
    shift # past argument
    ;;
    -rp)
    POS="$2"
    shift # past argument
    shift # past value
    ;;
    -d|--debug)
    DEBUG_ON="1"
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

# -- lines
[[ $LINES ]] || LINES="10"
_debug "\$LINES: $LINES"

if [[ -z $ACTION ]]; then
        usage
        exit 1
elif [[ $ACTION == "HELP" ]]; then
        usage
        exit 1
elif [[ $ACTION == "TOP" ]]; then    
    _debug "Running top command with $LINES lines"
    _loading "Showing top $LINES requests per log file"
    detect_server
    top $SERVER $LOGS $LINES
elif [[ $ACTION == "SCAN" ]]; then
    echo " - Running a scan for common attack requests"
    detect_server
    scan $SERVER $LOGS $LINES
else
    usage
    exit 1
    _error "Invalid command"
fi

