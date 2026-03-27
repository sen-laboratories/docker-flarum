# syntax=docker/dockerfile:1

ARG FLARUM_VERSION=v2.0.0-beta.8
ARG ALPINE_VERSION=3.22

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
    php84 \
    php84-cli \
    php84-ctype \
    php84-curl \
    php84-dom \
    php84-exif \
    php84-fileinfo \
    php84-fpm \
    php84-gd \
    php84-gmp \
    php84-iconv \
    php84-intl \
    php84-mbstring \
    php84-opcache \
    php84-openssl \
    php84-pdo \
    php84-pdo_mysql \
    php84-pecl-uuid \
    php84-phar \
    php84-session \
    php84-simplexml \
    php84-sodium \
    php84-tokenizer \
    php84-xml \
    php84-xmlwriter \
    php84-zip \
    php84-zlib \
    shadow \
    tar \
    tzdata \
  # Symlink php84 → php so composer and flarum CLI work without path games
  && ln -sf /usr/bin/php84 /usr/bin/php \
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
  # 2. add SEN Labs repository for the Authelia plugin
  && COMPOSER_CACHE_DIR="/tmp" composer config --working-dir /opt/flarum repositories.sen-labs \
     vcs https://github.com/sen-laboratories/flarum-oauth-authelia.git \
  && COMPOSER_CACHE_DIR="/tmp" composer require --working-dir /opt/flarum \
       --no-interaction --prefer-dist \
     flarum/core:${FLARUM_VERSION} \
     fof/oauth:"*" \
     sen-labs/oauth-authelia:"*" \
     fof/follow-tags:"*" \
     fof/links:"*" \
     fof/gamification:"*" \
     -W \
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
