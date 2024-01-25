FROM ubuntu:16.04

RUN apt update
RUN apt -y dist-upgrade
RUN apt install -y git curl build-essential libcurl4-openssl-dev libdb5.3-dev libdb5.3++-dev php-memcached php7.0-mysqlnd php7.0-curl php7.0-json php7.0-curl libapache2-mod-php7.0 php-mbstring php-dom mysql-client w3m

WORKDIR /var/www

RUN git clone https://github.com/MPOS/php-mpos.git mpos

WORKDIR /var/www/mpos

RUN git checkout master
RUN chown -R www-data templates/compile templates/cache logs
RUN php composer.phar install
RUN echo '\
<VirtualHost *:80>\n\
    ServerName localhost\n\
    DocumentRoot /var/www/mpos/public\n\n\
    <Directory /var/www/mpos/public>\n\
        Options Indexes FollowSymLinks\n\
        AllowOverride All\n\
        Require all granted\n\
    </Directory>\n\n\
    ErrorLog ${APACHE_LOG_DIR}/mpos_error.log\n\
    CustomLog ${APACHE_LOG_DIR}/mpos_access.log combined\n\
</VirtualHost>' \
    > /etc/apache2/sites-available/mpos.conf
RUN a2dissite 000-default.conf && a2ensite mpos.conf

COPY migrate.sh /var/www/mpos

RUN chmod +x /var/www/mpos/migrate.sh

WORKDIR /var/www/mpos

RUN ./migrate.sh

# CMD apachectl -D FOREGROUND