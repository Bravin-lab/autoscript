#!/bin/bash
set -euo pipefail

# Prints export lines for running setup1.sh against deployed Worker.
# Usage:
#   bash cloudflare-auth/tools/make_bootstrap_env.sh https://your-worker.workers.dev /path/to/public.pem

WORKER_BASE_URL="${1:-}"
PUBLIC_KEY_FILE="${2:-}"

if [[ -z "$WORKER_BASE_URL" || -z "$PUBLIC_KEY_FILE" ]]; then
  echo "Usage: bash cloudflare-auth/tools/make_bootstrap_env.sh https://your-worker.workers.dev /path/to/public.pem"
  exit 1
fi

if [[ ! -f "$PUBLIC_KEY_FILE" ]]; then
  echo "Public key file not found: $PUBLIC_KEY_FILE"
  exit 1
fi

PUBLIC_KEY_B64="$(base64 -w 0 "$PUBLIC_KEY_FILE")"
AUTH_URL="${WORKER_BASE_URL%/}/v1/bootstrap/authorize"

echo "export AUTH_API_URL='$AUTH_URL'"
echo "export PUBLIC_KEY_PEM_B64='$PUBLIC_KEY_B64'"
