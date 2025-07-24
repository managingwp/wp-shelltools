#!/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:/root/.local/bin
openlitespeed_status="$(/usr/local/lsws/bin/openlitespeed -t 2>&1)"
if [[ -n "$openlitespeed_status" ]]; then
  if [[ "$openlitespeed_status" == *"/usr/local/lsws/conf/vhosts"* ]]; then
    /bin/echo "OpenLiteSpeed Syntax Test failed - problems with a site's vhconf"
  else
    /bin/echo "OpenLiteSpeed Syntax Test failed - problems with httpd_config.conf"
  fi
  echo "------------------------------------------"
  echo "$openlitespeed_status"
  echo "------------------------------------------"
  exit 1
else
  /bin/echo "OpenLiteSpeed configuration file syntax tests successful!"
fi