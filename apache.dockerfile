# APACHE
# Pull the php apache image.
FROM php:7.4-apache

# Update and upgrade the container.
RUN apt-get -y update && \
    apt-get -y upgrade && \
    rm -rf /var/lib/apt/lists/*

# Install dependencies for php.
RUN docker-php-ext-install pdo pdo_mysql

# Copy in the SSL certificates.
COPY ./docker-apache/web/private/certs/apache-server.key /etc/ssl/private/apache.key
COPY ./docker-apache/web/private/certs/apache-server.crt /etc/ssl/certs/apache.crt
COPY ./docker-apache/web/private/certs/SSL-root.crt /etc/ssl/certs/SSL-root.crt

# Copy in the site configuration.
COPY ./docker-apache/web/private/web-config/site.conf /etc/apache2/sites-available/site.conf

# Enable the site and SSL.
RUN a2enmod ssl && \
    a2enmod headers && \
    a2enmod rewrite && \
    a2dissite 000-default default-ssl && \
    a2ensite site