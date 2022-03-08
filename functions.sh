# ---------------
# -- functions.sh
# ---------------

# ------------
# -- Variables
# ------------
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# ----------------
# -- Key Functions
# ----------------
_debug () {
        if [ -f $SCRIPT_DIR/.debug ];then
                echo -e "${CCYAN}**** DEBUG $@${NC}"
        fi
}

_error () {
        echo -e "${CRED}$@${NC}";
}

_success () {
        echo -e "${CGREEN}$@${NC}";
}

# - _getsitelogs
_getsitelogs () {
	if [ -d "/var/log/nginx" ]; then
		sitelogsdir="/var/log/nginx"
	elif [ -d "/var/log/lsws" ]; then
		sitelogsdir="/var/log/lsws"
	fi
	files=$(ls -aSd $logfiledir/* | grep access | egrep -v '/access.log$|staging|canary|gridpane|.gz')
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
# -- Colors
# --
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