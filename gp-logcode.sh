#!/usr/bin/env bash
# - gp-logcode
. $(dirname "$0")/functions.sh
_debug "Loading functions.sh"

# -- getopts
while getopts "c:m:l:d:r:ezx" option; do
        case ${option} in
                c) LOGCODE=$OPTARG ;;
                m) MODE=$OPTARG ;;
                l) LOGFILE=$OPTARG ;;
                d) DOMAIN=$OPTARG ;;
		r) RESULTS=$OPTARG ;;
                e) GP_EXCLUDE=1 ;;
                z) Z_INCLUDE=1 ;;
                x) DEBUG=1 ;;
                ?) usage ;;
        esac
done

_debug "args: $@"
_debug "getopts: \$LOGCODE=$LOGCODE \$MODE=$MODE \$LOGFILE=$LOGFILE \$DOMAIN=$DOMAIN \$RESULTS=$RESULTS \$GP_EXCLUDE=$GP_EXCLUDE \$Z_INCLUDE=$Z_INCLUDE"
_debug_all


# Usage
usage () {
        echo "Usage: $SCRIPT_NAME -c <code> -m [all|domain|log] (-l <logfilename>|-d <domain>) [-r results] [-e]"
	echo ""
	echo "Commands:"
        echo "  -c <code> = the http status code to locate number 4 = 4xx, 5 = 5xx, 404"
	echo "  -m <mode>		- Log Method"
	echo "					- all = all logs"
	echo "					- domain = domain logs"
	echo "					- log = single log, requires -l"
        echo "  -l <logfilename> 	- Specific log file when using -m log"
        echo "	-d <domainname>	- Domain logs when using -m domain"
        echo ""
        echo "  Options"
        echo "    -r [results] = number of results, optional, default 40"
        echo "    -e = exclude GridPane, staging and canary."
        echo "    -z = include compressed files"
        echo "	  -x = debug"
}

# -- check_logs
check_logs () { # Nginx or OLS?
	_debug "check_logs()"
	_debug "Checking if logs exist"

	# Paths
	nginxlogs=/var/log/nginx
	olslogs=/var/log/ols

	if [ -d $nginxlogs ]; then
	        _debug "Found nginx logs under $nginxlogs"
	        LOGFILEDIR=$nginxlogs
	elif [ -d $olslogs ]; then
	        _debug "Found ols logs under $olslogs"
	        LOGFILEDIR=$olslogs
	elif [[ $TEST ]]; then
		_debug "In test mode, using test data"
		LOGFILEDIR=$SCRIPTPATH/tests
	else
	        _error "No $nginxlogs or $olslogs directory"
	        exit
	fi
}

