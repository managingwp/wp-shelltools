#!/bin/bash
#
# USE FOR LOCAL DEVELOPMENT ONLY!!!
#
EMAIL='your-email@gmail.com'
MYSQL=`which mysql`

echo -n "DB user/name for project (lowercase) [ENTER]:"
read DB

if [ -z "$DB" ]; then
  echo "User must define a DB Name for your project."
  exit;
fi

echo -n "Local URL eg. local.test.com [ENTER]:"
read URL

if [ -z "$URL" ]; then
  echo "You must enter a valid url."
  exit;
fi

#
# Start WP Installation
#

random-string() {
  LENGTH=$1
  if [ -z "$LENGTH" ]; then
    LENGTH='20'
  fi

  cat /dev/urandom | env LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w $LENGTH | head -n 1
}

# Generate random password (mac friendly)
PASS=`random-string 20`

PREFIX=''
# No prefix? Then just comment out the line below
PREFIX="--dbprefix=`random-string 6`_"

Q1="CREATE DATABASE IF NOT EXISTS $DB;"
Q2="GRANT ALL ON $DB.* TO '$DB'@'localhost' IDENTIFIED BY '$PASS';"
Q3="FLUSH PRIVILEGES;"
SQL="${Q1}${Q2}${Q3}"

# Set up a login path for creating your dbs and users (must have global privileges)
# mysql_config_editor set --login-path=local --host=localhost --user=username --password
$MYSQL --login-path=local -e "$SQL"
echo "MYSQL user/db '$DB' created."

# Install latest WP
wp core download
wp core config --dbname="$DB" --dbuser="$DB" --dbpass="$PASS" $PREFIX
wp core install --url="$URL" --title='New WP Build' --admin_user='jason' --admin_password='local' --admin_email="$EMAIL" --skip-email

# Install but leave inactive

# Remove old default themes
wp theme delete twentyfifteen
wp theme delete twentythirteen
wp theme delete twentyfourteen

# Remove default posts, widgets, comments etc.
wp site empty --yes

# Move the config a directory above
mv wp-config.php ../

# Make uploads writable
chmod -R 777 wp-content/uploads

# Making a dumping folder
mkdir etc#