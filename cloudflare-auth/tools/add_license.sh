#!/bin/bash
set -euo pipefail

# Create and upload a license record to Cloudflare KV in one command.
# Usage:
#   bash tools/add_license.sh <KV_NAMESPACE_ID> <LICENSE_KEY> <VPS_IP> <EXPIRES_AT|LIFETIME> [MAX_IPS] [BIND_HWID]
# Example:
#   bash tools/add_license.sh ef7cc518a5f346d2b18d03467185e14d CUSTOMER-001 1.2.3.4 2026-12-31 1 true

KV_ID="${1:-}"
LICENSE_KEY="${2:-}"
VPS_IP="${3:-}"
EXPIRES_AT="${4:-}"
MAX_IPS="${5:-1}"
BIND_HWID="${6:-true}"

if [[ -z "$KV_ID" || -z "$LICENSE_KEY" || -z "$VPS_IP" || -z "$EXPIRES_AT" ]]; then
  echo "Usage: bash tools/add_license.sh <KV_NAMESPACE_ID> <LICENSE_KEY> <VPS_IP> <EXPIRES_AT|LIFETIME> [MAX_IPS] [BIND_HWID]"
  exit 1
fi

if [[ "$EXPIRES_AT" != "LIFETIME" ]]; then
  if ! [[ "$EXPIRES_AT" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "EXPIRES_AT must be LIFETIME or YYYY-MM-DD"
    exit 1
  fi
fi

if ! [[ "$MAX_IPS" =~ ^[0-9]+$ ]]; then
  echo "MAX_IPS must be a number"
  exit 1
fi

if [[ "$BIND_HWID" != "true" && "$BIND_HWID" != "false" ]]; then
  echo "BIND_HWID must be true or false"
  exit 1
fi

TMP_FILE="$(mktemp /tmp/license-XXXXXX.json)"
trap 'rm -f "$TMP_FILE"' EXIT

cat > "$TMP_FILE" <<EOF
{
  "status": "active",
  "expires_at": "$EXPIRES_AT",
  "allowed_ips": ["$VPS_IP"],
  "max_ips": $MAX_IPS,
  "bind_hwid_on_first_use": $BIND_HWID,
  "bound_hwid": ""
}
EOF

wrangler kv key put --namespace-id "$KV_ID" "license:$LICENSE_KEY" --path "$TMP_FILE" --remote
echo "Added license: $LICENSE_KEY for IP: $VPS_IP"