<<<<<<< HEAD
<<<<<<< HEAD
main () {
	_debug "main()"
	# Set results if not defined.
	if [ -z $results ];then
		results="40"
	fi
	_debug "results=$results"

	# All logs or just one?
	if [[ $alllogs == "1" ]]; then
		_debug "argument -a set - all log file mode"
	        # Exclude gridpane specific logs
	        if [[ $exclude == "-e" ]]; then
	                _debug "argument -e set - exclude gp, staging and canary sites in $logfiledir/*"
	                files=$(ls -aSd $logfiledir/* | grep access | egrep -v '/access.log$|staging|canary|gridpane|.gz')
	        else
	        	_debug "go through all logs in $logfiledir/*"
	                files=$(ls -aSd $logfiledir/* | egrep -v '.gz')
	        fi
	        _debug "logfiles selected"
	        _debug "$files"
	
	# Just one log file.
	else
	        _debug "single log file mode"
	        _debug "checking log files "
	        _debug " - $logfilename"
	        if [ -f $logfiledir/$logfile ]; then
	                _success "Log file exists - $logfile"
	                files=$(ls -aSd $logfiledir/$logfile)
	        else
	                _error "Log file $logfiledir/$logfile doesn't exist"
=======
process_options () {
	# Confirm exclude
	if [[ $GP_EXCLUDE == "-e" ]]; then
		_debug "argument -e set - exclude gp, staging and canary sites in $LOGFILEDIR/*"
               	EXCLUDE="| egrep -v '/access.log$|staging|canary|gridpane|.gz'"
        else
              	EXCLUDE=""
        fi
                
	# Set results if not defined.
        if [ -z $RESULTS ];then
                RESULTS="40"
        fi
        _debug "RESULTS=$RESULTS"
}

# -- main
main () {
	_debug_function
	
	# Process options
	process_options

	if [[ $1 == "all" ]]; then
		# Mode all
		_debug "All logs mode"
		if [[ $Z_INCLUDE ]]; then
			_debug "Include compressed files"
                	PROCESS_FILES=$(ls -aSd $LOGFILEDIR/* $EXCLUDE)
                	_debug "PROCESS_FILES: $PROCESS_FILES"
                else
                	_debug "Exclude compressed files"
	                PROCESS_FILES=$(ls -aSd $LOGFILEDIR/*.log $EXCLUDE)
	                _debug "PROCESS_FILES: $PROCESS_FILES"	                
	        fi
	elif [[ $1 == "domain" ]]; then
		# Mode domain
		_debug "Domain logs mode"
		if [[ $Z_INCLUDE ]]; then
			_debug "Include compressed files"
			PROCESS_FILES=$(ls -aSd $LOGFILEDIR/$DOMAIN* $EXCLUDE)
			_debug "PROCESS_FILES: $PROCESS_FILES"4
		else
			_debug "Exclude compressed files"
			_debug "ls -aSd $LOGFILEDIR/$DOMAIN*.log $EXCLUDE"
			PROCESS_FILES=$(ls -aSd $LOGFILEDIR/$DOMAIN*.log $EXCLUDE)
			_debug "PROCESS_FILES: $PROCESS_FILES"
		fi		
	elif [[ $1 == "log" ]]; then
		# Mode log
	        _debug "Single logfile mode - $LOGFILE"
	        if [[ -f $LOGFILEDIR/$LOGFILE ]]; then
	                _success "Log file exists - $logfile"	                
	                PROCESS_FILES=$LOGFILEDIR/$LOGFILE
	        else
	                _error "Log file $LOGFILEDIR/$logfile doesn't exist"
>>>>>>> dev
=======
process_options () {
	# Confirm exclude
	if [[ $GP_EXCLUDE == "-e" ]]; then
		_debug "argument -e set - exclude gp, staging and canary sites in $LOGFILEDIR/*"
               	EXCLUDE="| egrep -v '/access.log$|staging|canary|gridpane|.gz'"
        else
              	EXCLUDE=""
        fi
                
	# Set results if not defined.
        if [ -z $RESULTS ];then
                RESULTS="40"
        fi
        _debug "RESULTS=$RESULTS"
}

# -- main
main () {
	_debug_function
	
	# Process options
	process_options

	if [[ $1 == "all" ]]; then
		# Mode all
		_debug "All logs mode"
		if [[ $Z_INCLUDE ]]; then
			_debug "Include compressed files"
                	PROCESS_FILES=$(ls -aSd $LOGFILEDIR/* $EXCLUDE)
                	_debug "PROCESS_FILES: $PROCESS_FILES"
                else
                	_debug "Exclude compressed files"
	                PROCESS_FILES=$(ls -aSd $LOGFILEDIR/*.log $EXCLUDE)
	                _debug "PROCESS_FILES: $PROCESS_FILES"	                
	        fi
	elif [[ $1 == "domain" ]]; then
		# Mode domain
		_debug "Domain logs mode"
		if [[ $Z_INCLUDE ]]; then
			_debug "Include compressed files"
			PROCESS_FILES=$(ls -aSd $LOGFILEDIR/$DOMAIN* $EXCLUDE)
			_debug "PROCESS_FILES: $PROCESS_FILES"4
		else
			_debug "Exclude compressed files"
			_debug "ls -aSd $LOGFILEDIR/$DOMAIN*.log $EXCLUDE"
			PROCESS_FILES=$(ls -aSd $LOGFILEDIR/$DOMAIN*.log $EXCLUDE)
			_debug "PROCESS_FILES: $PROCESS_FILES"
		fi		
	elif [[ $1 == "log" ]]; then
		# Mode log
	        _debug "Single logfile mode - $LOGFILE"
	        if [[ -f $LOGFILEDIR/$LOGFILE ]]; then
	                _success "Log file exists - $logfile"	                
	                PROCESS_FILES=$LOGFILEDIR/$LOGFILE
	        else
	                _error "Log file $LOGFILEDIR/$logfile doesn't exist"
>>>>>>> dev
	                exit
	        fi
	fi
	
	# logcode
	if [[ $LOGCODE -lt 10 ]]; then
		_debug "logcode is less than 10"
		logcode="$logcode[0-9][0-9]"
	fi

	for file in $PROCESS_FILES; do
	        _debug "Processing $file"
		if [[ $Z_INCLUDE == "1" ]]; then
                        _debug "Running -- zgrep \" $LOGCODE \" $file | awk '{ print $6" - "$10" - "$7" "$8" "$9}' | sort | uniq -c | sort -nr | head -$RESULTS)"
                        content=$(zgrep "\" $LOGCODE " $file | awk '{ print $6" - "$10" - "$7" "$8" "$9}' | sort | uniq -c | sort -nr | head -$RESULTS)
		else
			_debug "Running -- grep \" $LOGCODE \" $file | awk '{ print $6" - "$10" - "$7" "$8" "$9}' | sort | uniq -c | sort -nr | head -$RESULTS)"
		        content=$(grep "\" $LOGCODE " $file | awk '{ print $6" - "$10" - "$7" "$8" "$9}' | sort | uniq -c | sort -nr | head -$RESULTS)
		fi	
		# Print content
	        if [[ $content ]]; then
			echo "##### File: $file"
	        	echo "$content"
		        echo "...more lines but limited to top $RESULTS"
		else
			_debug "No data in $file"
		fi
	done
}

# -------
# -- Main
# -------

check_logs

if [[ -z $LOGCODE ]] || [[ -z $MODE ]]; then
        usage
        _error "Need to specify -c <code> and -m <method>"
        exit
fi

<<<<<<< HEAD
<<<<<<< HEAD
# handle non-option arguments
_debug "logcode: $logcode, logfile: $logfile, alllogs: $alllogs, exclude:$exclude, results:$results"
_debug "args: $@"
if [[ -z $logcode ]]; then
=======
=======
>>>>>>> dev
if [[ $MODE == "all" ]]; then
	# Log all
	_debug "mode: $MODE"
	main all
elif [[ $MODE == "domain" ]]; then
	# Log domain
        _debug "mode: $MODE"
        if [[ $DOMAIN ]]; then
                _debug "domain: $DOMAIN"
                main domain
        else
                _error "Need to specify domain via -d <domain>"
        fi
elif [[ $MODE == "log" ]]; then
	# Log mode
        _debug "mode: $MODE"
        if [[ $LOGFILE ]]; then
                _debug "logfile: $LOGFILE"
                main log $LOGFILE
        else
                _error "Need to specify logfile via -l <logfile>"
        fi
else
<<<<<<< HEAD
>>>>>>> dev
	usage
fi

<<<<<<< HEAD
check_logs
main
=======
>>>>>>> dev
=======
	usage
fi

>>>>>>> dev
