# attackschan.sh
```
attackscan.sh [-top <lines>|-scan]
Version: 0.0.3

Parses Nginx and OLS web server access logs to find top number of requests and common attack requests for WordPress.

Commands:
 -top         -List top number of requests from the webserver access log.
 -scan        -List common attack requests that return a 200 status code, by IP address.

Options:
 <lines>   -How many lines to show, if not specified defaults to 10

Examples
   attackscan.sh -top 20
   attackscan.sh -scan
```
# Commands
## -top <lines>
* List top number of requests from the webserver access log.
### Example -top Output
```
** Parsing /var/log/ols/domain.com.access.log for top 10 requests
    467 /wp-login.php
    353 /
     97 /xmlrpc.php
     93 /robots.txt
     78 //xmlrpc.php
     63 /robots.txt/
     32 /favicon.ico
     30 //wp-json/wp/v2/users/
     30 //wp-json/oembed/1.0/embed?url=https://workingefficiently.com/
     30 //?author=1
```
## -scan <lines>
* List common attack requests that return a 200 status code, by IP address.
### Example -scan Output
```
** Parsing /var/log/ols/domain.com.access.log for top common attack requests serving 200 status code
      9 //xmlrpc.php,143.198.225.22,200
      9 /wp-login.php,185.119.81.105,200
      8 //xmlrpc.php,20.168.90.200,200
      8 /wp-login.php,185.119.81.108,200
      6 //xmlrpc.php,20.168.90.200,503
      6 /wp-login.php,185.119.81.97,200
      6 /wp-login.php,185.119.81.102,200
      6 /wp-login.php,185.119.81.100,200
      4 //xmlrpc.php,79.110.62.40,200
      4 //xmlrpc.php,208.67.105.86,200
```
# Running attackscan.sh
* Log into your server via SSH
* Run one of the following commands
## Run one time via bash+curl
You can run attachscan.sh one time using the following shell command, it won't download anything to your server.
```
bash <(curl -sL https://raw.githubusercontent.com/managingwp/gp-tools/main/attackscan.sh)
```
You should see the help page output, now you can append a command to the end of the shell command.
```
bash <(curl -sL https://raw.githubusercontent.com/managingwp/gp-tools/main/attackscan.sh) -top
```
## Download and Run
If you want to keep a copy on your server.
```
cd /usr/local/sbin; wget "https://raw.githubusercontent.com/managingwp/gp-tools/main/attackscan.sh"; chmod u+x /usr/local/sbin/attackscan.sh
```
You can now simply type the following at anytime.
```
attackscan.sh
```

# FAQ
## Why would I use this script?
This should will help identify requests that could potentially be causing an increase in resource usage on your server. Or highlight potential common attacks that spike resource usage, effectively causing your server to be at capacity prematurely.
## Why did you create this script?
I required a quick way to see what were the top requests being served, and to confirm if common resource based attacks on WordPress were being carried out due to no preventative measures being in place.
## Do you support other platforms beside GridPane
Yes, simply create an issue with the platform and we'll look into support it.

# Documentation
## Parsing Method for -scan command
The parsing method for -scan is rather simple using grep. Here is the full command.
```
grep -v "redirect_to" | grep "200" | egrep -e "xmlrpc|wp-login"
```
As you can see "redirect_to" is parsed out because the request was answered and redirecting, versus a direct POST request to the wp-login page.
## Log File Formats
### GP OLS
* ```logFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-agent}i\"```
* ```"192.168.1.1 - - [01/Sep/2022:20:16:55 -0700] "GET /favicon.ico HTTP/1.1" 200 103639 "https://domain.com/" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/105.0.0.0 Safari/537.36"```
### GP Nginx
* ```'[$time_local] $remote_addr $upstream_response_time $upstream_cache_status $http_host "$request" $status $body_bytes_sent $request_time "$http_referer" "$http_user_agent" "$http3"';```
* ```[01/Sep/2022:20:20:07 -0700] 192.168.1.1 1.360 - domain.com "GET /favicon.ico HTTP/2.0" 302 0 1.362 "https://domain.com" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/105.0.0.0 Safari/537.36"```