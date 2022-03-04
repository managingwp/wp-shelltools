# ---------------
# -- functions.sh
# ---------------
# ------------
# -- Variables
# ------------

# ----------------
# -- Key Functions
# ----------------

_debug () {
        if [ -f .debug ];then
                echo -e "${CCYAN}**** DEBUG $@${NC}"
        fi
}

_error () {
        echo -e "${CRED}$@${NC}";
}

_success () {
        echo -e "${CGREEN}$@${NC}";
}

# --
# -- Colors
# --
export TERM=xterm-color
export CLICOLOR=1
export LSCOLORS=ExFxCxDxBxegedabagacad

export NC='\e[0m' # No Color
export CBLACK='\e[0;30m'
export CGRAY='\e[1;30m'
export CRED='\e[0;31m'
export CLIGHT_RED='\e[1;31m'
export CGREEN='\e[0;32m'
export CLIGHT_GREEN='\e[1;32m'
export CBROWN='\e[0;33m'
export CYELLOW='\e[1;33m'
export CBLUE='\e[0;34m'
export CLIGHT_BLUE='\e[1;34m'
export CPURPLE='\e[0;35m'
export CLIGHT_PURPLE='\e[1;35m'
export CCYAN='\e[0;36m'
export CLIGHT_CYAN='\e[1;36m'
export CLIGHT_GRAY='\e[0;37m'
export CWHITE='\e[1;37m'

# --
# -- help_cmd associative array
# --
declare -A help_cmd

# --
# -- Functions
# --
_debug "Loading functions"

# - _getsitelogs
_getsitelogs () {
	if [ -d "/var/log/nginx" ]; then
		sitelogsdir="/var/log/nginx"
	elif [ -d "/var/log/lsws" ]; then
		sitelogsdir="/var/log/lsws"
	fi
	files=$(ls -aSd $logfiledir/* | grep access | egrep -v '/access.log$|staging|canary|gridpane|.gz')
}


# - exec_log - execute log functions
help_cmd[log]='tail or print last 50 lines of all GridPane logs'
declare -A help_log
help_log[tail]='tail all logs'
help_log[last]='last 50 lines of all logs'

tool_log () {
        # Usage
        if [ -v $2 ]; then
                echo "Usage: $SCRIPT_NAME log [tail|last] [-s]"
                echo "	-s Include site access and error logs."
                return
        fi	
        GPLP="/opt/gridpane/logs"
        NGINXP="/var/log/nginx"
        LSWSP="/usr/local/lsws/logs"
        
        SYSTEM_LOGS=("/var/log/syslog")
        GRIDPANE_LOGS=("$GPLP/backup.log" "$GPLP/backup.error.log" "$GPLP/gpclone.log" "$GPLP/gpdailyworker.log" "$GPLP/gphourlyworker.log" "$GPLP/gpworker.log")
        LSWS_LOGS=("$LSWSP/stderr.log" "$LSWSP/error.log" "$LSWSP/lsrestart.log")
	NGINX_LOGS=("$NGINXP/error_log")
	NGINX_FPM_LOGS=("/var/log/php/*/fpm.log")
	# Cycle through FPM logs.
	for file in /var/log/php/*/fpm.log; do
		_debug "fpm file - $file"
			NGINX_FILES+=("$SYS_LOGS")
	done

	

	# Start check logs
        echo  " -- Running $2"

        # System log files
        for SYS_LOGS in "${SYSTEM_LOGS[@]}"; do
                echo -n "  -- Checking $SYS_LOGS"
                if [ -f $SYS_LOGS ]; then
                        _success " - Found $SYS_LOGS"
                        LOG_FILES+=("$SYS_LOGS")
                else
                        _error " - Didn't find $SYS_LOGS"
                fi
        done

        # OLS Log files
	for OLS_LOGS in "${LSWS_LOGS[@]}"; do
		echo -n "  -- Checking $OLS_LOGS"
		if [ -f $OLS_LOGS ]; then
			_success " - Found $OLS_LOGS"
			LOG_FILES+=("$OLS_LOGS")
		else 
			_error " - Didn't find $OLS_LOGS"
		fi
	done

	# Nginx FPM log files
	for FPM_LOGS in ${NGINX_FPM_LOGS[@]}; do
		echo -n "  -- Checking $FPM_LOGS"
		if [ -f $FPM_LOGS ]; then
			_success " - Found $FPM_LOGS"
                        LOG_FILES+=("$FPM_LOGS")
                else
                	_error " - Didn't find $FPM_LOGS"
                fi
        done
        
        # Nginx log files
	for NX_LOGS in "${NGINX_LOGS[@]}"; do
		echo -n "  -- Checking $NX_LOGS"
                if [ -f $NX_LOGS ]; then
                        _success " - Found $NX_LOGS"
                        LOG_FILES+=("$NX_LOGS")
                else
                        _error " - Didn't find $NX_LOGS"
                fi
	done

        # GridPane specific log files
	for GP_LOGS in "${GRIDPANE_LOGS[@]}"; do
                echo -n "  -- Checking $GP_LOGS"
                if [ -f $GP_LOGS ]; then
                        _success " - Found $GP_LOGS"
                        LOG_FILES+=("$GP_LOGS")
                else
                        _error " - Didn't find $GP_LOGS"
                fi
        done
	
        # Website specific log files
	SITE_LOGS=$(_getsitelogs)
	_debug "$SITE_LOGS"
	
	if [[ -z $LOG_FILES ]]; then
		_error "-- No log files found"
		return
	else
		_debug "Found log files - ${LOG_FILES[*]}"
	fi
	
        if [ $1 = 'tail' ]; then
                echo " -- Tailing files ${LOG_FILES[*]}"
                tail -f "$LOG_FILES"
        elif [ $1 = 'last' ]; then
                echo " -- Tailing last 50 lines of files $LOG_FILES"
                tail -n 50 $LSWS_LOGS_CHECK $LOG_FILES | less
        fi
}


# - goaccess - execute log functions
help_cmd[goaccess]='Process GridPane logs with goaccess'
tool_goaccess () {
        # Usage
        if [ -v $2 ]; then
        	echo "Usage: $SCRIPT_NAME gp-goaccess [<domain.com>|-a]"
        	return
        fi
        
        # Formats for goaccess
	LOG_FORMAT='[%d:%t %^] %h %^ - %v \"%r\" %s %b \"%R\" \"%u\"\'
	DATE_FORMAT='%d/%b/%Y\'
	TIME_FORMAT='%H:%M:%S %Z\'

	_debug "goaccess arguments - $ACTION"
	_debug "goaccess LOG_FORMAT = $LOG_FORMAT ## DATE_FORMAT = $DATE_FORMAT ## TIME_FORMAT = $TIME_FORMAT"
	# -- Check args.
	if [ -v $ACTION ]; then
	        echo "Usage: gp-tools goaccess [<domain.com>|-a]"
	        echo "	-a will go through all the logs versus a single domain"
	        return
	fi

	# Main
	if [ $ACTION = "-a" ]; then
	        zcat /var/log/nginx/$2.access.log.*.gz | goaccess --log-format="$LOG_FORMAT" --date-format="$DATE_FORMAT" --time-format="$TIME_FORMAT"
	else
	        cat /var/log/nginx/$1.access.log | goaccess --log-format="$LOG_FORMAT" --date-format="$DATE_FORMAT" --time-format="$TIME_FORMAT"
	fi
}

# - 4xxerr
help_cmd[logcode]='Look for specifc HTTP codes in web server logfiles and return top hits.'
tool_logcode () {	
	gp-logcode.sh
}