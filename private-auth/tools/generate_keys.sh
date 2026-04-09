#!/bin/bash
set -euo pipefail

OUT_DIR="$(cd "$(dirname "$0")/.." && pwd)/keys"
mkdir -p "$OUT_DIR"

if [[ -f "$OUT_DIR/private.pem" || -f "$OUT_DIR/public.pem" ]]; then
  echo "Key files already exist in $OUT_DIR"
  echo "Delete them first if you want to regenerate."
  exit 1
fi

openssl genpkey -algorithm RSA -out "$OUT_DIR/private.pem" -pkeyopt rsa_keygen_bits:3072
openssl rsa -pubout -in "$OUT_DIR/private.pem" -out "$OUT_DIR/public.pem"
chmod 600 "$OUT_DIR/private.pem"
chmod 644 "$OUT_DIR/public.pem"

echo "Generated:"
echo "  $OUT_DIR/private.pem"
echo "  $OUT_DIR/public.pem"
