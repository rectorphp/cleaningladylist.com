# inspiration: https://github.com/rectorphp/getrector.org/blob/master/Dockerfile

####
## Base stage, to empower cache
####
FROM php:7.4-apache as base

WORKDIR /var/www/cleaningladylist.com

COPY ./.docker/apache/apache.conf /etc/apache2/sites-available/000-default.conf

# Install php extensions
RUN apt-get update && apt-get install -y \
        git \
        unzip \
        g++ \
        default-mysql-client \
        zlib1g-dev \
        libicu-dev \
        libzip-dev \
        libpng-dev \
        libjpeg-dev \
        sudo \
    && docker-php-ext-configure gd --with-jpeg \
    && docker-php-ext-configure opcache --enable-opcache \
    && docker-php-ext-install gd \
    && docker-php-ext-configure intl \
    && docker-php-ext-install intl \
    && docker-php-ext-install pdo_mysql \
    && docker-php-ext-install exif \
    && pecl -q install \
        zip \
    && docker-php-ext-enable zip opcache

# Install docker
RUN apt-get update && apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg2 \
        software-properties-common \
    && curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg > /tmp/dkey; apt-key add /tmp/dkey \
    && add-apt-repository \
        "deb [arch=amd64] https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
        $(lsb_release -cs) \
        stable" \
    && apt-get update && apt-get -y install \
        docker-ce-cli

# Installing composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

ENV PHP_OPCACHE_VALIDATE_TIMESTAMPS="0"
COPY ./.docker/php/opcache.ini /usr/local/etc/php/conf.d/opcache.ini

ENV COMPOSER_ALLOW_SUPERUSER=1 COMPOSER_MEMORY_LIMIT=-1

# Entrypoint
# standard location from parent image "php:7.4-apache as base": https://github.com/docker-library/php/blob/098e442542e8a10bdee2c22484a98d41583a8fb9/7.4/buster/apache/Dockerfile#L273
COPY ./.docker/docker-php-entrypoint /usr/local/bin/docker-php-entrypoint
# this is always run "docker run/docker-compose ..."
RUN chmod 777 /usr/local/bin/docker-php-entrypoint

# Allow www-data to run bin/run-demo.sh with sudo
COPY ./.docker/sudoers/www-data /etc/sudoers.d/www-data
RUN chmod 440 /etc/sudoers.d/www-data

####
## Build js+css assets
####
FROM node:10.15.3 as node-build

WORKDIR /build

COPY package.json yarn.* webpack.config.js ./
RUN yarn install

COPY ./assets ./assets

RUN yarn run build


####
## Build app itself
####
FROM base as production

COPY composer.json composer.lock phpunit.xml ./

RUN composer install --prefer-dist --no-dev --no-autoloader --no-scripts --no-progress --no-suggest \
    && composer clear-cache

COPY --from=node-build /build/public/build ./public/build

RUN mkdir -p ./var/cache ./var/log ./var/sessions

RUN composer dump-autoload -o --no-dev

RUN chown -R www-data ./var

COPY . .
