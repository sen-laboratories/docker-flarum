#!/usr/bin/with-contenv bash
# shellcheck shell=bash

mkdir -p /etc/services.d/nginx
cat > /etc/services.d/nginx/run <<EOL
#!/usr/bin/execlineb -P
s6-setuidgid ${PUID}:${PGID}
nginx -g "daemon off;"
EOL
chmod +x /etc/services.d/nginx/run

mkdir -p /etc/services.d/php-fpm
cat > /etc/services.d/php-fpm/run <<EOL
#!/usr/bin/execlineb -P
s6-setuidgid ${PUID}:${PGID}
php-fpm85 -F
EOL
chmod +x /etc/services.d/php-fpm/run

if [ "${FLARUM_REALTIME:-false}" = "true" ]; then
  mkdir -p /etc/services.d/realtime
  cat > /etc/services.d/realtime/run <<EOL
#!/usr/bin/execlineb -P
s6-setuidgid ${PUID}:${PGID}
/usr/local/bin/flarum-realtime
EOL
  chmod +x /etc/services.d/realtime/run
fi
