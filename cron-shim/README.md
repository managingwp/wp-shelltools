# Donate
If you like any of the scripts or tools, please consider donating to help support the development of these tools.

[![Buy Me A Coffee](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://ko-fi.com/jordantrask)
[![ManagingWP](https://i.imgur.com/x5SjITX.png)](https://managingwp.io/sponsor)

# cron-shim.sh
A shim between linux cron and WordPress.

## Description
This script is a shim between linux cron and WordPress, providing logging and monitor using health checks.

## Installation and Usage
### Guide
I've created a guide on how to use this script on my blog: [https://managingwp.io/2021/08/27/replacing-wordpress-wp-cron-with-manual-cron-url-and-php-method/](https://managingwp.io/2021/08/27/replacing-wordpress-wp-cron-with-manual-cron-url-and-php-method/)
### Quick Start
1. Copy the script to your server.
2. Add to Cron
```
* * * * * /path/to/cron-shim.sh
```

## Configuration (Cron-shim.conf)
The script can be configured to with the following options, either by editing the script or passing in via environment variables or creating cron-shim.conf in the same directory as the script.

```
WP_CLI="/usr/local/bin/wp" # - Location of wp-cli
WP_ROOT="" # - Path to WordPress, blank will try common directories.
CRON_CMD_SETTINGS="$WP_CLI cron event run --due-now" # - Command to run
HEARTBEAT_URL="" # - Heartbeat monitoring URL, example https://uptime.betterstack.com/api/v1/heartbeat/23v123v123c12312 leave blank to disable or pass in via environment variable
POST_CRON_CMD="" # - Command to run after cron completes
MONITOR_RUN="0" # - Monitor the script run and don't execute again if existing PID exists or process is still running.
MONITOR_RUN_TIMEOUT="300" # - Time in seconds to consider script is stuck.

LOG_TO_STDOUT="1" # - Log to stdout? 0 = no, 1 = yes
LOG_TO_SYSLOG="1" # - Log to syslog? 0 = no, 1 = yes
LOG_TO_FILE="0" # - Log to file? 0 = no, 1 = yes
LOG_FILE="cron-shim.log" # Location for WordPress cron log file if LOG_TO_FILE="1", if left blank then cron-shim.log"
```

# Changelog
## 1.2.1
* Added human readable time to log output at end of run.
* Added log pruning to keep log files below 10MB

## 1.2.0
* Implemented multisite detection and running of cron for all sites.
* Implemented queue for running cronjobs to support multisite.
* Implemented tracking queue runs for each site in a multisite.
* Improved logging of cron jobs to include errors and separation of errors and output.
* Show execution time per site on multisite.

## 1.1.0
* Improved detection of WordPress root directory.
* Created _log function and revamped logging to occur in realtime.
* Improved checking of WordPress root has a WordPress install in it.
* Improved fetching of WordPress domain.
