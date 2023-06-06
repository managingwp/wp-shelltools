#!/bin/bash
#
# This one liner should work, you would need to replace your.site with your actual multisite primary domain:
#  sudo su - "$(/usr/local/bin/gp conf read sys-user -site.env "your.site" -q)" -c "/usr/local/bin/wp site list --field=url --path=/var/www/your.site/htdocs | xargs -i -n1 /usr/local/bin/wp cron event run --due-now --url={} --path=/var/www/your.site/htdocs"
#
# You would save that in some filepath and make it executable:
# chmod +x /path/to/your/multisite-cron-script.sh
# The script accepts two args,
# multisite-cron-script.sh {primary.domain:string} {seconds:integer}
# 
# Then create a cronjob in your cron tab, passing in your site domain and seconds to sleep.
# It defaults to 1 second if you omit the second arg. Here is an example to run every 5 minutes, with 5 seconds delay between subsites crons, and outputting to a log.
#
# 5 * * * * /path/to/your/multisite-cron-script.sh your.site 2 >>/var/log/multisite-cron.log

default_sleep=1
multi_site="$1"
sleep_for_seconds="${2:-$default_sleep}"
sys_user=$(/usr/local/bin/gp conf read sys-user -site.env "${multi_site}" -q)
for site in $(sudo su - "${sys_user}" -c "/usr/local/bin/wp site list --field=url --path=/var/www/${multi_site}/htdocs"); do
 sudo su - "${sys_user}" -c "/usr/local/bin/wp cron event run --due-now --url=${site} --path=/var/www/${multi_site}/htdocs"
 sleep ${sleep_for_seconds}
done
