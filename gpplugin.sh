#!/bin/bash
# Variables
GP_WWW_PATH="/var/www/"
WP_CLI_OPTIONS="--allow-root --skip-plugins"

help () {
	echo "Lists WordPress plugins on all websites on a GridPane Server"
	echo ""
	echo "Syntax: gpplugin -a <plugin>"
	echo "  options"
	echo "  -a	List all plugins"
	echo "  -p	Status on specific plugin"
	echo ""
	echo "Notes:"
	echo "  * Find out which sites have which plugins + search for specific plugins and print wp-cli plugin status"
	echo "  * Excludes canary + staging + 22222 + nginx + *.gridpanevps.com sites"
	echo "	* --skip-plugins is run as to not fail potentially due to an error with a plugin"
	exit
}

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -a|--all)
    ALL="YES"
    shift # past argument
    shift # past value
    ;;
    -p|--plugin)
    PLUGIN="$2"
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

if [ ! -z $PLUGIN ]; then
	echo "Searching for $PLUGIN on all sites"
	ls -1 $GP_WWW_PATH | grep -vE 'canary|staging' | grep -vE '22222|nginx|gridpanevps.com' | xargs -i sh -c "echo '\033[1;42m$GP_WWW_PATH{}\e[0m';wp $WP_CLI_OPTIONS --path=$GP_WWW_PATH{}/htdocs plugin status $PLUGIN"
elif [ ! -z $ALL ]; then
	echo "Searching for all plugins on all sites!"
	ls -1 $GP_WWW_PATH | grep -vE 'canary|staging' | grep -vE '22222|nginx|gridpanevps.com' | xargs -i sh -c "echo '\033[1;42m$GP_WWW_PATH{}\e[0m';wp $WP_CLI_OPTIONS --path=$GP_WWW_PATH{}/htdocs plugin status"
else
	help
fi
