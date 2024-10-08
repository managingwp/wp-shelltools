<!--ts-->
Table of Contents
=================

- [Table of Contents](#table-of-contents)
- [Donate](#donate)
- [wp-shelltools](#wp-shelltools)
- [Install](#install)
  - [Requirements](#requirements)
- [Help](#help)
- [Directories](#directories)
- [Advanced Documentation](#advanced-documentation)
- [Debugging](#debugging)
- [Future Features](#future-features)
- [ToDo](#todo)
- [Resources](#resources)
<!--te--> 

# Donate
If you like any of the scripts or tools, please consider donating to help support the development of these tools.

[![Buy Me A Coffee](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://ko-fi.com/jordantrask)
[![ManagingWP](https://i.imgur.com/x5SjITX.png)](https://managingwp.io/sponsor)


# wp-shelltools
The goal of this project is to make it easy to manage and maintain WordPress servers using shell scripting. This repository was original named gp-tools, but decided to make it provider agnostic

You might find that there are still tools and functions that have gridpane or gp in their name. This will change when it becomes a priority.

# Install
## Requirements
* You need root, otherwise this makes no sense.
* You need git (apt-get install git)

It's simple, make sure you have git installed (apt-get install git) and then run the following
```
git clone https://github.com/jordantrizz/gpcli.git ~/gpcli;~/gpcli/gpcli -c install

```

# Help
Simply run the following command to get a list of available tools
```
wp-shelltools help
```
Here's a list of all commands
```
-- Loading wp-shelltools - v0.0.1

wp-shelltools help
-----------------------------------
  help goaccess        - Process GridPane logs with goaccess
  help backups         - List backups for all sites on the server.
  help plugins         - Lists WordPress plugins on all websites on a GridPane Server
  help logcode         - Look for specifc HTTP codes in web server logfiles and return top hits.
  help gpcron          - List sites using GP Cron
  help mysqlmem        - GridPane monit memory calculation
  help logs            - tail or show last lines on all GridPane logs.

Examples:
 --
  wp-shelltools goaccess
  wp-shelltools log
```

# Directories
* dawn-mover - GridPane's prime-mover recoded but broken, it's a mess.
* docs - Advanced documentation.
* tests - any test data.
* unfinished - code that is untested or needs to be moved into core.

# Advanced Documentation
Below is help for the advanced tools.
* [wpst-goaccess](docs/wpst-goaccess.md)
* [gp-api](docs/gp-api.md)
* [gp-plugins](docs/gp-plugins.md)
* [attackscan.sh](docs/attackscan.md)
* [dawn-mover](dawn-mover/README.md)

# Debugging
Add a .debug file to any directory to get debug information.

# Future Features
* Check Log Sizes - debug.log is a culprit in disk usage. Find all occurances and print out size.
* MySQL Database Checks - Check for anomiles, myisam, large table sizes, large databases. 
* MySQL Database Report - Largest Databases + more.
* CLI to API - A CLI to the GridPane API.

# ToDo
* Go through unfinished directory code.
* Better documentation
* Place some scripts into functions or separate files not inside root for a cleaner directory structure and code management.
* goaccess: Add filtering for 403 forbidden as they're blocked and not resource intensive


# Resources
* [Managing WP](https://mangingwp.io) - WordPress Articles and more!
* [Managing WordPress](https://www.facebook.com/groups/managingwordpress) - Created and managed by me.
* [Managing WordPress Discord](https://discord.gg/QCsHM234zh) - Come and chat about WordPress