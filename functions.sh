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

echo "-- Loading functions"

# - exec_log - execute log functions
help_cmd[log]='tail or print last 50 lines of all GridPane logs'
declare -A help_log
help_log[tail]='tail all logs'
help_log[last]='last 50 lines of all logs'

qgp-tools_log () {
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