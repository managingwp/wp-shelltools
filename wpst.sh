#!/bin/bash
# --------------------------
# Lazy way to provide help and a wrapper to related tools.
# -------------------------
# Get current script directory
SCRIPT_DIR="$( dirname "${BASH_SOURCE[0]}" )"
WPST_VERSION="$(cat ${SCRIPT_DIR}/VERSION)"
SCRIPT_NAME="wpst"

source $SCRIPT_DIR/lib/functions.sh # Core Functions
source $SCRIPT_DIR/lib/functions-gp.sh # GP Functions

# ------------
# -- Variables
# ------------

GP_CMDS=$(wpst_gp_cmds)

# -- USAGE
USAGE=\
"WordPress Shell Tools - $WPST_VERSION - $SCRIPT_DIR

Commands:

    wpst goaccess        - Run goaccess on web server logs
    wpst sql             - Run common WordPress SQL Commands
    wpst help            - This help.
    wpst attackscan      - Run attackscan.sh
    wpst ajaxlog         - Place ajaxlog.php in wp-content/mu-plugins to log ajax requests
    wpst dir             - Change to wpst directory

GP Commands:
$GP_CMDS

Core Commands:
    wpst check-update   - Check for updates

"
# -- usage
usage () {
    echo "$USAGE"
}

# ------------
# -- Main Loop
# ------------
ACTION="$1"
if [[ ! $ACTION ]]; then
	usage
	exit 1
elif [[ $ACTION = "help" ]]; then
    usage
    exit
elif [[ $ACTION = "goaccess" ]]; then
    $SCRIPT_DIR/bin/wpst-goaccess.sh $@
    exit
elif [[ $ACTION = "sql" ]]; then
    $SCRIPT_DIR/bin/sql.sh $@
    exit
elif [[ $ACTION = "attackscan" ]]; then
    $SCRIPT_DIR/bin/attackscan.sh $@
    exit
elif [[ $ACTION = "dir" ]]; then
    echo "Changing to $SCRIPT_DIR"
    cd "${SCRIPT_DIR}"
    exit
elif [[ $ACTION = "ajaxlog" ]]; then
    echo "Downloading ajaxlog.php to current directory"
    # -- Get current working directory and check for mu-plugins
    if [[ "$(basename "$PWD")" == "mu-plugins" ]]; then
        curl -s https://raw.githubusercontent.com/managingwp/wordpress-code-snippets/main/ajaxlog/ajaxlog.php > ajaxlog.php
    else
        echo "Current directory is not mu-plugins"
        exit 1
    fi
# GP Commands

elif [[ $ACTION = gp-* ]]; then
    cmd_$@
elif [[ $ACTION = "check-updates" ]]; then
    wpst_check_updates
else
        usage
        exit 1
fi