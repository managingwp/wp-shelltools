#!/usr/bin/env bash
# --------------------------
# -- gp-tools wrapper script v0.0.1
# 
# Lazy way to provide help and a wrapper to related tools.
# -------------------------
SCRIPT_NAME=gp-tools
VERSION=0.0.1

# ----------------
# -- Key Functions
# ----------------

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

# -------
# -- Init
# -------
echo "-- Loading $SCRIPT_NAME - v$VERSION"
. $(dirname "$0")/functions.sh

# -- Colors
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


# ------------
# -- Functions
# ------------

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
        echo "$SCRIPT_NAME help"
        echo "-----------------------------------"
	printf '  %-20s - %-15s\n' "all" "List all commands"
	for key in "${!help_cmd[@]}"; do
		 printf '  help %-15s - %-15s\n' "$key" "${help_cmd[$key]}"
	done
	echo ""
        echo "Examples:"
        echo " --"
        echo "  gp-tools all"
	echo "  gp-tools log"
	echo "  gp-tools log tail"
	echo ""

}

# -- core commands
help_topic () {
	declare -A help_topic
	help_topic=help_${1}
	_debug ""
	echo ""
	echo "$1 help"
	echo "----------------"
	for key in "${!help_topic[@]}"; do
		printf '  %-15s - %-15s\n' "$key" "${help_topic[$key]}"
	done
}

exec_tool () {	
	if [[ $1 == 'log' ]]; then
		if [ ! $2 ]; then
			_debug "Help for log command"
			help_topic log
		elif [[ $2 == 'tail' ]] || [[ $2 == 'last' ]]; then
			_debug "Executing log $2"
                        exec_log $2
                fi
	else
		_debug "Executing $@"
		tool_$1 $@
	fi
}

# --------------
# -- Main script
# --------------

args=$@
_debug "Command Line Arguments = $args"
if [ ! $1 ]; then
        help_intro
else
	if [ $1 = 'help' ]; then
		if [ $2 ]; then 
			help_topic $2
		else
			help_intro
		fi
	else
		_debug "exec_tool $@"
		exec_tool $@
	fi
fi