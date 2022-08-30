#!/bin/bash
echo "Checking for an attack"
if [[ -d /var/log/ols ]]; then
    echo "Found OLS logs at /var/log/ols"
    LOGS=($(ls /var/log/ols/*.access.log))
    for SITE in "${LOGS[@]}"; do
        echo "** Parsing $SITE for top 10 requests"
        cat ${SITE} | awk {' print $7 '} | sort | uniq -c | sort -nr | head -n 10
        echo "======================"
    done
else
    echo "Can't find site logs"
fi
