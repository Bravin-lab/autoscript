#!/bin/bash
set -euo pipefail

# Shared 443 multiplexer for Nginx (HTTPS/WS) and stunnel (SSH-SSL).
# - Front door: nginx stream listens on 443
# - HTTPS/WS traffic: routed to local nginx HTTPS backend on 8443
# - Non-HTTP TLS traffic: routed to local stunnel backend on 7443

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash $0"
  exit 1
fi

NGINX_CONF="/etc/nginx/nginx.conf"
STREAM_DIR="/etc/nginx/stream-conf.d"
STREAM_CONF="${STREAM_DIR}/shared-443.conf"
STUNNEL_CONF="/etc/stunnel/stunnel.conf"

if [[ ! -f "${NGINX_CONF}" ]]; then
  echo "Missing ${NGINX_CONF}. Install nginx first."
  exit 1
fi

if [[ ! -f "${STUNNEL_CONF}" ]]; then
  echo "Missing ${STUNNEL_CONF}. Install stunnel first."
  exit 1
fi

backup_file() {
  local file="$1"
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  cp -a "${file}" "${file}.bak.${ts}"
}

echo "[1/7] Installing nginx stream module if needed..."
if command -v apt-get >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y libnginx-mod-stream
fi

echo "[2/7] Backing up nginx and stunnel config..."
backup_file "${NGINX_CONF}"
backup_file "${STUNNEL_CONF}"

echo "[3/7] Ensuring nginx can load dynamic modules..."
if ! grep -qE '^include /etc/nginx/modules-enabled/\*\.conf;' "${NGINX_CONF}"; then
  sed -i '1i include /etc/nginx/modules-enabled/*.conf;' "${NGINX_CONF}"
fi

echo "[4/7] Ensuring stream include exists in nginx.conf..."
if ! grep -qE '^\s*include /etc/nginx/stream-conf\.d/\*\.conf;' "${NGINX_CONF}"; then
  cat >> "${NGINX_CONF}" <<'EOF'

stream {
    include /etc/nginx/stream-conf.d/*.conf;
}
EOF
fi

echo "[5/7] Writing nginx stream shared-443 router..."
mkdir -p "${STREAM_DIR}"
cat > "${STREAM_CONF}" <<'EOF'
# Shared 443 frontend:
# - ALPN h2/http1.1 -> nginx HTTPS backend on 127.0.0.1:8443
# - other TLS (no ALPN) -> stunnel backend on 127.0.0.1:7443
map $ssl_preread_alpn_protocols $shared443_upstream {
    ~\bh2\b         127.0.0.1:8443;
    ~\bhttp/1.1\b   127.0.0.1:8443;
    default          127.0.0.1:7443;
}

server {
    listen 443 reuseport;
    proxy_pass $shared443_upstream;
    ssl_preread on;
}
EOF

echo "[6/7] Ensuring stunnel backend listener exists on 127.0.0.1:7443..."
if ! grep -q '^\[ssh-ssl-443\]' "${STUNNEL_CONF}"; then
  cat >> "${STUNNEL_CONF}" <<'EOF'

[ssh-ssl-443]
accept = 127.0.0.1:7443
connect = 127.0.0.1:69
EOF
fi

echo "[7/7] Validating and restarting services..."
nginx -t
systemctl restart stunnel4 || systemctl restart stunnel
systemctl restart nginx

echo
cat <<'EOF'
Done.

IMPORTANT NEXT STEP:
Move your existing HTTPS/WS nginx listener from port 443 to 8443.
If nginx still listens directly on 443, it will conflict with the stream frontend.

Quick check:
  ss -lntp | grep ':443 '
  ss -lntp | grep ':8443 '
  ss -lntp | grep ':7443 '
EOF
