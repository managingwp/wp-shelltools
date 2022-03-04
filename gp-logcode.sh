#!/usr/bin/env bash
# - gp-logcode
. $(dirname "$0")/functions.sh
_debug "Loading functions.sh"

# Usage
usage () {
        echo "Usage: $SCRIPT_NAME logcode -c <code> (-l <logfilename>|-a) [-e] [-r results]"
        echo "  -c <code> = the http status code number 4 = 4xx, 5 = 5xx, 404"
        echo "  -l <logfilename> = specific log file or -a for all"
        echo "  -a = all nginx log files"
	echo ""
        echo "  Optional"
        echo "    -r [results] = number of results, optional, default 40"
        echo "    -e = exclude GridPane, staging and canary."
}


check_logs () { # Nginx or OLS?
	_debug "Checking if logs exist"
	nginxlogs=/var/log/nginx
	olslogs=/var/log/ols
	if [ -d $nginxlogs ]; then
	        _debug "Found nginx logs under $nginxlogs"
	        logfiledir=$nginxlogs
	elif [ -d $olslogs ]; then
	        _debug "Found ols logs under $olslogs"
	        logfiledir=$olslogs
	else
	        _error "No $nginxlogs or $olslogs directory"
	        exit
	fi
}

main () {
	# Set results if not defined.
	if [ -z $results ];then
		results="40"
	else 
		results=$5;_debug
	fi
	_debug "results=$results"

	# All logs or just one?
	if [[ $logfilename == "-a" ]]; then
		_debug "Going through all alog files"
	        # Exclude gridpane specific logs
	        if [[ $exclude == "-e" ]]; then
	                _debug "Argument -e set, will exclude GridPane, staging and canary"
	                files=$(ls -aSd $logfiledir/* | grep access | egrep -v '/access.log$|staging|canary|gridpane|.gz')
	        else
	                files=$(ls -aSd $logfiledir/* | egrep -v '.gz')
	        fi
	        _debug "Files selected"
	        _debug "$files"
	
	# Just one log file.
	else
	        _debug "Checking log file $logfilename"
	        if [ -f $logfiledir/$logfile ]; then
	                _debug "Log file exists - $logfile"
	                files=$(ls -aSd $logfiledir/$logfile)
	        else
	                echo "Log file $logfiledir/$logfile doesn't exist"
	        fi
	fi
	
	# logcode
	if [[ $logcode -lt 10 ]]; then
		_debug "logcode is less than 10"
		logcode="$logcode[0-9][0-9]"
	fi

	for file in $files; do
	        _debug "Processing $file"
	        _debug "Running -- grep \" $logcode \" $file | awk '{ print \$6\" - \"\$10\" - \"\$7\" \"$8\" \"\$9}' | sort | uniq -c | sort -nr | head -$results"
	        content=$(grep "\" $logcode " $file | awk '{ print $6" - "$10" - "$7" "$8" "$9}' | sort | uniq -c | sort -nr | head -$results)
	        echo "$content"
	        echo "...more lines but limited to top $results"
	done
}

# --
# Parse Arguments
# --

# -allow a command to fail with !’s side effect on errexit
# -use return value from ${PIPESTATUS[0]}, because ! hosed $?
! getopt --test > /dev/null 
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo 'I’m sorry, `getopt --test` failed in this environment.'
    exit 1
fi

OPTIONS=c:l:aer:
LONGOPTS=logcode:,logfile:,all,exclude,results:

# -regarding ! and PIPESTATUS see above
# -temporarily store output to be able to check for errors
# -activate quoting/enhanced mode (e.g. by writing out “--options”)
# -pass arguments only via   -- "$@"   to separate them correctly
! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    # e.g. return value is 1
    #  then getopt has complained about wrong arguments to stdout
    exit 2
fi
# read getopt’s output this way to handle the quoting right:
eval set -- "$PARSED"

c=- l=- a=n e=n r=-
# now enjoy the options in order and nicely split until we see --
# logcode -c <code> (-l <logfilename>|-a) [-e] [-r results]
while true; do
    case "$1" in
        -c|--logcode)
            logcode=$2
            shift 2
            ;;
        -l|--logfile)
            logfile=$2
            shift 2
            ;;
        -a|--all)
            alllogs="1"
            shift 1
            ;;
        -e|--exclude)
            exclude="1"
            shift 1
            ;;
        -r|--results)
            results=$2
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Programming error"
            exit 3
            ;;
    esac
done

# handle non-option arguments
_debug "logcode: $logcode, logfile: $logfile, alllogs: $alllogs, exclude:$exclude, results:$results"
_debug "$#"
if [[ -z $logcode ]]; then
	usage
	_error "No http code provided"
	exit 4
elif [[ -z $logfile ]] && [[ -z $alllogs ]]; then
	usage
	_error "Specify a -l <logfile> or -a for all logs"
	exit 4
fi

check_logs
main