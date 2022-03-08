#!/usr/bin/env bash
# --------------------------
# -- gp-tools wrapper script v0.0.1
# 
# Lazy way to provide help and a wrapper to related tools.
# -------------------------
SCRIPT_NAME=gp-tools
VERSION=0.0.1

# -------
# -- Init
# -------
echo "-- Loading $SCRIPT_NAME - v$VERSION"
. $(dirname "$0")/functions.sh
_debug "Loading functions.sh"

# ------------
# -- Functions
# ------------

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
	for key in "${!help_cmd[@]}"; do
		 printf '  help %-15s - %-15s\n' "$key" "${help_cmd[$key]}"
	done
	echo ""
        echo "Examples:"
        echo " --"
        echo "  gp-tools goaccess"
	echo "  gp-tools log"
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
	_debug "Executing $@"
	tool_$1 $@
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