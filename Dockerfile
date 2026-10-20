# syntax=docker/dockerfile:1

ARG FLARUM_VERSION=v2.0.2
ARG ALPINE_VERSION=3.24

FROM crazymax/yasu:latest AS yasu
FROM crazymax/alpine-s6:${ALPINE_VERSION}-2.2.0.3

COPY --from=yasu / /
RUN apk --update --no-cache add \
    bash \
    curl \
    git \
    libgd \
    mysql-client \
    mariadb-connector-c \
    nginx \
    openssh-client \
    php85 \
    php85-cli \
    php85-ctype \
    php85-curl \
    php85-dom \
    php85-exif \
    php85-fileinfo \
    php85-fpm \
    php85-gd \
    php85-gmp \
    php85-iconv \
    php85-intl \
    php85-mbstring \
    php85-openssl \
    php85-pdo \
    php85-pdo_mysql \
    php85-pecl-uuid \
    php85-phar \
    php85-session \
    php85-simplexml \
    php85-sodium \
    php85-tokenizer \
    php85-xml \
    php85-xmlwriter \
    php85-zip \
    php85-zlib \
    shadow \
    tar \
    tzdata \
  # Symlink php85 → php so composer and flarum CLI work without path games
  && ln -sf /usr/bin/php85 /usr/bin/php \
  && rm -rf /tmp/* /var/www/*

ENV S6_BEHAVIOUR_IF_STAGE2_FAILS="2"\
  TZ="UTC" \
  PUID="1000" \
  PGID="1000"

ARG FLARUM_VERSION
RUN mkdir -p /opt/flarum \
  && curl -sSL https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer \
  && COMPOSER_CACHE_DIR="/tmp" composer create-project flarum/flarum /opt/flarum \
       --stability=beta --no-install \
  # the 2.0 skeleton is minimum-stability stable, but fof/links and fof/gamification only have rc/beta releases for 2.0
  && COMPOSER_CACHE_DIR="/tmp" composer config --working-dir /opt/flarum minimum-stability beta \
  && COMPOSER_CACHE_DIR="/tmp" composer config --working-dir /opt/flarum prefer-stable true \
  # 2. add SEN Labs repository for the Authelia plugin
  && COMPOSER_CACHE_DIR="/tmp" composer config --working-dir /opt/flarum repositories.sen-labs \
     vcs https://codeberg.org/senlabs/flarum-oauth-authelia.git \
  && COMPOSER_CACHE_DIR="/tmp" composer require --working-dir /opt/flarum \
       --no-interaction --prefer-dist \
     flarum/core:${FLARUM_VERSION} \
     fof/oauth:"*" \
     sen-labs/oauth-authelia:"*" \
     fof/follow-tags:"*" \
     fof/links:"*" \
     fof/gamification:"*" \
     -W \
  ## check our extension so it does not break the container
  && find /opt/flarum/vendor/sen-labs/ -name '*.php' -exec php -l {} + \
  && composer clear-cache \
  && addgroup -g ${PGID} flarum \
  && adduser -D -h /opt/flarum -u ${PUID} -G flarum -s /bin/sh -D flarum \
  && chown -R flarum:flarum /opt/flarum \
  && rm -rf /root/.composer /tmp/*

COPY rootfs /

EXPOSE 8000
WORKDIR /opt/flarum
VOLUME [ "/data" ]

ENTRYPOINT [ "/init" ]
