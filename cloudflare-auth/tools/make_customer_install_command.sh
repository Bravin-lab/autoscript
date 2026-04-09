#!/bin/bash
set -euo pipefail

# Generates a single customer install command that injects AUTH_API_URL and PUBLIC_KEY_PEM_B64.
# Usage:
#   bash cloudflare-auth/tools/make_customer_install_command.sh \
#     https://your-worker.workers.dev \
#     ./private-auth/keys/public.pem \
#     https://raw.githubusercontent.com/<owner>/<repo>/main/setup1.sh

WORKER_BASE_URL="${1:-}"
PUBLIC_KEY_FILE="${2:-}"
SETUP1_URL="${3:-}"

if [[ -z "$WORKER_BASE_URL" || -z "$PUBLIC_KEY_FILE" || -z "$SETUP1_URL" ]]; then
  echo "Usage: bash cloudflare-auth/tools/make_customer_install_command.sh <worker_base_url> <public_pem_path> <setup1_raw_url>"
  exit 1
fi

if [[ ! -f "$PUBLIC_KEY_FILE" ]]; then
  echo "Public key file not found: $PUBLIC_KEY_FILE"
  exit 1
fi

PUBLIC_KEY_B64="$(base64 -w 0 "$PUBLIC_KEY_FILE")"
AUTH_URL="${WORKER_BASE_URL%/}/v1/bootstrap/authorize"

cat <<EOF
AUTH_API_URL='$AUTH_URL' PUBLIC_KEY_PEM_B64='$PUBLIC_KEY_B64' bash <(curl -fsSL '$SETUP1_URL')
EOF
