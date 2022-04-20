#!/usr/bin/env bash
# ----------
# -- gp-logs
# ----------

# ------------
# -- functions
# ------------
. $(dirname "$0")/functions.sh
_debug "Loading functions.sh"

# -- getopts
while getopts ":el:c:" option; do
        case ${option} in
		l) LOGS=$OPTARG ;;
                c) COMMAND=$OPTARG ;;
                e) GP_EXCLUDE=1 ;;
                ?) usage ;;
        esac
done
_debug "args: $@"
_debug "getopts: \$LOGS=$LOGS \$COMMAND=$COMMAND \$GP_EXCLUDE=$GP_EXCLUDE"

# ------------
# -- Variables
# ------------
GPOPT="/opt/gridpane"
GPLP="/opt/gridpane/logs"
NGINX_LOG_PATH="/var/log/nginx"
OLS_LOG_PATH="/usr/local/lsws/logs"

(( TEST >= "1" )) && LOG_FILES+=("$SCRIPTPATH/tests/test.log")
SYS_LOGS=("/var/log/syslog")
NGINX_LOGS=("$NGINX_LOG_PATH/error.log" "$NGINX_LOG_PATH/access.log")
OLS_LOGS=("$OLS_LOG_PATH/stderr.log" "$OLS_LOG_PATH/error.log" "$OLS_LOG_PATH/lsrestart.log")
GP_LOGS=("$GPOPT/gpclone.log" "$GPOPT/gpdailyworker.log" "$GPOPT/gphourlyworker.log" "$GPOPT/gpworker.log")
GP_BACKUP_LOGS=("$GPOPT/backup.log" "$GPOPT/backup.error.log" "$GPOPT/backups.monitoring.log")
PHP_FPM_LOGS=("/var/log/php")

# ------------
# -- debug all
# ------------
_debug_all $@

# ------------
# -- functions
# ------------

