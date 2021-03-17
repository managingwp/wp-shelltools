#!/usr/bin/env bash

# -- Intro
# Created by Jordan v0.1
# 

# -- Variables
gp_api_url="https://my.gridpane.com/oauth/api/v1/$gp_api_endpoint"
gp_api_token=.gptoken
gp_api_cmd=$(curl -s $gp_api_url --header 'Authorization: Bearer $gp_api_access_token')

## - Color
RED='\033[97;41m'
GREEN='\033[97;42m'
YELLOW='\033[30;103m'
NC='\033[0m' # No Color
SUCCESS="${GREEN}* SUCCESS *${NC}"
ERROR="${RED}* ERROR *${NC}"

# -- Variable Ingestion
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -v|--value)
    VALUE="$2"
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

if [[ -n $1 ]]; then
    unknown_options=$1
fi

# -- Functions
_debug () {
	if [ -f .debug ]; then
                echo -e "\n${YELLOW} Debug:${NC} $@"
        fi
}

# echo commands run using | exe eval ls -al
exe() { echo "\$ $@" ; "$@" ; }

run_api () {
	api_output=$(eval curl -s --location --request $@ --header \'Authorization: Bearer $gp_api_access_token\')
	_debug "Running curl --location --request $@ --header 'Authorization: Bearer $gp_api_access_token'"
	if [ $? -ne 0 ]; then
		echo $api_output
		exit
	fi
}

check_gptoken () {
	if [ -f "$gp_api_token" ]; then
		echo -e "$SUCCESS GP Token file found $gp_api_access_token"
		source $gp_api_token
	else
		echo -e "$ERROR GP Token file missing, please place your GridPane API Token in the file named .gptoken"
		exit
	fi
}

test_gptoken () {
	test_path="GET 'https://my.gridpane.com/oauth/api/v1/user'"
	run_api $test_path
	_debug $api_output
	api_output_test=$(echo $api_output | cut -c1-6)
	if [[ $api_output_test == '{"id":' ]]; then
		echo -e "$SUCCESS API Success! $NC"
	else
		echo -e "$ERROR API Failure...something is wrong! $NC"
		exit
	fi
	#api_test_output=$(echo $api_output | jq ' . | {name: .name, id: .id, email: .email}')
}

help () {
	echo "Syntax: gpapi -c <command> -v <value>"
	echo ""
	echo "Commands:"
	echo "d2s 	- Domain to Server value=domain.com"
}

send_command () {
	echo "Send command"
}

# -- Init
check_gptoken
test_gptoken