FROM ubuntu:16.04
MAINTAINER Afterster

#RUN echo 'deb http://download.videolan.org/pub/debian/stable/ /' >> /etc/apt/sources.list
#RUN echo 'deb-src http://download.videolan.org/pub/debian/stable/ /' >> /etc/apt/sources.list
#RUN echo 'deb http://archive.ubuntu.com/ubuntu trusty main multiverse' >> /etc/apt/sources.list

RUN apt-get update
RUN apt-get -y upgrade
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install wget inotify-tools
#RUN wget -O - https://download.videolan.org/pub/debian/videolan-apt.asc|sudo apt-key add -
#RUN apt-get update

# Need this environment variable otherwise mysql will prompt for passwords
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install mysql-server apache2 wget php php-json php-curl php-mysqlnd pwgen lame libvorbis-dev vorbis-tools flac libmp3lame-dev libavcodec-extra* libfaac-dev libtheora-dev libvpx-dev libav-tools git libapache2-mod-php php-xml php-gd

# Install composer for dependency management
RUN php -r "readfile('https://getcomposer.org/installer');" | php && \
    mv composer.phar /usr/local/bin/composer

# For local testing / faster builds
# COPY master.tar.gz /opt/master.tar.gz
ADD https://github.com/ampache/ampache/archive/master.tar.gz /opt/ampache-master.tar.gz
ADD ampache.cfg.php.dist /var/temp/ampache.cfg.php.dist

# extraction / installation
RUN rm -rf /var/www/html/* && \
    tar -C /var/www/html -xf /opt/ampache-master.tar.gz ampache-master --strip=1 && \
    cd /var/www/html && composer install --prefer-source --no-interaction && \
    chown -R www-data /var/www/html

RUN apt-get -y install cron socat

# setup mysql like this project does it: https://github.com/tutumcloud/tutum-docker-mysql
# Remove pre-installed database

RUN rm -rf /var/lib/mysql/*
ADD create_mysql_admin_user.sh /create_mysql_admin_user.sh
ADD run.sh /run.sh
RUN chmod 755 /*.sh
ENV MYSQL_PASS **Random**
# Add VOLUMEs to allow backup of config and databases
VOLUME  ["/etc/mysql", "/var/lib/mysql"]

# setup apache with default ampache vhost
ADD 001-ampache.conf /etc/apache2/sites-available/
RUN rm -rf /etc/apache2/sites-enabled/*
RUN ln -s /etc/apache2/sites-available/001-ampache.conf /etc/apache2/sites-enabled/
RUN a2enmod rewrite

# Add job to cron to clean the library every night
RUN echo '30 7    * * *   www-data php /var/www/html/bin/catalog_update.inc' >> /etc/crontab

VOLUME ["/media"]
VOLUME ["/var/www/html/config"]
VOLUME ["/var/www/html/themes"]
EXPOSE 80

CMD ["/run.sh"]
