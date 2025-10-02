# APACHE
# Pull the php apache image.
FROM php:7.4-apache

# Install libraries and PHP extensions
RUN apt-get update && \
    apt-get install -y \
        libssl-dev \
        default-mysql-client \
    && docker-php-ext-install pdo_mysql \
    && rm -rf /var/lib/apt/lists/*

# Copy in SSL certificates
COPY ./docker-apache/web/private/certs/apache-server.key /etc/ssl/private/apache.key
COPY ./docker-apache/web/private/certs/apache-server.crt /etc/ssl/certs/apache.crt
COPY ./docker-apache/web/private/certs/SSL-root.crt /etc/ssl/certs/SSL-root.crt

# Apache config
COPY ./docker-apache/web/private/web-config/site.conf /etc/apache2/sites-available/site.conf

# Enable SSL and site
RUN a2enmod ssl headers rewrite \
    && a2dissite 000-default default-ssl \
    && a2ensite site