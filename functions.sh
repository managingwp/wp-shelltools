# ---------------
# -- functions.sh
# ---------------

# ------------
# -- Variables
# ------------
VERSION="0.4.0"
SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
REQUIRED_APPS=("jq" "column")
[[ -f .test ]] && TEST=$(<$SCRIPTPATH/.test) || TEST="0"
[[ -f .debug ]] && DEBUG=$(<$SCRIPTPATH/.debug) || DEBUG="0"
[[ -z $DEBUG ]] && DEBUG="0"
[[ -z $TEST ]] && TEST="0"

# -- colors
export TERM=xterm-color
export CLICOLOR=1
export LSCOLORS=ExFxCxDxBxegedabagacad

export NC='\e[0m' # No Color
export CBLACK='\e[0;30m'
export CGRAY='\e[1;30m'
export CRED='\e[0;31m'
export CLIGHT_RED='\e[1;31m'
export CGREEN='\e[0;32m'
export CLIGHT_GREEN='\e[1;32m'
export CBROWN='\e[0;33m'
export CYELLOW='\e[1;33m'
export CBLUE='\e[0;34m'
export CLIGHT_BLUE='\e[1;34m'
export CPURPLE='\e[0;35m'
export CLIGHT_PURPLE='\e[1;35m'
export CCYAN='\e[0;36m'
export CLIGHT_CYAN='\e[1;36m'
export CLIGHT_GRAY='\e[0;37m'
export CWHITE='\e[1;37m'

# ----------------
# -- Key Functions
# ----------------
_debug () {
        if [ -f .debug ] || (( $DEBUG >= "1" )); then
                echo -e "${CCYAN}**** DEBUG $@${NC}"
        fi
}

# -- debug curl
_debug_curl () {
                if [[ $DEBUG == "2" ]]; then
                        echo -e "${CCYAN}**** DEBUG $@${NC}"
                fi
}

# -- show debug information
_debug_all () {
        _debug "--------------------------"
        _debug "arguments - $@"
        _debug "funcname - ${FUNCNAME[@]}"
        _debug "basename - $SCRIPTPATH"
        _debug "sourced files - ${BASH_SOURCE[@]}"
        _debug "--------------------------"
}

_debug_function () {
	_debug "function: ${FUNCNAME[1]}"
}

# -- error message
_error () {
        echo -e "${CRED}$@${NC}";
}

# -- success message
_success () {
        echo -e "${CGREEN}$@${NC}";
}

# -- Check root
_checkroot () {
	if [ ! -f .debug ]; then
	        if [ "$EUID" -ne 0 ]
	                then echo "Please run as root"
	                exit
	        fi
	fi
}

# --
# -- GridPane specific functions
# --

# -- _getsitelogs
_getsitelogs () {
	_debug_function
        if [ -d "/var/log/nginx" ]; then
		_debug "Found nginx log directory"
                sitelogsdir="/var/log/nginx"
        elif [ -d "/var/log/lsws" ]; then
        	_debug "found OLS log directory"
                sitelogsdir="/var/log/lsws"
        fi
	SITE_LOGS=$(ls -aSd $sitelogsdir/* | grep access | egrep -v '/access.log$|staging|canary|gridpane|.gz' | tr '\n' ' ')
	_debug "\$SITE_LOGS=${SITE_LOGS}"
}

# --
# -- Help Stuff
# --

# -- help_cmd associative array
declare -A help_cmd

# -- 
# -- Functions for external script files
# --

# - logs
help_cmd[logs]='tail or show last lines on all GridPane logs.'
tool_logs () {
        gp-logs.sh $@
}
 
# - logcode
help_cmd[logcode]='Look for specifc HTTP codes in web server logfiles and return top hits.'
tool_logcode () {
        gp-logcode.sh $@
}

# - mysqlmem
help_cmd[mysqlmem]='GridPane monit memory calculation'
tool_mysqlmem () {
        gp-mysqlmem.sh $@
}

# - plugins
help_cmd[plugins]='Lists WordPress plugins on all websites on a GridPane Server'
tool_plugins () {
        gp-plugins.sh $@
}

# --
# -- Small Functions
# --

# - goaccess - execute log functions
help_cmd[goaccess]='Process GridPane logs with goaccess'
tool_goaccess () {
        # Usage
        if [ -v $2 ]; then
                echo "Usage: $SCRIPT_NAME gp-goaccess [<domain.com>|-a]"
                return
        fi

        # Formats for goaccess
        LOG_FORMAT='[%d:%t %^] %h %^ - %v \"%r\" %s %b \"%R\" \"%u\"\'
        DATE_FORMAT='%d/%b/%Y\'
        TIME_FORMAT='%H:%M:%S %Z\'

        _debug "goaccess arguments - $ACTION"
        _debug "goaccess LOG_FORMAT = $LOG_FORMAT ## DATE_FORMAT = $DATE_FORMAT ## TIME_FORMAT = $TIME_FORMAT"
        # -- Check args.
        if [ -v $ACTION ]; then
                echo "Usage: gp-tools goaccess [<domain.com>|-a]"
                echo "  -a will go through all the logs versus a single domain"
                return
        fi

        # Main
        if [ $ACTION = "-a" ]; then
                zcat /var/log/nginx/$2.access.log.*.gz | goaccess --log-format="$LOG_FORMAT" --date-format="$DATE_FORMAT" --time-format="$TIME_FORMAT"
        else
                cat /var/log/nginx/$1.access.log | goaccess --log-format="$LOG_FORMAT" --date-format="$DATE_FORMAT" --time-format="$TIME_FORMAT"
        fi
}

# - gpcron
help_cmd[gpcron]='List sites using GP Cron'
tool_gpcron () {
	grep 'cron:true' /var/www/*/logs/*.env	
}

# - backups - execute log functions
help_cmd[backups]='List backups for all sites on the server.'
tool_backups () {
	ls -aL /home/*/sites/*/logs/backups.env | xargs -l -I {} sh -c "echo {} | awk -F/ '{print \$5}'|tr '\n' '|'; tr '\n' '|' < {};echo \n"
}

# - api - GridPane api
help_cmd[api]='Interact with the GridPane API'
tool_api () {
	gp-api.sh $@
}