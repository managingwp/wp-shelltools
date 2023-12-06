#!/bin/bash
# -- Created by Jordan - hello@managingwp.io - https://managingwp.io
# -- Last Updated: 2023-12-06

# -- Ger version from VERSION
VERSION="1.0.5"
SCRIPT_NAME="cron-shim"

# -- Variables
OUTPUT_FILE="cron-shim-output.csv"
NUM_REQUESTS="20"
LOG_FILE="cron-shim.log"
TEST="0"
TEST_FILE="cron-shim-test.log"
SORT_BY="count" # default sort option
declare -A event_count
declare -A event_high
declare -A event_low

function USAGE () {
    echo "Usage: $SCRIPT_NAME [-t] [-s sort_option] [-l LOG_FILE] -n [number_of_requests (default: 5)]"
    echo ""
    echo "Options"
    echo "  -l,  --log [cron-shim.log]     Path to the cron log file. Default is cron-shim.log"
    echo "  -s,  --sort [seconds/count]      Sort by date or count. Default is date."
    echo "  -t,  --test                   Test mode."
    echo "  -tf, --testlog               Use a test log file instead of a real one. Default cron-shim-test.log"
    echo "  -n,  --num [5]                Number of requests to show. Default is 5."
    echo ""
    echo "Example: $0 -s count cron_log.txt 10"
    echo ""
    echo "Version: $VERSION"
}

# Check if at least one argument is provided
if [ $# -lt 1 ]; then
    USAGE
    exit 1
fi

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -t|--test)
    TEST="1"
    shift # past argument
    ;;
    -tf|--testfile)
    TEST_FILE="$2"
    shift # past argument
    shift # past value
    ;;
    -l|--log)
    LOG_FILE="$2"
    shift # past argument
    shift # past value
    ;;
    -s|--sort)
    SORT_BY="$2"
    shift # past argument
    shift # past value
    ;;
    -n|--num)
    NUM_REQUESTS="$2"
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

# Add CSV header
echo "UniqueID,EventName,DURATIONSeconds,Count" > "$OUTPUT_FILE"

# -- Check test file
if [[ $TEST == "1" ]]; then
    if [[ ! -f $TEST_FILE ]]; then
        echo "Error: Test file $TEST_FILE does not exist." >&2; exit 1;
    fi
    LOG_FILE="$TEST_FILE"
fi

# Determine sorting criteria
if [ "$SORT_BY" = "count" ]; then
    SORT_CRITERIA="-k4,4nr"
elif [ "$SORT_BY" = "seconds" ]; then
    SORT_CRITERIA="-k3,3nr"    
else
    echo "Invalid sort option: $SORT_BY. Defaulting to date."
    SORT_CRITERIA="-k1,1"
fi

# Process the log file
while IFS= read -r line; do
    # Check for the start of a cron job
    if [[ $line == *"Cron job start"* ]]; then
        # Extract the date and time
        DATETIME=$(echo "$line" | grep -oP '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}')
        DATETIME=($DATETIME)
        DATETIME="${DATETIME[0]}_${DATETIME[1]}"
    fi

    # Check for the execution line
    if [[ $line == *"Executed the cron event"* ]]; then
        # Extract the event name and DURATION
        EVENT_NAME=$(echo "$line" | grep -oP "'\K[^']+(?=')")
        DURATION=$(echo "$line" | grep -oP '\d+\.\d+(?=s)')
        
        # Update high and low durations
        if [ -z "${event_high[$EVENT_NAME]}" ] || (( $(echo "$DURATION > ${event_high[$EVENT_NAME]}" | bc -l) )); then
            event_high[$EVENT_NAME]=$DURATION
        fi
        if [ -z "${event_low[$EVENT_NAME]}" ] || (( $(echo "$DURATION < ${event_low[$EVENT_NAME]}" | bc -l) )); then
            event_low[$EVENT_NAME]=$DURATION
        fi

        # Use DATETIME as the identifier instead of a Unix timestamp
        UNIQUE_ID="$DATETIME"

        # Count the events
        ((event_count["$EVENT_NAME"]++))

        # Append to CSV
        echo "$UNIQUE_ID,$EVENT_NAME,$DURATION,${event_count["$EVENT_NAME"]}" >> "$OUTPUT_FILE"
    fi
done < "$LOG_FILE"

# Sort and get top requested events based on the selected criteria
TOP_EVENTS=($(tail -n +2 "$OUTPUT_FILE" | sort -t ',' $SORT_CRITERIA | head -n "$NUM_REQUESTS"))

if [[ $TOP_EVENTS == "" ]]; then
    echo "Error: Could not get top events, file could be empty or internal error/bug" >&2;
    exit 1    
fi

# Print in a pretty table
echo "==================================================================================================="
echo "== Cron Shim Report ${VERSION} - Log File: $LOG_FILE - $NUM_REQUESTS most requested events sorted by $SORT_BY =="
echo "==================================================================================================="
OUTPUT+="UniqueID,EventName,Seconds,Count,CHigh,CLow\n"
# Cycle through the top events

for EVENT in "${TOP_EVENTS[@]}"; do    
    # Extract the event name
    EVENT_NAME=$(echo "$EVENT" | cut -d ',' -f 2)
    # Extract the high duration
    EVENT_HIGH=$(echo "${event_high[$EVENT_NAME]}")
    # Extract the low duration
    EVENT_LOW=$(echo "${event_low[$EVENT_NAME]}")
    OUTPUT+="$EVENT,$EVENT_HIGH,$EVENT_LOW\n"
done
echo -e "$OUTPUT" | column -t -s ','

