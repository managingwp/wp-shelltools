# ---------------
# -- functions.sh
# ---------------

# -----------
# -- Includes
# -----------

# ------------
# -- Variables
# ------------
WPST_VERSION="0.0.2"
SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
REQUIRED_APPS=("jq" "column")
if [[ $DEBUG_ON="1" ]]; then DEBUG="1"; fi

# -- Colors
RED="\033[0;31m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
BLUEBG="\033[0;44m"
YELLOWBG="\033[0;43m"
GREENBG="\033[0;42m"
DARKGREYBG="\033[0;100m"
ECOL="\033[0;0m"

# ----------------
# -- Core Functions
# ----------------

_error () { echo -e "${RED}** ERROR ** - ${*} ${ECOL}"; }
_warning () { echo -e "${RED}** WARNING ** - ${*} ${ECOL}"; }
_notice () { echo -e "${BLUE}** NOTICE ** - ${*} ${ECOL}"; }
_success () { echo -e "${GREEN}** SUCCESS ** - ${*} ${ECOL}"; }
_running () { echo -e "${BLUEBG}${@}${ECOL}"; }
_creating () { echo -e "${DARKGREYBG}${@}${ECOL}"; }
_separator () { echo -e "${YELLOWBG}****************${ECOL}"; }

# -- _debug
_debug () {
    if [[ $DEBUG_ON == "1" ]]; then
        echo -e "${CYAN}** DEBUG: ${*}${ECOL}"
    fi
}

# -- show debug information
_debug_all () {
        _debug "--------------------------"
        _debug "arguments: ${*}"
        _debug "funcname: ${FUNCNAME[@]}"
        _debug "basename: $SCRIPTPATH"
        _debug "sourced files: ${BASH_SOURCE[@]}"
        _debug "--------------------------"
}

# -- debug curl
_debug_curl () {
                if [[ $DEBUG == "2" ]]; then
                        echo -e "${CCYAN}**** DEBUG ${*}${NC}"
                fi
}

# -- _cexists -- Returns 0 if command exists or 1 if command doesn't exist
_cexists () {
		if [[ "$(command -v $1)" ]]; then
            _debug $(which $1)
			if [[ $ZSH_DEBUG == 1 ]]; then
            	_debug "${*} is installed";
            fi
            CMD_EXISTS="0"
        else
            if [[ $ZSH_DEBUG == 1 ]]; then
            	_debug "${*} not installed";
            fi
            CMD_EXISTS="1"
        fi
        return $CMD_EXISTS
}

# -- Check root
_checkroot () {
	if [ ! -f .debug ]; then
	        if [ "$EUID" -ne 0 ]
	                then echo "Please run as root"
	                exit
	        fi
	fi
}

# ------------------------------
# -- GridPane specific functions
# ------------------------------

# - logs
help_cmd[logs]='tail or show last lines on all GridPane logs.'
tool_logs () {
        gp-logs.sh ${*}
}
 
# - logcode
help_cmd[logcode]='Look for specifc HTTP codes in web server logfiles and return top hits.'
tool_logcode () {
        gp-logcode.sh ${*}
}

# - mysqlmem
help_cmd[mysqlmem]='GridPane monit memory calculation'
tool_mysqlmem () {
        gp-mysqlmem.sh ${*}
}

# - plugins
help_cmd[plugins]='Lists WordPress plugins on all websites on a GridPane Server'
tool_plugins () {
        gp-plugins.sh ${*}
}

