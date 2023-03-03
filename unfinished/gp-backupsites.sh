#!/usr/bin/env bash

# -- Intro
# Created by Jordan v0.1

# -- Variables
BACKUP_DIR="/var/www/backups/gpbksite"

## - Color
RED='\033[97;41m'
GREEN='\033[97;42m'
YELLOW='\033[30;103m'
NC='\033[0m' # No Color
SUCCESS="${GREEN}* SUCCESS *${NC}"
ERROR="${RED}* ERROR *${NC}"

# -- debug command line
_debug () {
        if [ -f .debug ]; then
                echo -e "\n${YELLOW} Debug:${NC} $@"
        fi
}
_debug "Running $@"

# -- Variable Ingestion
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -s|--site)
    SITE="$2"
    shift # past argument
    shift # past value
    ;;
    -a|--all)
    ALLSITES="true"
    shift # past argument
    shift # past value
    ;;
    -f|--files)
    DATABASE="true"
    shift # past argument
    shift # past value
    ;;
    -d|--database)
    DATABASE="true"
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

if [[ -n $1 ]]; then
    unknown_options=$1
fi

# -- Functions
# echo commands run using | exe eval ls -al
exe() { echo "\$ $@" ; "$@" ; }

help () {
	echo "Syntax: gpbksite.sh [ -s <site> | -a ]  [ -d | -f ]"
	echo ""
	echo "gpbksite.sh - Allows you to backup a website on GridPane to a .tar file"
	echo ""
	echo "Commands:"
	echo "-s <site> 	- Website to backup"
	echo "-a		- Backup all sites"
	echo ""
	echo "Options:"
	echo "-f 		- Files Only"
	echo "-d		- Databases Only"
	echo "-l		- Location, defaults to /var/backups/gpbksite"
	echo ""
}

if [[ ! -z $SITE ]]; then
	echo "Backing up $SITE"
elif [[ ! -z $ALLSITES ]]; then
	echo "Backing up all sites"
else
	help;exit;
fi



#if [[ $COMMAND == 'test' ]]; then check_gptoken;test_gptoken; fi
#if [[ -z $VALUE ]]; then echo "Specify a value"; exit; fi


#if [[ $COMMAND == 'd2s' ]]; then
#	check_gptoken
#	run_api "GET https://my.gridpane.com/oauth/api/v1/site"
#	_debug $api_output
#	d2s_domain_id=$(echo $d2s_list)
#	_debug $d2s_domain_id
#fi
