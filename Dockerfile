FROM php:8.3-fpm

# Install system dependencies
RUN apt-get update && apt-get install -y \
    nginx \
    curl \
    zip \
    unzip \
    git \
    supervisor \
    libicu-dev \
    libzip-dev \
    && docker-php-ext-install \
        pdo \
        pdo_mysql \
        zip \
        intl \
        opcache \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Composer
COPY --from=composer:2.7 /usr/bin/composer /usr/bin/composer

# Copy configuration files
COPY docker/php/cachet.ini /usr/local/etc/php/conf.d/cachet.ini
COPY docker/nginx/nginx.conf /etc/nginx/nginx.conf
COPY docker/supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY docker/entrypoint.sh /entrypoint.sh

# Set working directory
WORKDIR /var/www/html

# Copy application code
COPY . .

# Install PHP dependencies including Redis client
RUN COMPOSER_ALLOW_SUPERUSER=1 composer require predis/predis --no-scripts \
    && composer install --no-dev --optimize-autoloader --no-scripts

# Set permissions
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 storage bootstrap/cache \
    && chmod +x artisan /entrypoint.sh

# Create necessary directories and set permissions
RUN mkdir -p /var/www/html/storage/framework/cache \
    && mkdir -p /var/www/html/storage/framework/sessions \
    && mkdir -p /var/www/html/storage/framework/views \
    && chown -R www-data:www-data /var/www/html/storage

# Build Cachet
RUN php artisan vendor:publish --tag=cachet

# Gen self-signed SSL certificate
RUN openssl req -subj '/CN=example.com/O=My Company Name LTD./C=US' -new -newkey rsa:2048 -days 365 -nodes -x509 -keyout /etc/ssl/private/ssl-cert-snakeoil.key -out /etc/ssl/certs/ssl-cert-snakeoil.pem

EXPOSE 80

CMD ["/entrypoint.sh"]