# - goaccess - execute log functions
help_cmd[goaccess]='Process GridPane logs with goaccess'
tool_goaccess () {
	_debug_all ${*}
	
    if [[ -z $2 ]]; then
        echo "Usage: goaccess -c [domain.com|all]"
		echo "  Commands"
		echo "    domain       - Domain name of log files to process"
        echo "    all-domains  - Go through all the logs versus a single domain"
		echo ""
        echo "  Options:"
        echo "    -c           - Process compressed log files"
        echo ""
        return
    fi
	
	_debug "Checking if goaccess is installed"
	_cexists goaccess
	_debug "\$CMD_EXISTS: $CMD_EXISTS"
	if [[ $CMD_EXISTS == "1" ]]; then
		_error "goaccess is not installed"
		return 1
	else
		_debug "Confirmed goaccess is installed"
	fi
		
    # Usage
    if [ -v $2 ]; then
		echo "Usage: $SCRIPT_NAME gp-goaccess [<domain.com>|-a]"
        return 1
    fi
	
	# Formats for goaccess
	# OLS
	# logformat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-agent}i\"
	# "192.168.0.1 - - [13/Sep/2022:16:28:40 -0400] "GET /request.html HTTP/2" 200 46479 "https://domain.com/referer.html" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/105.0.0.0 Safari/537.36"
	OLS_LOG_FORMAT='\"%h - - [%d:%t %^] \"%r\" %s %b \"%R\" \"%u\"\'
	OLS_DATE_FORMAT='%d/%b/%Y\'
	OLS_TIME_FORMAT='%H:%M:%S %Z\'
	
	# NGINX
	# log_format we_log '[$time_local] $remote_addr $upstream_response_time $upstream_cache_status $http_host "$request" $status $body_bytes_sent $request_time "$http_referer" "$http_user_agent" "$http3"';
	# [14/Sep/2022:10:12:55 -0700] 129.168.0.1 - domain.com "GET /request.html HTTP/1.1" 200 47 1.538 "https://domain.com/referer.html" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/105.0.0.0 Safari/537.36"
    NGINX_LOG_FORMAT='[%d:%t %^] %h %^ - %v \"%r\" %s %b \"%R\" \"%u\"\'
    NGINX_DATE_FORMAT='%d/%b/%Y\'
    NGINX_TIME_FORMAT='%H:%M:%S %Z\'

    _debug "goaccess arguments - $ACTION"
    _debug "goaccess LOG_FORMAT = $LOG_FORMAT ## DATE_FORMAT = $DATE_FORMAT ## TIME_FORMAT = $TIME_FORMAT"
    # -- Check args.

	_debug "Detecting log files"    
    if [[ -d /usr/local/lsws ]]; then
    	WEB_SERVER="OLS"
        LOG_FORMAT=$OLS_LOG_FORMAT
        DATE_FORMAT=$OLS_DATE_FORMAT
        TIME_FORMAT=$OLS_TIME_FORMAT
    	if [[ $2 == "all" ]]; then
    		LOG_FILE_LOCATION="/var/www/*/logs"
    		LOG_FILTER="*.access.log"
    	else
	    	LOG_FILE_LOCATION="/var/www/$2/logs"
	    	LOG_FILTER="*.access.log"
	    fi
    elif [[ -d /var/log/nginx ]]; then
    	WEB_SERVER="NGINX"
        LOG_FORMAT=$NGINX_LOG_FORMAT
        DATE_FORMAT=$NGINX_DATE_FORMAT
        TIME_FORMAT=$NGINX_TIME_FORMAT
    	LOG_FILE_LOCATION="/var/log/nginx"

		if [[ $2 == "all" ]]; then
		   	LOG_FILTER="*.access.log"
		else
			LOG_FILTER="$2.access.log"
		fi
    else
    	_error "Can't detect webserver logs"
    fi
    
	_debug "Webserver detected as $WEB_SERVER"

    # Main		
	cat ${LOG_FILE_LOCATION}/${LOG_FILTER} | goaccess --log-format="$LOG_FORMAT" --date-format="$DATE_FORMAT" --time-format="$TIME_FORMAT"
}

# - gpcron
help_cmd[gpcron]='List sites using GP Cron'
tool_gpcron () {
	grep 'cron:true' /var/www/*/logs/*.env	
}

# - backups - execute log functions
help_cmd[backups]='List backups for all sites on the server.'
tool_backups () {
	ls -aL /home/*/sites/*/logs/backups.env | xargs -l -I {} sh -c "echo {} | awk -F/ '{print \$5}'|tr '\n' '|'; tr '\n' '|' < {};echo \n"
}

# - api - GridPane api
help_cmd[api]='Interact with the GridPane API'
tool_api () {
	gp-api.sh ${*}
}
