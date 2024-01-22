#!/bin/bash
DRYRUN="1"
ACTION="$1"

dmp_usage () {
    echo "Usage: delete-mu-plugins.sh <go|help>"
    echo ""
    echo "A script to move mu-plugins from each domain to a backup folder as a removal method."
    echo "Configuration is done in delete-mu-plugins.conf"
    echo ""
    echo "Arguments:"
    echo "  go              Move mu-plugins from each domain to a backup folder."
    echo "  help            Display this help message."
    echo ""
    echo "Example delete-mu-plugins.conf:"
    echo ""
    echo "SOURCE_DIR=\"/var/www\""
    echo "BACKUP_DIR=\"/root/backup\""
    echo "DOMAIN_LIST=('domain1.com' 'domain2.com' 'domain3.com')"
    echo "FILES_FOLDERS_DELETE=('htdocs/wp-content/mu-plugins/pluginfile.php' 'htdocs/wp-content/plugins/testplugin' 'htdocs/wp-content/mu-plugins/test.php')"
    echo "DRYRUN=0"
    echo ""
    echo "Note, DRYRUN is always set as default, so you must set it to 0 to run the script."
    exit 1
}

# -- _dryrunexit
# -- Exit if DRYRUN is set to 1
_dryrunexit () {
    if [[ $DRYRUN == "0" ]]; then        
        exit 1
    fi        
}

# -- Move files and folders
# -- move_files (SOURCE_DIR, BACKUP_DIR, DOMAIN, FILES_FOLDERS_DELETE DRYRUN)
function move_files () {
    local SOURCE_DIR="$1"
    local BACKUP_DIR="$2"
    local DOMAIN="$3"
    local FILES_FOLDERS_DELETE="$4"
    local DRYRUN="$5"

    echo "----- Processing $DOMAIN -----"

    if [[ $DRYRUN == "1" ]]; then    
        echo "- Dry run enabled. Skipping move operation."
        for ITEM in "${FILES_FOLDERS_DELETE[@]}"; do
            echo "- Processing $DOMAIN and in $SOURCE_DIR/$DOMAIN/$ITEM to $BACKUP_DIR/$SOURCE_DIR/$DOMAIN/$ITEM"
            echo "#> rsync -avR --remove-source-files \"$SOURCE_DIR/$DOMAIN/$ITEM\" \"$BACKUP_DIR\""
        done                
    else
        for ITEM in "${FILES_FOLDERS_DELETE[@]}"; do
            echo "- Processing $DOMAIN and in $SOURCE_DIR/$DOMAIN/$ITEM to $BACKUP_DIR/$SOURCE_DIR/$DOMAIN/$ITEM"             
            # -- Use rsync to maintain directory tree
            rsync -av --remove-source-files "$SOURCE_DIR/$DOMAIN/$ITEM" "$BACKUP_DIR"
        done 
    fi

    echo "----- Done processing $DOMAIN -----"
    echo ""
}

function pre_flight_checks () {
    # -- Grab settings from delete-mu-plugins.conf
    if [[ -f delete-mu-plugins.conf ]]; then
        echo "Found and sourcing delete-mu-plugins.conf"
        source delete-mu-plugins.conf
    else
        echo "Error: delete-mu-plugins.conf not found."
        _dryrunexit
    fi

    # -- Check config
    [[ -n $SOURCE_DIR ]] || { echo "Error: DMP_SOURCE_DIR is not set."; _dryrunexit; }
    [[ -n $BACKUP_DIR ]] || { echo "Error: BACKUP_DIR is not set."; _dryrunexit; }
    [[ -n $DOMAIN_LIST ]] || { echo "Error: DOMAIN_LIST is not set."; _dryrunexit; }
    [[ -n $FILES_FOLDERS_DELETE ]] || { echo "Error: FILES_FOLDERS_DELETE is not set."; _dryrunexit; }

    # -- Check if arrays are arrays    
    [[ "$(declare -p DOMAIN_LIST 2>/dev/null)" =~ "declare -a" ]] || { echo "Error: DOMAIN_LIST is not an array $?."; _dryrunexit; }
    [[ "$(declare -p FILES_FOLDERS_DELETE 2>/dev/null)" =~ "declare -a" ]] || { echo "Error: FILES_FOLDERS_DELETE is not an array $?."; _dryrunexit; }

    # -- Check if $SOURCE_DIR exists
    if [[ ! -d $SOURCE_DIR ]]; then
        echo "Error: $SOURCE_DIR does not exist."
        _dryrunexit
    fi

    # -- Check if $BACKUP_DIR exists
    if [[ ! -d $BACKUP_DIR ]]; then
        echo "Error: $BACKUP_DIR does not exist."
        _dryrunexit
    fi
    echo ""
}
 

# -- Start Main
if [[ $ACTION == "go" ]]; then
    pre_flight_checks
    echo "Starting process"
    echo "----------------"
    echo "Running as: $(whoami)"
    echo "Starting in: $SOURCE_DIR"
    echo "Processing domains: $DOMAIN_LIST"
    echo "Processing files and folders: $FILES_FOLDERS_DELETE"
    echo "Moving files and folders to: $BACKUP_DIR"
    read -p "Proceed? (y/n)" PHASE1_CONFIRM
    echo
    # -- Confirm the move operation    
    if [[ $PHASE1_CONFIRM == "y" ]]; then
        echo "Proceeding."
        for DOMAIN in "${DOMAIN_LIST[@]}"; do        
            move_files "$SOURCE_DIR" "$BACKUP_DIR" "$DOMAIN" "$FILES_FOLDERS_DELETE" "$DRYRUN"
        done        
    else
        echo "Operation canceled."
        exit 1
    fi
else
    dmp_usage
    exit 1
fi