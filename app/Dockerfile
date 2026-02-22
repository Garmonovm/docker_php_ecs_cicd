# ============================================================================
# Multi-stage Dockerfile for PHP Application
# Stage 1: Build — install Composer dependencies
# Stage 2: Runtime — lean production image with PHP + Apache
# ============================================================================

# ---------------------------------------------------------------------------
# Stage 1: Builder — install PHP dependencies via Composer
# ---------------------------------------------------------------------------
FROM composer:2.8 AS builder

WORKDIR /build

# Copy dependency manifest first (Docker layer caching)
COPY composer.json composer.lock* ./

# Install production dependencies only — no dev packages
RUN composer install \
    --no-dev \
    --no-interaction \
    --no-progress \
    --optimize-autoloader \
    --prefer-dist

# Copy application source code
COPY . .

# ---------------------------------------------------------------------------
# Stage 2: Runtime — minimal production image
# ---------------------------------------------------------------------------
FROM php:8.3-apache AS runtime

# Metadata
LABEL maintainer="owner_me" \
      description="Production PHP application" \
      version="1.0.0"

# Install only required runtime extensions (add more as needed)
RUN docker-php-ext-install opcache \
    && a2enmod rewrite headers

# Harden PHP for production
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# Custom PHP production settings
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
# ServerName localhost — suppresses AH00558 warning in logs.
RUN sed -i "s/Listen 80/Listen ${PORT}/" /etc/apache2/ports.conf \
    && echo "ServerName localhost" >> /etc/apache2/apache2.conf

COPY <<'EOF' /etc/apache2/sites-available/000-default.conf
<VirtualHost *:${PORT}>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html/public

    <Directory /var/www/html/public>
        AllowOverride All
        Require all granted

        # Route all requests through index.php (Slim framework)
        FallbackResource /index.php
    </Directory>

    # Log to stdout/stderr for container logging
    ErrorLog /dev/stderr
    CustomLog /dev/stdout combined
    LogLevel warn
</VirtualHost>
EOF

# Set working directory
WORKDIR /var/www/html

# Copy vendor (dependencies) from builder stage
COPY --from=builder /build/vendor ./vendor

# Copy application source
COPY --from=builder /build/composer.json ./
COPY --from=builder /build/public ./public

# Ensure correct ownership
RUN chown -R www-data:www-data /var/www/html

# Security: run as non-root (port 8080 doesn't require root)
USER www-data

# Expose the configurable port
EXPOSE ${PORT}

# Health check — used by Docker and ECS
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:${PORT}/health || exit 1

# Run Apache in foreground (PID 1, logs to stdout/stderr)
CMD ["apache2-foreground"]
