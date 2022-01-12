# ---------------
# -- functions.sh
# ---------------

echo "-- Loading functions"

# - exec_log - execute log functions

exec_log () {
	GPLP="/var/opt/gridpane/logs"
	echo  "  -- Running $1"
	
	# System log files
	LOG_FILES="/var/log/syslog.log"

	# OLS Log files
	if [ -f /usr/local/lsws/stderr.log ]; then LOG_FILES="$LOG_FILES /usr/local/lsws/stderr.log"; fi
	if [ -f /usr/local/lsws/.log ]; then LOG_FILES="$LOG_FILES /usr/local/lsws/error.log"; fi
	if [ -f /usr/local/lsws/.log ]; then LOG_FILES="$LOG_FILES /usr/local/lsws/lsrestart.log"; fi

	# GridPane specific log files
	LOG_FILES="$LOG_FILES $GPLP/backup.log $GPLP/backup.error.log"
	LOG_FILES="$LOG_FILES $GPLP/gpclone.log"
	LOG_FILES="$LOG_FILES $GPLP/gpdailyworker.log $GPLP/gphourlyworker.log $GPLP/gpworker.log"
	LOG_FILES="$LOG_FILES "
	
	
	echo " -- Tailing files $LOG_FILES"
	tail -10 $LOG_FILES
}