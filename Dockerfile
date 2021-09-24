FROM ubuntu:18.04

RUN apt-get update \
  && apt-get install -y unixodbc firebird3.0-utils nginx php7.2-fpm supervisor openssh-client openssl ca-certificates \
  && apt-get autoremove -y \
  && apt-get clean \
  && apt-get autoclean

COPY config/nginx.conf /etc/nginx/nginx.conf
COPY config/fpm-pool.conf /etc/php/7.2/fpm/pool.d/www.conf
COPY config/php.ini /etc/php/7.2/fpm/conf.d/custom.ini
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY --chown=nobody:nogroup ssh/ /var/www/ssh/

RUN rm /etc/nginx/sites-available/default \
    && rm /etc/nginx/sites-enabled/default \
    && mkdir -p /var/www/html \
    && chown -R nobody:nogroup /var/www/html \
    && chown -R nobody:nogroup /run \
    && chown -R nobody:nogroup /var/lib/nginx \
    && chown -R nobody:nogroup /var/log/nginx \
    && mkdir -p /run/php \
    && chown -R nobody:nogroup /run/php

USER nobody

WORKDIR /var/www/html
COPY --chown=nobody:nogroup src/ /var/www/html/

EXPOSE 8080

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:8080/fpm-ping

