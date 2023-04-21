#!/bin/bash
# --------------------------
# -- wpst version v0.1.0
# Lazy way to provide help and a wrapper to related tools.
# -------------------------
VERSION=0.1.0
SCRIPT_NAME=wpst
DEBUG_ON="0"

# -----------
# -- Includes
# -----------
. $(dirname "$0")/functions.sh

# ------------
# -- Variables
# ------------

# -- USAGE
USAGE=\
"WordPress Shell Tools - $VERSION

Commands:

    wpst-goaccess        - Run goaccess on web server logs
    wpst-sql             - Run common WordPress SQL Commands
    wpst help                 - This help.

WPSET Version $WPST_VERSION
"

# -- usage
usage () {
    echo "$USAGE"    
}

# ------------
# -- Main Loop
# ------------
ACTION="$2"
if [[ ! $ACTION ]]; then
	usage
	exit 1
elif [[ $ACTION = "help" ]]; then
		usage
		exit 1
fi