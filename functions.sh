# ---------------
# -- functions.sh
# ---------------
# ------------
# -- Variables
# ------------

# -- help_cmd associative array
declare -A help_cmd

# -----------
# -- Functions
# ------------

_debug "Loading functions"

# - exec_log - execute log functions
help_cmd[log]='tail or print last 50 lines of all GridPane logs'
declare -A help_log
help_log[tail]='tail all logs'
help_log[last]='last 50 lines of all logs'

gp-tools_log () {
        GPLP="/opt/gridpane/logs"
        NGINXP="/var/log/nginx"
        LSWSP="/usr/local/lsws/logs"
        
        SYSTEM_LOGS=("/var/log/syslog")
        LSWS_LOGS=("$LSWSP/stderr.log" "$LSWSP/error.log" "$LSWSP/lsrestart.log")
	NGINX_LOGS=("$NGINXP/error_log" "/var/log/php/*/fpm.log")
	GP_LOGS=("$GPLP/backup.log" "$GPLP/backup.error.log" "$GPLP/gpclone.log" "$GPLP/gpdailyworker.log" "$GPLP/gphourlyworker.log" "$GPLP/gpworker.log")        
        echo  " -- Running $1"

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
        GRIDPANE_LOGS=("$GPLP/backup.log" "$GPLP/backup.error.log" "$GPLP/gpclone.log" "$GPLP/gpdailyworker.log" "$GPLP/gphourlyworker.log" "$GPLP/gpworker.log")	
	for GP_LOGS in "${GRIDPANE_LOGS[@]}"; do
                echo -n "  -- Checking $GP_LOGS"
                if [ -f $GP_LOGS ]; then
                        _success " - Found $GP_LOGS"
                        LOG_FILES+=("$GP_LOGS")
                else
                        _error " - Didn't find $GP_LOGS"
                fi
        done
	
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
        else
                help_intro log
        fi

}


# - goaccess - execute log functions
help_cmd[goaccess]='Process GridPane logs with goaccess'
declare -A help_goaccess
help_goaccess[usage]='usage: gp-goaccess [<domain.com>|-a]'

tool_goaccess () {
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
declare -A help_logcode
help_logcode[usage]='Usage: logcode <code> [<file>|-a]'

tool_logcode () {	
	# Usage
        if [ -v $2 ] || [ -v $3 ]; then
		echo "Usage: $SCRIPT_NAME logcode -e <code> <length> [<logfilename>|-a]"
		echo "	tcode = the http status code number 4 = 4xx or 5 = 5xx"
		echo "	<logfilename> = specific log file"
		echo "	-a = all log files for Nginx or OLS"
		echo "	-e = exclude GridPane, staging and canary"
		return
	fi
	
	# Set parameters.
	exclude=$2;_debug "exculde=$exclude"
	logcode=$3;_debug "logcode=$logcode"
	headlength=$4;_debug "headlength=$headlength"
	logfilename=$5;_debug "logfilename=$logfilename"

	# Nginx or OLS?
	nginxlogs=/var/log/nginx
	olslogs=/var/log/ols
	if [ -d $nginxlogs ]; then
		_debug "Found nginx logs under $nginxlogs"
		logfiledir=$nginxlogs
	elif [ -d $olslogs ]; then
		_debug "Found ols logs under $olslogs"
		logfiledir=$olslogs
	else
		_error "No $nginxlogs or $olslogs directory"
		return
	fi
		
	# All logs or just one?
	if [[ $3 == "-a" ]]; then
		_debug "Going through all alog files"
		# Exclude gridpane specific logs
		if [[ $4 == "-e" ]]; then
			_debug "Argument -e set, will exclude GridPane, staging and canary"
			files=$(ls -aSd $logfiledir/* | grep access | egrep -v '/access.log$|staging|canary|gridpane|.gz')
		else
			files=$(ls -aSd $logfiledir/* | egrep -v '.gz')
		fi
		_debug "Files selected"
		_debug "$files"
	# Just one log file.
	else
		_debug "Checking log file $3"
		if [ -f $3 ]; then
			_debug "Log file exists - $3"
			files=$(ls -aSd $logfiledir/$3)
		else
			echo "Log file $logfiledir$3 doesn't exist"
		fi
	fi

        for file in $files; do
		_debug "Processing $file"
		content=$(grep " $2[0-9][0-9] " $file | awk '{ print $6" - "$10" - "$7" "$8" "$9}' | sort | uniq -c | sort -nr | head -40)
        	echo "$content"
        	echo "...more lines but limited to top 40"
        done
}