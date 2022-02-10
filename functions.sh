# ---------------
# -- functions.sh
# ---------------

echo "-- Loading functions"

# - exec_log - execute log functions

exec_log () {
        GPLP="/opt/gridpane/logs"
        NGINXP="/var/log/nginx"
        echo  " -- Running $1"

        # System log files
        LOG_FILES="/var/log/syslog"

        # OLS Log files
        LSWSP="/usr/local/lsws/logs"
        LSWS_LOGS=("$LSWSP/stderr.log" "$LSWSP/error.log" "$LSWSP/lsrestart.log")
        LSWS_LOGS_CHECK=("")
	for LOGS in "${LSWS_LOGS[@]}"; do
		echo "-- Checking $LOGS"
		if [ -f $LOGS ]; then
			echo "-- Found $LOGS"
			LSWS_LOGS_CEHCK+=("$LOGS")			
		else 
			echo "-- No $LOGS"
		fi
	done
	return
        # Nginx log files
        if [ -f $NGINXP/error.log ]; then LOG_FILES="$LOG_FILES $NGINXP/error_log"; fi

        # php-fpm logs
        if [ -d /var/log/php ]; then LOG_FILES="$LOG_FILES /var/log/php/*/fpm.log"; fi

        # GridPane specific log files
        LOG_FILES="$LOG_FILES $GPLP/backup.log $GPLP/backup.error.log"
        LOG_FILES="$LOG_FILES $GPLP/gpclone.log"
        LOG_FILES="$LOG_FILES $GPLP/gpdailyworker.log $GPLP/gphourlyworker.log $GPLP/gpworker.log"
        LOG_FILES="$LOG_FILES "
        if [ $1 = 'tail' ]; then
                echo " -- Tailing files $LOG_FILES"
                tail -f $LOG_FILES
        elif [ $1 = 'last' ]; then
                echo " -- Tailing last 50 lines of files $LOG_FILES"
                tail -n 50 $LOG_FILES | less
        else
                help_intro log
        fi

}