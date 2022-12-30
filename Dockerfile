# Latest Alpine Linux Image
FROM alpine:latest

# Set the maintainer
LABEL maintainer="Ahmed Nagi"

# Set the timezone
RUN echo "UTC" > /etc/timezone

# Set The default user and group for the container
ARG WWWGROUP=www-data

# Main working directory on the container
ENV APP_HOME=/var/www/html

# Set current working directory
WORKDIR $APP_HOME

# Install a variety of tools and libraries:
#
# bash: The Bash shell, a command-line interface for interacting with the operating system.
# nano: A text editor.
# sudo: A utility for running commands with superuser privileges.
# git: A version control system.
# openssh: An implementation of the Secure Shell (SSH) protocol.
# rsync: A utility for synchronizing files between systems.
# jq: A command-line JSON processor.
# zip: A utility for creating and manipulating zip archives.
# unzip: A utility for extracting files from zip archives.
# curl: A command-line tool for transferring data with URL syntax.
# sqlite: A lightweight database management system.
# nginx: A web server.
# supervisor: A process manager for running programs.
# shadow: A suite of utilities for managing user accounts and passwords.
# htop: A interactive process viewer.
# openssh-keygen: A utility for generating SSH keys.
# tar: A utility for creating and manipulating tar archives.
# libgcc: A library of common code that is used by other programs.
# libstdc++: The GNU Standard C++ library.
# libuv: A cross-platform library for asynchronous I/O.
# dos2unix: A utility for converting text files between DOS, UNIX, and Mac formats.
# wget: A utility for downloading files from the Internet.
# gnupg: A utility for managing cryptographic keys.
# gosu: A utility for running programs as another user.
# ca-certificates: A set of certificates for verifying the authenticity of SSL/TLS certificates.
# zip: A utility for creating and manipulating zip archives.
# unzip: A utility for extracting files from zip archives.
# sqlite3: A command-line interface for SQLite.
# dnsutils: A collection of utilities for querying DNS servers.
#
# "sed -i 's/bin\/ash/bin\/bash/g' /etc/passwd" is for
# Change the default shell for the user from ash to bash.

RUN apk update \
    && apk add --no-cache bash nano sudo wget git openssh rsync jq && sed -i 's/bin\/ash/bin\/bash/g' /etc/passwd \
    && apk add --no-cache zip unzip curl sqlite nginx supervisor shadow htop openssh-keygen tar libgcc libstdc++ libuv dos2unix gnupg gosu ca-certificates zip unzip sqlite3 dnsutils

# Wait tool is used to manage dependencies between services in a Docker Compose file.
# It allows you to specify that a service should only be started once other services
# have reached a certain state, ensuring that services are started in the correct
# order and are not prematurely terminated due to unmet dependencies.
ADD https://github.com/ufoscout/docker-compose-wait/releases/download/2.9.0/wait /wait
RUN chmod +x /wait


# Install PHP 8.2 because we are using the latest version of alpine
# php8.2 is only available in edge, alpine >= 3.18 repository.
# You can find the list of available repositories here: https://pkgs.alpinelinux.org/packages
# Insall older version of php by chaning the number 82 to 80 or 81
RUN apk add --no-cache php82 \
    php82-common \
    php82-fpm \
    php82-pdo \
    php82-opcache \
    php82-zip \
    php82-phar \
    php82-iconv \
    php82-cli \
    php82-curl \
    php82-openssl \
    php82-mbstring \
    php82-tokenizer \
    php82-fileinfo \
    php82-json \
    php82-intl \
    php82-xml \
    php82-xmlwriter \
    php82-simplexml \
    php82-dom \
    php82-pdo_mysql \
    php82-xmlreader \
    php82-bcmath \
    php82-pdo_sqlite \
    php82-sqlite3 \
    php82-sockets \
    php82-tokenizer \
    php82-sodium \
    php82-pcntl \
    php82-readline \
    php82-gd \
    php82-exif \
    php82-imap \
    php82-pecl-redis


# Install Node.js 18, NPM 9 and Yarn
# because we are using the latest version of alpine
# nodejs 18 is only available in edge, alpine >= 3.18 repository.
# You can find the list of available repositories here: https://pkgs.alpinelinux.org/packages
# Insall older version of nodejs by chaning the alpine version to 3.14 or 3.13
RUN apk add --no-cache nodejs npm yarn


# Install Composer
RUN curl -sS https://getcomposer.org/installer -o composer-setup.php \
    && php composer-setup.php --install-dir=/usr/local/bin --filename=composer \
    && rm -rf composer-setup.php

# Install cpu limit tool for limiting cpu usage of a process when needed
 RUN apk add cpulimit


