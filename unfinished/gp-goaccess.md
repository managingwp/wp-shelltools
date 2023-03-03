Welcome GridPane'rs!

<a href="https://www.buymeacoffee.com/jordantrask" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/default-orange.png" alt="Buy Me A Coffee" height="41" width="174"></a>

# How to use goacecss with GridPane
## Installation
```
echo "deb https://deb.goaccess.io/ $(lsb_release -cs) main" | sudo tee -a /etc/apt/sources.list.d/goaccess.list
wget -O - https://deb.goaccess.io/gnugpg.key | sudo apt-key --keyring /etc/apt/trusted.gpg.d/goaccess.gpg add -
sudo apt-get update
sudo apt-get install goaccess
```

## Log Format
```
goaccess --log-format='[%d:%t %^] %h %^ - %v "%r" %s %b "%R" "%u"' --date-format='%d/%b/%Y' --time-format='%H:%M:%S %Z'
```

## Configuration
If you don't want to use the command above, you can configure goaccess globally to use the abouve settings
* Edit /etc/goaccess/goaccess.conf and update the following lines.
```
date-format %d/%b/%Y
time-format %H:%M:%S %Z
log-format [%d:%t %^] %h %^ - %v "%r" %s %b "%R" "%u"
```
