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
COPY Apache/security/certs/Overseer.key /etc/ssl/private/overseer.key
COPY Apache/security/certs/Overseer.crt /etc/ssl/certs/overseer.crt
COPY Apache/security/certs/OS_root.crt  /etc/ssl/certs/OS_root.crt

# Copy in the frontends configuration.
COPY Apache/web/private/config/Overseer.conf /etc/apache2/sites-available/overseer.conf

# Enable the site and SSL.
RUN a2enmod ssl && \
    a2enmod headers && \
    a2enmod rewrite && \
    a2dissite 000-default default-ssl && \
    a2ensite overseer