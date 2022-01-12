# ---------------
# -- functions.sh
# ---------------

echo "-- Loading functions"

# - exec_log - execute log functions

exec_log () {
	GPLP="/opt/gridpane/logs"
	LSWSP="/usr/local/lsws/"
	NGINXP="/var/log/nginx"
	echo  " -- Running $1"
		
	# System log files
	LOG_FILES="/var/log/syslog"

	# OLS Log files
	if [ -f $LSWSP/stderr.log ]; then LOG_FILES="$LOG_FILES $LSWSP/stderr.log"; fi
	if [ -f $LSWSP/lsws/.log ]; then LOG_FILES="$LOG_FILES $LSWSP/error.log"; fi
	if [ -f $LSWSP/lsws/.log ]; then LOG_FILES="$LOG_FILES $LSWSP/lsrestart.log"; fi
	
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
		tail -50 $LOG_FILES | less
	else
		help_intro log
	fi		
	
}