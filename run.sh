#!/bin/bash

VOLUME_HOME="/var/lib/mysql"

mkdir -p /var/run/mysqld
chown mysql:mysql /var/run/mysqld
rm /var/run/mysqld/mysqld.sock.lock

if [[ ! -d $VOLUME_HOME/mysql ]]; then
    echo "=> An empty or uninitialized MySQL volume is detected in $VOLUME_HOME"
    echo "=> Installing MySQL ..."
    mysqld --initialize-insecure > /dev/null 2>&1
    echo "=> Done!"
    /create_mysql_admin_user.sh
else
    echo "=> Using an existing volume of MySQL"
fi

if [[ ! -f /var/www/config/ampache.cfg.php ]]; then
    mv /var/temp/ampache.cfg.php.dist /var/www/config/ampache.cfg.php.dist
fi


cp /var/www/html/rest/.htaccess.dist /var/www/html/rest/.htaccess
cp /var/www/html/play/.htaccess.dist /var/www/html/play/.htaccess
cp /var/www/html/channel/.htaccess.dist /var/www/html/channel/.htaccess

# Start apache in the background
service apache2 start

# Start socat for redirecting the REST API streams
socat tcp-listen:1080,reuseaddr,fork tcp:localhost:80 &

# Start cron in the background
cron

# Start a process to watch for changes in the library with inotify
(
while true; do
    inotifywatch /mnt
    php /var/www/html/bin/catalog_update.inc -a
    sleep 30
done
) &

# run this in the foreground so Docker won't exit
exec mysqld_safe
