# delete-mu-plugins
Delete all mu-plugins from WordPress sites on a single server.
## Usage
```
./delete-mu-plugins.sh go
```

## Installation
```
cd $HOME
mkdir delete-mu-plugins
wget https://github.com/managingwp/wp-shelltools/blob/main/custom/delete-mu-plugins/delete-mu-plugins.sh
wget https://github.com/managingwp/wp-shelltools/blob/main/custom/delete-mu-plugins/delete-mu-plugins.conf
chmod u+x delete-mu-plugins.sh
```

## Configuration
The script will look for a file in the same directory called delete-mu-plugins.conf.

```
# -- Don't include trailing slashes in SOURCE_DIR or slashes at the beginning of FILES_FOLDERS_DELETE
SOURCE_DIR="/var/www"
BACKUP_DIR="/root/backup"
DOMAIN_LIST=('domain1.com' 'domain2.com' 'domain3.com')
#DOMAIN_LIST="test.com test1.com test2.com"
FILES_FOLDERS_DELETE=('htdocs/wp-content/mu-plugins/pluginfile.php' 'htdocs/wp-content/plugins/testplugin' 'htdocs/wp-content/mu-plugins/test.php')
DRYRUN=1
```