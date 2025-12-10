# cron-task-runner
A simple bash script that runs multiple cron tasks sequentially. Useful for running multiple cron tasks in a single cron job so they don't overlap.

# Installation
## 1. Download the script
```wget https://raw.githubusercontent.com/managingwp/wp-shelltools/main/cron-task-runner/cron-task-runner.sh -O /usr/local/bin/cron-task-runner```
## 2. Make it executable
```chmod +x /usr/local/bin/cron-task-runner```
## 3. Download config
```wget https://raw.githubusercontent.com/managingwp/wp-shelltools/main/cron-task-runner/cron-task-runner.conf -O /etc/cron-task-runner.conf```
## 4. Setup Crontab
Edit your crontab with `crontab -e` and add a line like the following to run the cron-task-runner every 5 minutes:

```
*/5 * * * * /usr/local/bin/cron-task-runner
```
## 5. Edit config
Edit `cron-task-runner.conf` file to configure the cron-task-runner.sh options and tasks to run.

# Configuration
See the `cron-task-runner.conf-example` file for configuration options and examples.