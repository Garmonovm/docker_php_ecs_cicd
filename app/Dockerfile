# ============================================================================
# Multi-stage Dockerfile for PHP Application
# Stage 1: Build — install Composer dependencies
# Stage 2: Runtime — Alpine-based production image with PHP + Apache
#
# Switched from php:8.3-apache (Debian Bookworm) to php:8.3-alpine + Apache2
# to drastically reduce the OS-level vulnerability surface (50+ → ~0-3).
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
# Stage 2: Runtime — Alpine-based minimal production image
# ---------------------------------------------------------------------------
FROM php:8.3-alpine AS runtime

# Metadata
LABEL maintainer="owner_me" \
      description="Production PHP application" \
      version="1.0.0"

RUN apk add --no-cache \
        apache2 \
        apache2-mod-php83 \
        curl \
    && docker-php-ext-install opcache \
    && ln -sf /usr/lib/apache2/mod_php83.so /usr/lib/apache2/mod_php.so

# Enable required Apache modules
RUN sed -i \
        -e 's/#LoadModule rewrite_module/LoadModule rewrite_module/' \
        -e 's/#LoadModule headers_module/LoadModule headers_module/' \
        /etc/apache2/httpd.conf

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

# Environment
ENV PORT=8080
ENV APP_NAME=php-app
ENV APP_VERSION=1.0.0

# Configure Apache: listen on $PORT, set ServerName to suppress warnings
RUN sed -i \
        -e "s/^Listen 80$/Listen ${PORT}/" \
        -e "s/^#ServerName.*/ServerName localhost/" \
        /etc/apache2/httpd.conf

# Apache VirtualHost — mirrors original config, adapted for Alpine httpd.conf style
COPY <<'EOF' /etc/apache2/conf.d/app.conf
Listen ${PORT}

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

# Set working directory
WORKDIR /var/www/html

# Copy vendor (dependencies) from builder stage
COPY --from=builder /build/vendor ./vendor

# Copy application source
COPY --from=builder /build/composer.json ./
COPY --from=builder /build/public ./public

# Ensure correct ownership for www-data (Alpine uses different UID — create if needed)
RUN adduser -u 82 -D -S -G www-data www-data 2>/dev/null || true \
    && chown -R www-data:www-data /var/www/html \
    && chown -R www-data:www-data /var/log/apache2 \
    && chown -R www-data:www-data /run/apache2

# Security: run as non-root
USER www-data

# Expose the configurable port
EXPOSE ${PORT}

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:${PORT}/health || exit 1

# Run Apache in foreground
CMD ["httpd", "-D", "FOREGROUND"]