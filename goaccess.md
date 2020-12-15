# How to use goacecss with GridPane
## Log Format
* goaccess --log-format='[%d:%t %^] %h %^ - %v "%r" %s %b "%R" "%u"' --date-format=%d/%b/%Y --time-format=%H:%M:%S %Z

## Configuration
* Edit /etc/goaccess/goaccess.conf
* date-format %d/%b/%Y
* time-format %H:%M:%S %Z
* log-format [%d:%t %^] %h %^ - %v "%r" %s %b "%R" "%u"
