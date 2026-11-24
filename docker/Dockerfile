FROM php:8.3-apache

RUN docker-php-ext-install mysqli

COPY app/ /var/www/html/
RUN chown -R www-data:www-data /var/www/html

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD curl -fs http://localhost/health.php > /dev/null || exit 1

EXPOSE 80
