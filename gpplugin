#!/bin/bash
help () {
	echo "Usage: gpplugin -a <plugin>"
	echo ""
	echo "-Find out which sites have which plugins + search for specific plugins and print wp-cli plugin status"
	echo "-Excludes canary + staging + 22222 + nginx + *.gridpanevps.com sites"
}

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -a|--all)
    ALL="$2"
    shift # past argument
    shift # past value
    ;;
    -c|--command)
    COMMAND="$2"
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

PLUGIN=$1
ls -1 | grep -vE 'canary|staging' | grep -vE '22222|nginx|gridpanevps.com' | xargs -i sh -c "echo '\033[1;42m{}\e[0m';wp --allow-root --path=/var/www/{}/htdocs plugin status $PLUGIN"