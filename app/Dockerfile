FROM composer:2.8 AS builder

WORKDIR /build

COPY composer.json composer.lock* ./

RUN composer install \
    --no-dev \
    --no-interaction \
    --no-progress \
    --optimize-autoloader \
    --prefer-dist

COPY . .

FROM php:8.3-apache AS runtime

LABEL maintainer="owner_me" \
      description="Production PHP application" \
      version="1.0.0"

RUN docker-php-ext-install opcache \
    && a2enmod rewrite headers

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

COPY <<'EOF' /usr/local/etc/php/conf.d/99-production.ini
; Performance
opcache.enable=1
opcache.memory_consumption=128
opcache.max_accelerated_files=10000
opcache.validate_timestamps=0

; Security
expose_php=Off
display_errors=Off
log_errors=On
error_log=/dev/stderr

; Limits
memory_limit=128M
max_execution_time=30
post_max_size=10M
upload_max_filesize=10M
EOF

# Configure Apache to listen on configurable PORT (default: 8080)
ENV PORT=8080
ENV APP_NAME=php-app
ENV APP_VERSION=1.0.0

# Apache configuration: listen on $PORT, log to stdout/stderr
RUN sed -i "s/Listen 80/Listen ${PORT}/" /etc/apache2/ports.conf \
    && echo "ServerName localhost" >> /etc/apache2/apache2.conf

COPY <<'EOF' /etc/apache2/sites-available/000-default.conf
<VirtualHost *:${PORT}>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html/public

    <Directory /var/www/html/public>
        AllowOverride All
        Require all granted

        FallbackResource /index.php
    </Directory>

    ErrorLog /dev/stderr
    CustomLog /dev/stdout combined
    LogLevel warn
</VirtualHost>
EOF

WORKDIR /var/www/html

COPY --from=builder /build/vendor ./vendor

COPY --from=builder /build/composer.json ./
COPY --from=builder /build/public ./public

# ownership
RUN chown -R www-data:www-data /var/www/html
USER www-data

EXPOSE ${PORT}

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:${PORT}/health || exit 1

# Run Apache in foreground (PID 1, logs to stdout/stderr)
CMD ["apache2-foreground"]
