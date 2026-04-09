#!/bin/bash
set -euo pipefail

# Usage:
#   bash tools/put_license.sh <KV_NAMESPACE_ID> <LICENSE_KEY> <JSON_FILE>

KV_ID="${1:-}"
LICENSE_KEY="${2:-}"
JSON_FILE="${3:-}"

if [[ -z "$KV_ID" || -z "$LICENSE_KEY" || -z "$JSON_FILE" ]]; then
  echo "Usage: bash tools/put_license.sh <KV_NAMESPACE_ID> <LICENSE_KEY> <JSON_FILE>"
  exit 1
fi

if [[ ! -f "$JSON_FILE" ]]; then
  echo "License JSON not found: $JSON_FILE"
  exit 1
fi

wrangler kv key put --namespace-id "$KV_ID" "license:${LICENSE_KEY}" --path "$JSON_FILE" --remote
echo "Stored license key: license:${LICENSE_KEY}"
