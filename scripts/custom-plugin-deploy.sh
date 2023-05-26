#!/bin/bash
# -- A script to deploy a custom plugin to all websites on a server

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )" # -- Get current directory
LOG_FILE="$SCRIPT_DIR/script.log" # -- Set the log file path
VERSION="0.0.1"

# -- USAGE
USAGE=\
"custom-plugin-deploy.sh -p <platform> -f <plugin-file>

Options:
    -p|--platform     - The platform to deploy the plugin to. (gp|runcloud|cpanel) (Required)
    -f|--file         - The plugin file to deploy. (Required)

Version: $SCRIPT_VERSION
"

# -- usage
usage () {
    echo "$USAGE"    
}

# -- Get Parameters
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -p|--platform)
    PLATFORM="$2"
    shift # past argument
    shift # past value
    ;;
    -f|--file)
    PLUGIN_FILE="$2"
    shift # past argument
    shift # past value
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

# ------------
# -- Main Loop
# ------------
if [[ -n $PLATFORM || -n $PLUGIN_FILE ]]; then
	usage
    echo "Error: Missing required parameters"
	exit 1
elif [[ $ACTION = "help" ]]; then
		usage
		exit 1
fi


# -- Check if the plugin file exists
if [[ ! -f "$PLUGIN_FILE" ]]; then
    echo "Error: $PLUGIN_FILE does not exist." >&2
    exit 1
fi

# -- Gather websites and directories
if [[ $PLATFORM == "gp" ]]; then
    echo "Collecting website paths.."
    WEBSITE_PATHS=$()

# -- Iterate through each website directory
for website_dir in /var/www/website/*; do
  if [[ -d "$website_dir" ]]; then
    website_name=$(basename "$website_dir")
    mu_plugins_dir="$website_dir/htdocs/wp-content/mu-plugins"
    script_path="/path/to/script.sh"

    # Check if the mu-plugins directory exists
    if [[ ! -d "$mu_plugins_dir" ]]; then
      mkdir -p "$mu_plugins_dir"  # Create the mu-plugins directory if it doesn't exist
      cp "$script_path" "$mu_plugins_dir"  # Copy the script to the mu-plugins directory
      echo "$(date) - Copied script to $mu_plugins_dir" >> "$LOG_FILE"
    else
      # Check if the script already exists
      if [[ ! -f "$mu_plugins_dir/script.sh" ]]; then
        cp "$script_path" "$mu_plugins_dir"  # Copy the script to the mu-plugins directory
        echo "$(date) - Copied script to $mu_plugins_dir" >> "$LOG_FILE"
      else
        # Get the MD5 hash of the existing script
        md5_hash=$(md5sum "$mu_plugins_dir/script.sh" | awk '{print $1}')
        echo "$(date) - Script already exists at $mu_plugins_dir with MD5 hash: $md5_hash" >> "$LOG_FILE"
      fi
    fi
  fi
done
