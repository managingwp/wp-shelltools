#!/usr/bin/env bash
# --------------------------
# -- gp-tools wrapper script v0.0.1
# 
# Lazy way to provide help and a wrapper to related tools.
# -------------------------
source functions.sh
SCRIPT_NAME=gp-tools
VERSION=0.0.1
echo "-- Loading $SCRIPT_NAME - v$VERSION"
. $(dirname "$0")/functions.sh

declare CMD
declare ACTION
CMD=${1:null}
ACTION=${2:null}

# -- colors
# -- Colors
export TERM=xterm-color
export GREP_OPTIONS='--color=auto' GREP_COLOR='1;32'
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

# ----------------------------------------------
# -- Help function and it's associated functions
# ----------------------------------------------

# -- debug
_debug () {
	if [ -f .debug ];then
		echo -e "${CCYAN}**** DEBUG $1${NC}"
	fi
}

_error () {
	echo -e "${CRED}$@${NC}";
}

_success () {
	echo -e "${CGREEN}$@${NC}";
}

# -- Help
help () {
        if [ ! $1 ]; then
        	help_intro
        fi
}

# -- Help introduction
help_intro () {
	echo ""
        echo "** General help for $SCRIPT_NAME **"
        echo "-----------------------------------"
	echo " all		- List all commands"
	echo " core		- List all core commands"
	echo " log		- List all log commands"
	echo ""
        echo "Examples:"
        echo " --"
        echo " gp-tools all"
	echo " gp-tools log"
	echo " gp-tools log tail"
	echo ""

}

# -- core commands
help_topic () {
	echo ""
	echo " ** Help for $1"
	echo "----------------"
	if [ $1 = 'core' ]; then
		echo "version		- Script version"
	fi
	if [ $1 = 'log' ]; then
		echo "log tail		- Tail all log files"
		echo "log last		- Last 50 lines of all log files."
	fi
}

exec_tool () {	
	if [[ $CMD == 'log' ]]; then
		if [ ! $ACTION ]; then
			help_topic log
		elif [[ $ACTION == 'tail' ]] || [[ $ACTION == 'last' ]]; then
                        exec_log $2
                fi
	else
		help_topic log
	fi
}

# --------------
# -- Main script
# --------------

_debug "command: $CMD action: $ACTION"
if [ ! $1 ]; then
        help_intro
else
	if [ $1 = 'help' ]; then
		if [ $2 ]; then 
			help $2
		else
			help_intro
		fi
	else
		exec_tool $@
	fi
fi