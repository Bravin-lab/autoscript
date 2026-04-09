#!/bin/bash
set -euo pipefail

# Publish installer payload to backend path used by private-auth config.
# Usage:
#   sudo bash tools/publish_payload.sh /path/to/install_payload.sh

SRC_PAYLOAD="${1:-}"
DEST_DIR="/opt/autoscript-private"
DEST_PAYLOAD="${DEST_DIR}/payload.sh"

if [[ -z "$SRC_PAYLOAD" ]]; then
  echo "Usage: sudo bash tools/publish_payload.sh /path/to/install_payload.sh"
  exit 1
fi

if [[ ! -f "$SRC_PAYLOAD" ]]; then
  echo "Source payload not found: $SRC_PAYLOAD"
  exit 1
fi

mkdir -p "$DEST_DIR"
cp "$SRC_PAYLOAD" "$DEST_PAYLOAD"
chmod 700 "$DEST_PAYLOAD"

echo "Payload published to: $DEST_PAYLOAD"
echo "Ensure private-auth/config.json uses:"
echo "  \"payload_file\": \"$DEST_PAYLOAD\""
