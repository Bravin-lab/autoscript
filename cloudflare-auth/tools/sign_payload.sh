#!/bin/bash
set -euo pipefail

# Usage:
#   bash tools/sign_payload.sh /path/to/payload.sh /path/to/private.pem

PAYLOAD="${1:-}"
PRIVATE_KEY="${2:-}"

if [[ -z "$PAYLOAD" || -z "$PRIVATE_KEY" ]]; then
  echo "Usage: bash tools/sign_payload.sh /path/to/payload.sh /path/to/private.pem"
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

TMP_SIG="$(mktemp /tmp/payload-sig.XXXXXX)"
trap 'rm -f "$TMP_SIG"' EXIT

openssl dgst -sha256 -sign "$PRIVATE_KEY" -out "$TMP_SIG" "$PAYLOAD"
SHA256_VALUE="$(sha256sum "$PAYLOAD" | awk '{print $1}')"
SIG_B64="$(base64 -w 0 "$TMP_SIG")"

echo "PAYLOAD_SHA256=$SHA256_VALUE"
echo "PAYLOAD_SIG_B64=$SIG_B64"

echo
 echo "Set them in Worker secrets/vars, for example:"
echo "  wrangler secret put PAYLOAD_SHA256"
echo "  wrangler secret put PAYLOAD_SIG_B64"