# -- Usage
usage () {
	echo "Usage: $SCRIPT_NAME -c [tail|last|test] -l [all|web|system|gp|fpm] (-e)"
        echo ""
	echo "Command (-c):"
	echo "    tail		- Tail all logs"
	echo "    last		- Last 10 lines of all logs"
	echo "    test		- Test what logs will be processed"
	echo ""
	echo "Logs (-l):"
	echo "    all		- Include all logs."
	echo "    web		- Web logs only"
	echo "    system	- System log files only"
	echo "    gp		- GridPane core log files only"
	echo "    gpbackup	- GridPane backup logs only"
	echo ""
	echo "Options:"
	echo "    -e            - Exclude GridPane, staging, and canary"
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

# -- start_logs
start_logs () {
	echo ""
	read -p " -- Press [Enter] to start"
	
	
}

# -- collect_logs
collect_logs () {
	_debug_function
	# all = Include all logs.
	# web = Web logs only
	# system = System log files only
	# gp = GridPane core log files only"
	# fpm = PHP-FPM log files only"

	if [[ $LOGS == "all" ]]; then
		_debug "Collect logs: all"
		collect_system_logs
		collect_webserver-logs
		collect_web-logs both
		collect_php-fpm-logs
		collect_gridpane
		collect_gridpane_backup
	elif [[ $LOGS == "web-access" ]];then
		collect_webserver-logs
		collect_web-logs access	
	elif [[ $LOGS == "web-error" ]]; then
		collect_web-logs error
		collect_php-fpm-logs
	elif [[ $LOGS == "web-all" ]]; then
		collect_webserver-logs
		collect_web-logs both	
		collect_php-fpm-logs
	elif [[ $LOGS == "system" ]]; then
		collect_system_logs
	elif [[ $LOGS == "gp" ]]; then
		collect_gridpane
		collect_gridpane_backup
	elif [[ $LOGS == "gpbackup" ]]; then
		collect_gridpane_backup
	else
		_error "Something borked... :("
	fi

}


# -- system logs
collect_system_logs () {
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
}

# -- collect_web-logs errors|access|both
collect_web-logs () {
        _debug_function
        # Find logs
        if [ -d $NGINX_LOG_PATH ]; then
                _debug "Found nginx log directory"
                collect_nginx $1
        elif [ -d $OLS_LOG_PATH ]; then
                _debug "Found OLS log directory"
                collect_ols $1
        else
        	_error "-- Didn't find access logs directory for OLS or Nginx"
        fi
}

# -- collect_access-logs-nginx -- grab Nginx log files.
collect_nginx () {        
		# Choose what logs to return based on $1
		if [[ $1 == "error" ]] || [[ $1 == "access" ]]; then
			LOG_GREP="$1"
		elif [[ $1 == "both" ]]; then
			LOG_GREP="error|access"
		fi
		_debug "\$LOG_GREP:$LOG_GREP"
	
		if [[ $GP_EXCLUDE ]]; then
                _debug "Exclude GridPane access logs '/access.log$|staging|canary|gridpane|.gz'"
                NGINX_LOGS=$(ls -aSd $NGINX_LOG_PATH/* | egrep $LOG_GREP | egrep -v '/access.log$|staging|canary|gridpane|.gz' | tr '\n' ' ')
        else
                _debug "Including GridPane access logs '/access.log$|staging|canary|gridpane|.gz'"
				_debug "ls -aSd $NGINX_LOG_PATH/* | grep $LOG_GREP | grep -v '.gz' | tr '\n' ' '"
                NGINX_LOGS=$(ls -aSd $NGINX_LOG_PATH/* | grep $LOG_GREP | grep -v '.gz' | tr '\n' ' ')
        fi
		_debug "\$NGINX_LOGS = ${NGINX_LOGS}"

        if [[ -f $NGINX_LOGS ]]; then		
			echo " -- Found ${NGINX_LOGS}"
		else
			_error "Didn't find any Nginx Access logs"			
		fi
}

collect_ols () {
	_debug "Not completed"
	echo "-- Not completed"
}


# -- collect_webserver-logs
collect_webserver-logs () {
	_debug_function

	# Nginx logs
	if [[ -d $NGINX_LOG_PATH ]]; then
		echo " -- Checking for NGINX webserver logs"
		for NGINX_LOG in "${NGINX_LOGS[@]}"; do
			echo -n "  -- Checking $NGINX_LOG"
			if [ -f $NGINX_LOG ]; then
		        	_success "   -- Found $NGINX_LOG"
		                 LOG_FILES+=("$NGINX_LOG")
		        else
		        	_error "   -- Didn't find $NGINX_LOG"
		        fi
		done
	else
		_error "-- Didn't find Nginx webserver logs"
	fi

	# OLS logs
	if [[ -d $OLS_LOG_PATH ]]; then
		echo "-- Checking for OLS web server logs"
		for OLS_LOG in "${OLS_LOGS[@]}"; do
			echo -n "  -- Checking $OLS_LOGS"
			if [ -f $OLS_LOGS ]; then
				_success "   -- Found $OLS_LOGS"
				LOG_FILES+=("$OLS_LOGS")
			else 
				_error "   -- Didn't find $OLS_LOGS"
			fi
		done
	else
		_error "-- Didn't find OLS web server logs"
	fi
}

collect_gridpane () {
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
}


collect_gridpane_backup () {
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
}

collect_php-fpm-logs () {
	# PHP FPM log files
	echo "-- Checking PHP FPM log files"

	if [ "$(find "$PHP_FPM_LOGS" -mindepth 1 -maxdepth 1 -not -name '.*')" ]; then
        _debug "Found PHP log directories"
        for name in $PHP_FPM_LOGS/*/*; do
			_debug "Found $name"
		done		
	else
		_debug "Not including PHP FPM logs"
	fi
	# Old Method
	# Locate FPM logs.
	#for file in /var/log/php/*/fpm.log; do
    #    	_debug "fpm file - $file"
	#        FPM_LOGS+=("$file")
	#done
}

# -- check_logs -- most likely not needed anymore
check_logs () {
	# -- Check if there are any logs to run against.
	if [[ -z $LOG_FILES ]]; then
		_debug "\$LOG_FILES = $LOG_FILES"
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

if [[ -z $COMMAND ]] || [[ -z $LOGS ]]; then
	_error "Requires -c and -l to proceed"
	usage
	exit 1
fi

if [[ $COMMAND = 'tail' ]]; then
	echo " -- Starting to tail logs"
	collect_logs
	echo " -- Tailing files ${LOG_FILES[*]}"
	start_logs
        tail -f "${LOG_FILES[@]}"
elif [[ $COMMAND = 'last' ]]; then
	echo " -- Starting to tail logs"
	collect_logs
	echo " -- Tailing last 50 lines of files $LOG_FILES"
	start_logs
        tail -n 50 "${LOG_FILES[@]}" | less
elif [[ $COMMAND = 'test' ]]; then
	echo " -- Starting test"
	collect_logs
	echo " -- Running test to confirm log files to process"
	start_logs
	echo ${LOG_FILES[@]} | tr ' ' '\n'
else
	_debug "args: $@"
	_error "No option provided to print out logs, choose either tail or last"
	usage
	exit 1
fi

_success "Test!"