# Install mysql client to use mysql commands in the container
# specially mysqldump command to backup the database from
# the container or to restore the database from a backup
# file to the other containers. It also can be used to
# Allow spatie/laravel-backup package to function.
 RUN apk add mysql-client --no-cache --allow-untrusted

# Clean up the apk cache to reduce the size of the image
RUN  rm -rf /var/cache/apk/*


# Create a user and group for the web server
RUN groupadd --force -g $WWWGROUP www-data
RUN useradd -ms /bin/bash --no-user-group -g $WWWGROUP -u 1337 www-data

# Set up and configure supervisor and cron services:
#
# Create the '/var/log/supervisor' directory if it does not exist
# Set the execute permission for the 'crontab' command for all users
# Set the permissions for the 'root' user's crontab file to 0600
RUN mkdir -p /var/log/supervisor \
&& chmod a+x /usr/bin/crontab \
&& chmod 0600 /var/spool/cron/crontabs/root

# Configure php-fpm socket and pid files to make sure that the php-fpm
# service can start, also to normalize the permissions and paths of
# the files dispite the version of php/php-fpm that is installed.
RUN mkdir -p /run/php/ \
    && touch /run/php/php8.2-fpm.pid \
    && touch /run/php/php8.2-fpm.sock \
    && chown www-data:www-data /run/php/php8.2-fpm.sock

# Copy the configuration files for the services to the container
COPY ./supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY ./cron /var/spool/cron/crontabs/root

# configure php-fpm and php.ini
# if you want to use a different version of php, change the number 82 to 80 or 81
COPY ./www.conf /etc/php82/php-fpm.d/www.conf
COPY ./php-fpm.conf /etc/php82/php-fpm.conf
COPY ./php.ini /etc/php82/php.ini

# configure nginx
COPY ./nginx.conf /etc/nginx/
COPY ./nginx-laravel.conf /etc/nginx/modules/

# Configure nginx socket and pid files to make sure that the nginx
# service can start, also direct the access and error logs to the
# standard output and error streams. To show on the docker logs.
RUN mkdir -p /run/nginx/ \
    && touch /run/nginx/nginx.pid
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

# create document root, fix permissions for www-data user and change owner to www-data
# Some santy checks to make sure that laravel can write to the storage directory
RUN mkdir -p $APP_HOME/public \
    && mkdir -p $APP_HOME/storage \
    && mkdir -p $APP_HOME/storage/framework \
    && mkdir -p $APP_HOME/storage/app \
    && mkdir -p $APP_HOME/storage/logs \
    && mkdir -p $APP_HOME/storage/backups \
    && mkdir -p $APP_HOME/storage/framework/sessions \
    && mkdir -p $APP_HOME/storage/framework/views \
    && mkdir -p $APP_HOME/storage/framework/cache \
    && mkdir -p $APP_HOME/storage/app \
    && mkdir -p $APP_HOME/storage/public \
    && mkdir -p $APP_HOME/storage/framework \
    && mkdir -p $APP_HOME/storage/logs \
    && mkdir -p $APP_HOME/storage/framework/cache \
    && mkdir -p $APP_HOME/storage/framework/sessions \
    && mkdir -p $APP_HOME/storage/framework/testing \
    && mkdir -p $APP_HOME/storage/framework/views \
    && mkdir -p $APP_HOME/storage/framework/cache/data \
    && mkdir -p $APP_HOME/bootstrap/cache \
    && touch $APP_HOME/storage/logs/laravel.log \
    && mkdir -p /home/www-data \
    && chown -R www-data:www-data /home/www-data \
    && chmod -R 777 $APP_HOME/storage \
    && chown -R www-data:www-data $APP_HOME

# Extra fix for eof error, when using windows line endings
RUN find $APP_HOME -type f -print0 | xargs -0 dos2unix --


# Alisases to make life easier
RUN echo 'alias wr="cd /var/www/html"' >> /root/.bashrc \
&& echo 'alias ll="ls -alF"' >> /root/.bashrc \
&& echo 'alias l="ls -alF"' >> /root/.bashrc \
&& echo 'alias c="composer"' >> /root/.bashrc \
&& echo 'alias art="php artisan"' >> /root/.bashrc \
&& echo 'alias a="php artisan"' >> /root/.bashrc

# Copy entrypoint script to the container and
# make it executable and change the line endings
COPY ./start-container /usr/local/bin/start-container
RUN dos2unix /usr/local/bin/start-container
RUN ["chmod", "+x", "/usr/local/bin/start-container"]

EXPOSE 80 443 6001

ENTRYPOINT ["wait", "start-container"]
