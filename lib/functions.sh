# ---------------
# -- functions.sh
# ---------------

# ------------
# -- Variables
# ------------
[[ $WPST_VERSION ]] || WPST_VERSION="$(cat ${SCRIPT_DIR}/../VERSION)"
[[ $SCRIPT_DIR ]] || SCRIPT_DIR="$( dirname "${BASH_SOURCE[0]}" )"
REQUIRED_APPS=("jq" "column")
if [[ $DEBUG_ON="1" ]]; then DEBUG="1"; fi

# -- Colors
RED="\033[0;31m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
BLUEBG="\033[0;44m"
YELLOWBG="\033[0;43m"
GREENBG="\033[0;42m"
DARKGREYBG="\033[0;100m"
ECOL="\033[0;0m"

# ----------------
# -- Core Functions
# ----------------

_error () { echo -e "${RED}** ERROR ** - ${*} ${ECOL}"; }
_warning () { echo -e "${RED}** WARNING ** - ${*} ${ECOL}"; }
_notice () { echo -e "${BLUE}** NOTICE ** - ${*} ${ECOL}"; }
_success () { echo -e "${GREEN}** SUCCESS ** - ${*} ${ECOL}"; }
_running () { echo -e "${BLUEBG}${@}${ECOL}"; }
_loading () { echo -e "${BLUEBG}${@}${ECOL}"; }
_creating () { echo -e "${DARKGREYBG}${@}${ECOL}"; }
_separator () { echo -e "${YELLOWBG}****************${ECOL}"; }

# -- _debug
_debug () {
    if [[ $DEBUG_ON == "1" ]]; then
        echo -e "${CYAN}** DEBUG: ${*}${ECOL}"
    fi
}

# -- show debug information
_debug_all () {
        _debug "--------------------------"
        _debug "arguments: ${*}"
        _debug "funcname: ${FUNCNAME[@]}"
        _debug "basename: $SCRIPTPATH"
        _debug "sourced files: ${BASH_SOURCE[@]}"
        _debug "--------------------------"
}

# -- debug curl
_debug_curl () {
                if [[ $DEBUG == "2" ]]; then
                        echo -e "${CCYAN}**** DEBUG ${*}${NC}"
                fi
}

# -- _cexists -- Returns 0 if command exists or 1 if command doesn't exist
_cexists () {
		if [[ "$(command -v $1)" ]]; then
            _debug $(which $1)
			if [[ $ZSH_DEBUG == 1 ]]; then
            	_debug "${*} is installed";
            fi
            CMD_EXISTS="0"
        else
            if [[ $ZSH_DEBUG == 1 ]]; then
            	_debug "${*} not installed";
            fi
            CMD_EXISTS="1"
        fi
        return $CMD_EXISTS
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

# -- check_for_updates
help_cmd[check-update]="Check for updates to wpst"
function tool_check-update () {
    local script_name="$1"
    local github_url="$2"
    
    # Get the local version from the VERSION file
    local local_version
    if [[ -f "VERSION" ]]; then
        local_version=$(cat "VERSION")
    else
        echo "ERROR: VERSION file not found."
        return 1
    fi
    
    # Get the remote version from GitHub
    local remote_version
    remote_version=$(curl -sSL "$github_url/VERSION")
    if [[ -z "$remote_version" ]]; then
        echo "ERROR: Failed to retrieve remote version from GitHub."
        return 1
    fi
    
    # Compare local and remote versions
    if [[ "$local_version" == "$remote_version" ]]; then
        echo "Your script ($script_name) is up to date."
    else
        echo "Your script ($script_name) is out of date."
        echo "Local version: $local_version"
        echo "Remote version: $remote_version"
    fi
}