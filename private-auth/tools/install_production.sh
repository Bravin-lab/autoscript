#!/bin/bash
set -euo pipefail

# Production installer for private-auth backend.
# Usage:
#   sudo bash tools/install_production.sh /path/to/private-auth auth.example.com

SRC_DIR="${1:-}"
DOMAIN="${2:-}"
TARGET_DIR="/opt/autoscript-private-auth"

if [[ -z "$SRC_DIR" || -z "$DOMAIN" ]]; then
  echo "Usage: sudo bash tools/install_production.sh /path/to/private-auth auth.example.com"
  exit 1
fi

if [[ ! -d "$SRC_DIR" ]]; then
  echo "Source directory not found: $SRC_DIR"
  exit 1
fi

if [[ ! -f "$SRC_DIR/app.py" ]]; then
  echo "app.py not found in source directory: $SRC_DIR"
  exit 1
fi

apt-get update -y
apt-get install -y python3 python3-venv python3-pip nginx certbot python3-certbot-nginx

rm -rf "$TARGET_DIR"
mkdir -p "$TARGET_DIR"
cp -a "$SRC_DIR"/. "$TARGET_DIR"/

python3 -m venv "$TARGET_DIR/.venv"
"$TARGET_DIR/.venv/bin/pip" install --upgrade pip
"$TARGET_DIR/.venv/bin/pip" install -r "$TARGET_DIR/requirements.txt"

if [[ ! -f "$TARGET_DIR/config.json" ]]; then
  cp "$TARGET_DIR/config.example.json" "$TARGET_DIR/config.json"
  echo "Created $TARGET_DIR/config.json from template. Edit it before starting the service."
fi

if [[ ! -f "$TARGET_DIR/licenses.json" ]]; then
  cp "$TARGET_DIR/licenses.example.json" "$TARGET_DIR/licenses.json"
  echo "Created $TARGET_DIR/licenses.json from template. Edit it before starting the service."
fi

sed "s/auth.example.com/$DOMAIN/g" "$TARGET_DIR/deploy/nginx-auth.conf" > /etc/nginx/sites-available/private-auth
ln -sf /etc/nginx/sites-available/private-auth /etc/nginx/sites-enabled/private-auth
rm -f /etc/nginx/sites-enabled/default

cp "$TARGET_DIR/deploy/private-auth.service" /etc/systemd/system/private-auth.service

systemctl daemon-reload
systemctl enable private-auth

nginx -t
systemctl restart nginx

echo "Issue TLS certificate with:"
echo "  certbot --nginx -d $DOMAIN"
echo
echo "After editing config/license files, start service:"
echo "  systemctl restart private-auth"
echo "  systemctl status private-auth --no-pager"
