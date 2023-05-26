#!/usr/bin/env bash
# - gp-logcode
. $(dirname "$0")/functions.sh
_debug "Loading functions.sh"

usage () {
	echo "Usage: nothing yet!"
}

tuneswap () {
	# Tune swap
	##ISSUE need to check if swappiness is already tuned.
	echo " -- Tuning /proc/sys/vm/swappiness"	
	echo 1 >  /proc/sys/vm/swappiness
}
