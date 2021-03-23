# gpplugin.sh
The following plugin will allow you accomplish two tasks
* List all plugins for all sites.
* List the status of a specific plugin.

# Donate
Coffee, Beer or steaped Tea! Feel free to buy me one :0

<a href="https://wpinfo.net/sponsor/" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/default-orange.png" alt="Buy Me A Coffee" height="41" width="174"></a>

# Install
You can refer to [README.md](README.md) to install all the tools.

or

Run the following!

```
wget https://raw.githubusercontent.com/jordantrizz/gpcli/main/gpplugin.sh
```

# Usage
You can run the following command to see the help screen.
```
./gpplugin.sh
```

You'll be presented with the following

```
❯ ./gpplugin.sh
Lists WordPress plugins on all websites on a GridPane Server

Syntax: gpplugin -a <plugin>
  options
  -a    List all plugins
  -p    Status on specific plugin

Notes:
        * Find out which sites have which plugins + search for specific plugins and print wp-cli plugin status
        * Excludes canary + staging + 22222 + nginx + *.gridpanevps.com sites
        * --skip-plugins is run as to not fail potentially due to an error with a plugin

Updates: https://github.com/jordantrizz/gpcli
```

## List all Plugins
If you want to list all plugins simply run the following.

```
gpplugin.sh -a
```
## Statis on Specific Plugin
If you want the status on a specific plugin!
```
gpplugin.sh -p elementor
```