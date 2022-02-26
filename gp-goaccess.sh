#/usr/bin/env bash
# Run gp-go-access <domain.com>
# Example gp-goaccess testing.com

# Variables
LOG_FORMAT='[%d:%t %^] %h %^ - %v \"%r\" %s %b \"%R\" \"%u\"\'
DATE_FORMAT='%d/%b/%Y\'
TIME_FORMAT='%H:%M:%S %Z\'


# -- Check args.
if [ -v $1 ]; then
	echo "usage: gp-goaccess <domain.com>"
	return
fi	

# Main
if [ $1 = "-a" ]; then
        zcat /var/log/nginx/$2.access.log.*.gz | goaccess --log-format="$LOG_FORMAT" --date-format="$DATE_FORMAT" --time-format="$TIME_FORMAT"
else
        cat /var/log/nginx/$1.access.log | goaccess --log-format="$LOG_FORMAT" --date-format="$DATE_FORMAT" --time-format="$TIME_FORMAT"
fi
