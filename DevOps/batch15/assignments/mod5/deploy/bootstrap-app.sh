#!/usr/bin/env bash
# Runs ON the app server (as root) to install the deploy tooling. Called by infra/provision.sh over SSH.
# Expects deploy.sh, run-backend.sh, shopnest@.service, nginx.conf.tpl in the same directory.
set -euo pipefail
cd "$(dirname "$0")"

id shopnest >/dev/null 2>&1 || useradd --system --home /opt/shopnest --shell /usr/sbin/nologin shopnest
mkdir -p /opt/shopnest/bin /etc/shopnest /var/log/shopnest
install -m 755 deploy.sh run-backend.sh /opt/shopnest/bin/
install -m 644 shopnest@.service /etc/systemd/system/shopnest@.service
systemctl daemon-reload

rm -f /etc/nginx/sites-enabled/default
for pair in production:80 staging:8080; do
  ENVN="${pair%%:*}"; PORT="${pair##*:}"
  mkdir -p "/etc/shopnest/$ENVN" "/opt/shopnest/$ENVN"
  [ -f "/etc/shopnest/$ENVN/upstream.inc" ] || echo "server 127.0.0.1:1;" > "/etc/shopnest/$ENVN/upstream.inc"
  sed -e "s/@ENV@/$ENVN/g" -e "s/@PORT@/$PORT/g" nginx.conf.tpl > "/etc/nginx/conf.d/shopnest-$ENVN.conf"
  mkdir -p "/opt/shopnest/$ENVN/releases/_placeholder/frontend"
  [ -L "/opt/shopnest/$ENVN/current" ] || ln -sfn "/opt/shopnest/$ENVN/releases/_placeholder" "/opt/shopnest/$ENVN/current"
done
chown -R shopnest:shopnest /opt/shopnest
chmod 755 /opt/shopnest /etc/shopnest /etc/shopnest/*
nginx -t && systemctl reload nginx
echo "bootstrap complete"
