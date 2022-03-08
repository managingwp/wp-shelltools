#!/usr/bin/env bash
# - gp-logcode
. $(dirname "$0")/functions.sh
_debug "Loading functions.sh"

# --
# -- Variables
# --
GPOPT="/opt/gridpane"
GPLP="/opt/gridpane/logs"
NGINX_LOG_PATH="/var/log/nginx"
OLS_LOG_PATH="/usr/local/lsws/logs"

SYS_LOGS=("/var/log/syslog")
OLS_LOGS=("$OLS_LOG_PATH/stderr.log" "$OLS_LOG_PATH/error.log" "$OLS_LOG_PATH/lsrestart.log")
NGINX_LOGS=("$NGINX_LOG_PATH/error_log")
GP_LOGS=("$GPOPT/gpclone.log" "$GPOPT/gpdailyworker.log" "$GPOPT/gphourlyworker.log" "$GPOPT/gpworker.log")
GP_BACKUP_LOGS=("$GPOPT/backup.log" "$GPOPT/backup.error.log" "$GPOPT/backups.monitoring.log")


# ---------------
# -- functions.sh
# ---------------

# Usage
usage () {
	echo "Usage: $SCRIPT_NAME log [tail|last] [-s]"
        echo "  -s Include site access and error logs."
}


# Start check logs
echo  "-- Running logs command with $2 option"
        
# Locate FPM logs.
for file in /var/log/php/*/fpm.log; do
	_debug "fpm file - $file"
	FPM_LOGS+=("$file")
done

# PHP FPM log files
echo "-- Checking PHP FPM log files"
for FPM_LOG in "${FPM_LOGS[@]}"; do
        echo -n "  -- Checking $FPM_LOG"
        if [ -f $FPM_LOG ]; then
                _success "   -- Found $FPM_LOG"
                LOG_FILES+=("$FPM_LOG")
        else
                _error "   -- Didn't find $FPM_LOG"
        fi
done

# System log files
echo "-- Checking System log files"
for SYS_LOG in "${SYS_LOGS[@]}"; do
	echo -n "  -- Checking $SYS_LOG"
        if [ -f $SYS_LOG ]; then
        	_success "   -- Found $SYS_LOG"
                LOG_FILES+=("$SYS_LOG")
        else
        	_error "   -- Didn't find $SYS_LOG"
        fi
done

# OLS Log files
if [[ -d $OLS_LOG_PATH ]]; then
	echo "-- Checking for OLS log files"
	for OLS_LOG in "${OLS_LOGS[@]}"; do
		echo -n "  -- Checking $OLS_LOGS"
		if [ -f $OLS_LOGS ]; then
			_success "   -- Found $OLS_LOGS"
			LOG_FILES+=("$OLS_LOGS")
		else 
			_error "   -- Didn't find $OLS_LOGS"
		fi
	done
fi

# Nginx log files
if [[ -d $NGINX_LOG_PATH ]]; then
	echo " -- Checking for NGINX log files"
	for NGINX_LOG in "${NGINX_LOGS[@]}"; do
		echo -n "  -- Checking $NGINX_LOG"
		if [ -f $NGINX_LOG ]; then
	        	_success "   -- Found $NGINX_LOG"
	                LOG_FILES+=("$NGINX_LOG")
	        else
	        	_error "   -- Didn't find $NGINX_LOG"
	        fi
	done
fi

# GridPane specific log files
echo "-- Checking for GridPane log files"
for GP_LOG in "${GP_LOGS[@]}"; do
	echo -n "  -- Checking $GP_LOG"
        if [ -f $GP_LOG ]; then
	        _success "   -- Found $GP_LOG"
        	LOG_FILES+=("$GP_LOG")
        else
        	_error "   -- Didn't find $GP_LOG"
        fi
done

# GridPane Backup specific log files
echo "-- Checking for GridPane Backup log files"
for GP_BACKUP_LOG in "${GP_BACKUP_LOGS[@]}"; do
        echo -n "  -- Checking $GP_BACKUP_LOG"
        if [ -f $GP_BACKUP_LOG ]; then
                _success "   -- Found $GP_BACKUP_LOG"
                LOG_FILES+=("$GP_BACKUP_LOG")
        else
                _error "   -- Didn't find $GP_BACKUP_LOG"
        fi
done
	
# -- Check for website specific log files
echo "  -- Checking for site log files"
SITE_LOGS=$(_getsitelogs)
	
if [[ -z $SITE_LOGS ]]; then
	_error "    -- No web logs files found"
else
	_success "    -- Found web log files"
	_debug "    -- Found log files - ${LOG_FILES[*]}"
	LOG_FILES+=("$SITE_LOGS")
fi

# -- Check if there are any logs to run against.
if [[ -z $LOG_FILES ]]; then
        _error "No logs files found at all, exiting"
        exit 1
else
        _success "  -- Found log files, continuing"
        _debug "  -- Found log files - ${LOG_FILES[*]}"
fi

# -- tail or last log files!
if [ $2 = 'tail' ]; then
	echo " -- Tailing files ${LOG_FILES[*]}"
        tail -f "$LOG_FILES"
elif [ $2 = 'last' ]; then
	echo " -- Tailing last 50 lines of files $LOG_FILES"
        tail -n 50 $LSWS_LOGS_CHECK $LOG_FILES | less
else
	_error "No option provided to print out logs, choose either tail or last"
	exit 1
fi