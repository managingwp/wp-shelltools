# ---------------
# -- functions.sh
# ---------------

echo "-- Loading functions"

# - exec_log - execute log functions

exec_log () {
        GPLP="/opt/gridpane/logs"
        NGINXP="/var/log/nginx"
        LSWSP="/usr/local/lsws/logs"
        
        SYSTEM_LOGS=("/var/log/syslog")
        LSWS_LOGS=("$LSWSP/stderr.log" "$LSWSP/error.log" "$LSWSP/lsrestart.log")
	NGINX_LOGS=("$NGINXP/error_log" "/var/log/php/*/fpm.log")
	GP_LOGS=("$GPLP/backup.log" "$GPLP/backup.error.log" "$GPLP/gpclone.log" "$GPLP/gpdailyworker.log" "$GPLP/gphourlyworker.log" "$GPLP/gpworker.log")        
        echo  " -- Running $1"

        # System log files
        for LOGS in "${SYSTEM_LOGS[@]}"; do
                echo -n "  -- Checking $LOGS"
                if [ -f $LOGS ]; then
                        _success " - Found $LOGS"
                        LOG_FILES+=("$LOGS")
                else
                        _error " - Didn't find $LOGS"
                fi
        done

        # OLS Log files
	for LOGS in "${LSWS_LOGS[@]}"; do
		echo -n "  -- Checking $LOGS"
		if [ -f $LOGS ]; then
			_success " - Found $LOGS"
			LOG_FILES+=("$LOGS")			
		else 
			_error " - Didn't find $LOGS"
		fi
	done

        # Nginx log files
	for LOGS in "${NGINX_LOGS[@]}"; do
		echo -n "  -- Checking $LOGS"
                if [ -f $LOGS ]; then
                        _success " - Found $LOGS"
                        LOG_FILES+=("$LOGS")
                else
                        _error " - Didn't find $LOGS"
                fi
	done

        # GridPane specific log files
        GP_LOGS=("$GPLP/backup.log" "$GPLP/backup.error.log" "$GPLP/gpclone.log" "$GPLP/gpdailyworker.log" "$GPLP/gphourlyworker.log" "$GPLP/gpworker.log")	
	for LOGS in "${GP_LOGS[@]}"; do
                echo -n "  -- Checking $LOGS"
                if [ -f $LOGS ]; then
                        _success " - Found $LOGS"
                        LOG_FILES+=("$LOGS")
                else
                        _error " - Didn't find $LOGS"
                fi
        done
	
	if [[ -z $LOG_FILES ]]; then
		_error "-- No log files found"
		return
	else
		_debug "Found log files - ${LOG_FILES[*]}"
	fi
	
        if [ $1 = 'tail' ]; then
                echo " -- Tailing files $LOG_FILES"
                tail -f "$LOG_FILES"
        elif [ $1 = 'last' ]; then
                echo " -- Tailing last 50 lines of files $LOG_FILES"
                tail -n 50 $LSWS_LOGS_CHECK $LOG_FILES | less
        else
                help_intro log
        fi

}