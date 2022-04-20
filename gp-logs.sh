#!/usr/bin/env bash
# - gp-logcode
# -- functions
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
NGINX_LOGS=("$NGINX_LOG_PATH/error.log")
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
	echo "    gpbackup	- PHP-FPM log files only"
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

start_logs () {
	echo ""
	read -p " -- Press [Enter] to start"
	
	
}

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
		collect_access_logs
		collect_weblogs
		collect_gridpane
		collect_gridpane_backup
		collect_accesslogs		
	elif [[ $LOGS == "web" ]];then
		collect_weblogs
		collect_access_logs		
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

# -- access logs
collect_access_logs () {
        _debug_function
        # Find logs
        if [ -d "/var/log/nginx" ]; then
                _debug "Found nginx log directory"
                sitelogsdir="/var/log/nginx"
        elif [ -d "/var/log/lsws" ]; then
                _debug "found OLS log directory"
                sitelogsdir="/var/log/lsws"
        else
        	_error "-- Didn't find access logs directory for OLS or Nginx"
        fi

        # Grab logs
        if [[ $GP_EXCLUDE ]]; then
                _debug "Exclude GridPane access logs '/access.log$|staging|canary|gridpane|.gz'"
                SITE_LOGS=$(ls -aSd $sitelogsdir/* | grep access | egrep -v '/access.log$|staging|canary|gridpane|.gz' | tr '\n' ' ')
        else
                _debug "Including GridPane access logs '/access.log$|staging|canary|gridpane|.gz'"
                SITE_LOGS=$(ls -aSd $sitelogsdir/* | grep access | egrep -v '/access.log$|staging|canary|gridpane|.gz' | tr '\n' ' ')
        fi
        _debug "\$SITE_LOGS=${SITE_LOGS}"
}


# -- web logs files
collect_weblogs () {
	_debug_function
	# OLS logs
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
	else
		_error "-- Didn't find OLS logs"
	fi

	# Nginx logs
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
	else
		_error "-- Didn't find Nginx logs"
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
	
collect_accesslogs () {
# -- Check for website log files
if [[ $ACCESS_LOGS == "1" ]]; then
	# Access logs
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
else
	_debug "Not including web access logs"
fi
}

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