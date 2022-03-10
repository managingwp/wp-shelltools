#!/usr/bin/env bash
# - gp-logcode
# -- functions
. $(dirname "$0")/functions.sh
_debug "Loading functions.sh"

# -- getopts
while getopts ":aec:" option; do
        case ${option} in
                a) ACCESS_LOGS=1 ;;
                e) GP_EXCLUDE=1 ;;
                c) COMMAND=$OPTARG ;;
                ?) usage ;;
        esac
done
_debug "getopts: \$ACCESS_LOGS=$ACCESS_LOGS \$GP_EXCLUDE=$GP_EXCLUDE \$COMMAND=$COMMAND"

# --
# -- Variables
# --
GPOPT="/opt/gridpane"
GPLP="/opt/gridpane/logs"
NGINX_LOG_PATH="/var/log/nginx"
OLS_LOG_PATH="/usr/local/lsws/logs"

(( TEST >= "1" )) && LOG_FILES+=("$SCRIPTPATH/tests/test.log")
SYS_LOGS=("/var/log/syslog")
OLS_LOGS=("$OLS_LOG_PATH/stderr.log" "$OLS_LOG_PATH/error.log" "$OLS_LOG_PATH/lsrestart.log")
NGINX_LOGS=("$NGINX_LOG_PATH/error_log")
GP_LOGS=("$GPOPT/gpclone.log" "$GPOPT/gpdailyworker.log" "$GPOPT/gphourlyworker.log" "$GPOPT/gpworker.log")
GP_BACKUP_LOGS=("$GPOPT/backup.log" "$GPOPT/backup.error.log" "$GPOPT/backups.monitoring.log")

# --------
# -- Debug
# --------
_debug_all $@

# ------------
# -- functions
# ------------

# Usage
usage () {
	echo "Usage: $SCRIPT_NAME [-s|-e] -c [tail|last|test]"
        echo ""
	echo "Commands (-c):"
	echo "    tail		- Tail all logs"
	echo "    last		- Last 10 lines of all logs"
	echo "    test		- Test what logs will be processed"
	echo ""
	echo "Options:"
	echo "    -a		- Include website access and error logs."
	echo "    -e		- Exclude GridPane, staging, and canary"
	echo ""
	echo ""
        echo "Log files checked:"
        echo "    System 	- ${SYS_LOGS[@]}"
        echo "    OLS	- ${OLS_LOGS[@]}"
        echo "    NGINX 	- ${NGINX_LOGS[@]}"
        echo "    GP		- ${GP_LOGS[@]}"
        echo "    GP Backup 	- ${GP_BACKUP_LOGS[@]}"
        echo ""
}

collect_logs () {

# Start check logs
echo  "-- Running logs command with $1 option"
        
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
if [[ $ACCESS_LOGS == "1" ]]; then
	_debug "Including web access logs"
	echo "  -- Checking for site log files"
	_getsitelogs

	if [[ -z $SITE_LOGS ]]; then
		_error "    -- No web logs files found"
	else
		_success "    -- Found web log files"
		_debug "    -- Found log files - ${SITE_LOGS[@]}"
		LOG_FILES+=("$SITE_LOGS")
	fi
else
	_debug "Not including web access logs"
fi

# -- Check if there are any logs to run against.
if [[ -z $LOG_FILES ]]; then
        _error "No logs files found at all, exiting"
        exit 1
else
        _success "  -- Found log files, continuing"
        _debug "  -- Found log files - ${LOG_FILES[*]}"
fi

}

# -------
# -- Main
# -------

if [[ $COMMAND = 'tail' ]]; then
	echo " -- Starting to tail logs"
	collect_logs
	echo " -- Tailing files ${LOG_FILES[*]}"	
        tail -f "${LOG_FILES[@]}"
elif [[ $COMMAND = 'last' ]]; then
	echo " -- Starting to tail logs"
	collect_logs
	echo " -- Tailing last 50 lines of files $LOG_FILES"
        tail -n 50 "${LOG_FILES[@]}" | less
elif [[ $COMMAND = 'test' ]]; then
	echo " -- Starting test"
	collect_logs
	echo " -- Running test to confirm log files to process"
	echo ${LOG_FILES[@]} | tr ' ' '\n'
else
	_debug "args: $@"
	_error "No option provided to print out logs, choose either tail or last"
	exit 1
fi