## cron-shim.sh
A shim between linux cron and WordPress.

## Description
This script is a shim between linux cron and WordPress, providing logging and monitor using health checks.

## Installation and Usage
### Guide
I've created a guide on how to use this script on my blog: [https://managingwp.io/2021/08/27/replacing-wordpress-wp-cron-with-manual-cron-url-and-php-method/](https://managingwp.io/2021/08/27/replacing-wordpress-wp-cron-with-manual-cron-url-and-php-method/)
### Quick Start
1. Copy the script to your server.
```
wget -O cron-shim.sh https://github.com/managingwp/wp-shelltools/raw/refs/heads/main/cron-shim/cron-shim.sh
```
2. Make the script executable.
```
chmod +x cron-shim.sh
```
3. Run the script.
```
./cron-shim.sh
```
4. Add to Cron
```
* * * * * /path/to/cron-shim.sh
```

## Configuration (Cron-shim.conf)
The script can be configured to with the following options, either by editing the script or passing in via environment variables or creating cron-shim.conf in the same directory as the script.

### wp-cli Detection
The script includes enhanced wp-cli detection that automatically searches for wp-cli in common installation paths if it's not found at the configured location. This only applies when `WP_CLI` is not explicitly set in the configuration file.

**Search paths include:**
- `/usr/bin/wp`
- `/usr/local/bin/wp` 
- `/opt/wp-cli/wp`
- `$HOME/.composer/vendor/bin/wp`
- `/usr/share/wp-cli/wp`

**Note:** If you explicitly set `WP_CLI` in your `cron-shim.conf` file, the script will only use that path and will not search alternatives.

### Main Options
| Option | Description | Default |
| --- | --- | --- |
| `WP_CLI` | Location of wp-cli. If not found, script will search common paths like /usr/bin/wp, /usr/local/bin/wp, etc. | `/usr/local/bin/wp` |
| `PHP_BIN` | Location of PHP binary | `/usr/bin/php` |
| `WP_ROOT` | Path to WordPress, blank will try common directories. | `""` |
| `CRON_CMD_SETTINGS` | Command to run | `$WP_CLI cron event run --due-now` |
| `HEARTBEAT_URL` | Heartbeat monitoring URL, example https://uptime.betterstack.com/api/v1/heartbeat/23v123v123c12312 leave blank to disable or pass in via environment variable | `""` |
| `POST_CRON_CMD` | Command to run after cron completes | `""` |
| `MONITOR_RUN` | Monitor the script run and kill after MONITOR_RUN_TIMEOUT | `0` |
| `MONITOR_RUN_TIMEOUT` | Time in seconds to consider script is stuck. | `300` |

### Logging Options
| Option | Description | Default |
| --- | --- | --- |
| `LOG_TO_STDOUT` | Log to stdout? 0 = no, 1 = yes | `1` |
| `LOG_TO_SYSLOG` | Log to syslog? 0 = no, 1 = yes | `1` |
| `LOG_TO_FILE` | Log to file? 0 = no, 1 = yes | `0` |
| `LOG_FILE` | Location for WordPress cron log file if LOG_TO_FILE="1", if left blank then cron-shim.log | `$SCRIPT_DIR/cron-shim.log` |

### wp-cli opcache options
| Option | Description | Default |
| --- | --- | --- |
| `WP_CLI_OPCACHE` | Enable opcache for wp-cli? 0 = no, 1 = yes | `0` |
| `WP_CLI_OPCACHE_DIR` | Directory to store opcache files | `$SCRIPT_DIR/.opcache` |

## Example Configuration
```
WP_CLI="/usr/local/bin/wp" 
CRON_CMD_SETTINGS="$WP_CLI cron event run --due-now" 
HEARTBEAT_URL="https://uptime.betterstack.com/api/v1/heartbeat/23v123v123c12312"

LOG_TO_STDOUT="1"
LOG_TO_SYSLOG="1"
```

# Donate
If you like any of the scripts or tools, please consider donating to help support the development of these tools.

[![Buy Me A Coffee](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://ko-fi.com/jordantrask)
[![ManagingWP](https://i.imgur.com/x5SjITX.png)](https://managingwp.io/sponsor)


# Changelog

## 1.4.2
* (cron-shim) Added support for checking server load average before running cron jobs.
* (cron-shim) Introduced `CHECK_LOAD_AVERAGE` and `MAX_LOAD_AVERAGE` configuration options to control load average checks.
* (cron-shim) Added `SCRIPT_ENABLED` configuration option to enable or disable script execution.

## 1.4.1
* (cron-shim) Added support to set LOG_PRUNE_SIZE_MB in configuration file to control log file size.

## 1.4.0
* (cron-shim) Enhanced wp-cli detection to automatically search common installation paths when wp-cli is not found at the configured location.
* (cron-shim) Only searches alternative paths if WP_CLI wasn't explicitly set via configuration file.
* (cron-shim) Improved error messages for wp-cli detection failures.

## 1.3.9
* fix(cron-shim): Fixed issue with wp-cli using opcache and double php binaries.
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
