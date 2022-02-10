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

# ----------------------------------------------
# -- Help function and it's associated functions
# ----------------------------------------------

# -- debug
_debug () {
	if [ -f .debug ];then
		echo " **** DEBUG $1"
	fi
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