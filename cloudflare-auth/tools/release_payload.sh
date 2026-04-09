#!/bin/bash
set -euo pipefail

# One-command payload release for Cloudflare backend.
# It performs:
# 1) payload sanity check
# 2) signature + sha256 generation
# 3) remote R2 upload
# 4) update Worker secrets (PAYLOAD_SHA256, PAYLOAD_SIG_B64)
# 5) optional wrangler deploy
#
# Usage:
#   bash tools/release_payload.sh \
#     --payload ../private-auth/payloads/install_payload.sh \
#     --private-key ../private-auth/keys/private.pem \
#     --bucket autoscript-payloads \
#     --object-key payload.sh \
#     --deploy

PAYLOAD=""
PRIVATE_KEY=""
BUCKET="autoscript-payloads"
OBJECT_KEY="payload.sh"
DEPLOY="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --payload)
      PAYLOAD="${2:-}"
      shift 2
      ;;
    --private-key)
      PRIVATE_KEY="${2:-}"
      shift 2
      ;;
    --bucket)
      BUCKET="${2:-}"
      shift 2
      ;;
    --object-key)
      OBJECT_KEY="${2:-}"
      shift 2
      ;;
    --deploy)
      DEPLOY="true"
      shift
      ;;
    --help|-h)
      sed -n '1,40p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

if [[ -z "$PAYLOAD" || -z "$PRIVATE_KEY" ]]; then
  echo "Missing required arguments."
  echo "Use: --payload <file> --private-key <file> [--bucket <name>] [--object-key <key>] [--deploy]"
  exit 1
fi

if [[ ! -f "$PAYLOAD" ]]; then
  echo "Payload file not found: $PAYLOAD"
  exit 1
fi

if [[ ! -f "$PRIVATE_KEY" ]]; then
  echo "Private key not found: $PRIVATE_KEY"
  exit 1
fi

if ! command -v wrangler >/dev/null 2>&1; then
  echo "wrangler not found in PATH"
  exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "openssl not found in PATH"
  exit 1
fi

if ! command -v sha256sum >/dev/null 2>&1; then
  echo "sha256sum not found in PATH"
  exit 1
fi

if ! command -v base64 >/dev/null 2>&1; then
  echo "base64 not found in PATH"
  exit 1
fi

echo "[1/5] Signing payload and computing checksum..."
TMP_SIG="$(mktemp /tmp/payload-sig.XXXXXX)"
trap 'rm -f "$TMP_SIG"' EXIT

openssl dgst -sha256 -sign "$PRIVATE_KEY" -out "$TMP_SIG" "$PAYLOAD"
PAYLOAD_SHA256="$(sha256sum "$PAYLOAD" | awk '{print $1}')"
PAYLOAD_SIG_B64="$(base64 -w 0 "$TMP_SIG")"

echo "[2/5] Uploading payload to R2 (remote)..."
wrangler r2 object put "${BUCKET}/${OBJECT_KEY}" --file "$PAYLOAD" --remote

echo "[3/5] Updating PAYLOAD_SHA256 secret..."
echo -n "$PAYLOAD_SHA256" | wrangler secret put PAYLOAD_SHA256

echo "[4/5] Updating PAYLOAD_SIG_B64 secret..."
echo -n "$PAYLOAD_SIG_B64" | wrangler secret put PAYLOAD_SIG_B64

if [[ "$DEPLOY" == "true" ]]; then
  echo "[5/5] Deploying Worker..."
  wrangler deploy
else
  echo "[5/5] Skipped deploy (use --deploy to include it)."
fi

echo
echo "Release complete."
echo "PAYLOAD_SHA256=$PAYLOAD_SHA256"
