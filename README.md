# gp-tools
The goal of this project is to make it easy to manage and maintain GridPane servers.

# Resources
* [Managing WP](https://mangingwp.io) - WordPress Articles and more!
* [Managing WordPress](https://www.facebook.com/groups/managingwordpress) - Created and managed by me.
* * [Managing WordPress Discord](https://discord.gg/QCsHM234zh) - Come and chat about WordPress
* [GridPane Facebook Group](https://www.facebook.com/groups/selfmanagedwordpress) - Managed by GridPane and full of customers and WordPress community members.

# Donate
Stepped Tea, ocasional Coffee, Beer, Scotch, Chicken Wings help me through the day, so feel free to buy me one :0

<a href="https://wpinfo.net/sponsor/" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/default-orange.png" alt="Buy Me A Coffee" height="41" width="174"></a>

# Install
## Requirements
* You need root, otherwise this makes no sense.
* You need git (apt-get install git)

It's simple, make sure you have git installed (apt-get install git) and then run the following
```
git clone https://github.com/jordantrizz/gpcli.git ~/gpcli;~/gpcli/gpcli -c install

```

# Tools
Below are the tools and their respective README's.

## [gpgoaccess](gpgoaccess.md)
* Provides the appropriate commands to run goaccess on GridPane Nginx log files.
## [gpapi](gpapi.md)
* Wrapper to the GP API.
<<<<<<< HEAD
## [gpplugin](gpplugin.md)
* Traverses all sites on a server (excluding system sites) and lists plugins or gets status on a single plugin

=======
## [gpbksite](gpbksite.md)
* A script to backup your gp websites, WIP.

# Debugging
Add a .debug file to any directory to get debug information.

# Future Features
* Check Log Sizes - debug.log is a culprit in disk usage. Find all occurances and print out size.
* MySQL Database Checks - Check for anomiles, myisam, large table sizes, large databases. 
* MySQL Database Report - Largest Databases + more.
* CLI to API - A CLI to the GridPane API.
