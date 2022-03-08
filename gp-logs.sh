#!/usr/bin/env bash
# - gp-logcode
. $(dirname "$0")/functions.sh
_debug "Loading functions.sh"

# --
# -- Variables
# --
GPOPT="/opt/gridpane"
GPLP="/opt/gridpane/logs"
NGINXP="/var/log/nginx"
LSWSP="/usr/local/lsws/logs"

SYSTEM_LOGS=("/var/log/syslog")
GRIDPANE_LOGS=("$GPOPT/backup.log" "$GPOPT/backup.error.log" "$GPOPT/gpclone.log" "$GPOPT/gpdailyworker.log" "$GPOPT/gphourlyworker.log" "$GPOPT/gpworker.log")
LSWS_LOGS=("$LSWSP/stderr.log" "$LSWSP/error.log" "$LSWSP/lsrestart.log")
NGINX_LOGS=("$NGINXP/error_log")
NGINX_FPM_LOGS=("/var/log/php/*/fpm.log")

# ---------------
# -- functions.sh
# ---------------

# Usage
usage () {
	echo "Usage: $SCRIPT_NAME log [tail|last] [-s]"
        echo "  -s Include site access and error logs."
}


# Start check logs
echo  " -- Running $2"
        
# Cycle through FPM logs.
for file in /var/log/php/*/fpm.log; do
	_debug "fpm file - $file"
		NGINX_FILES+=("$SYS_LOGS")
done

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