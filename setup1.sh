#!/bin/bash
set -euo pipefail

# Secure public bootstrap loader.
# Public repo holds only this loader; real installer is delivered from your private backend.

AUTH_API_URL="${AUTH_API_URL:-https://auth.example.workers.dev/v1/bootstrap/authorize}"
LICENSE_KEY="${LICENSE_KEY:-}"
PUBLIC_KEY_PEM_B64="${PUBLIC_KEY_PEM_B64:-}"
PUBLIC_KEY_URL="${PUBLIC_KEY_URL:-}"
SERVER_IP=""
HWID=""
WORK_DIR="$(mktemp -d /tmp/autoscript-bootstrap.XXXXXX)"
PAYLOAD_FILE="${WORK_DIR}/payload.sh"
SIG_FILE="${WORK_DIR}/payload.sig"
PUBKEY_FILE="${WORK_DIR}/pubkey.pem"

trap 'rm -rf "${WORK_DIR}"' EXIT

# Replace this with your real RSA public key for payload signature verification.
# You can also inject key without editing this file by using either:
# - PUBLIC_KEY_PEM_B64=<base64 PEM>
# - PUBLIC_KEY_URL=https://.../public.pem
read -r -d '' DEFAULT_PUBLIC_KEY_PEM <<'KEYEOF' || true
-----BEGIN PUBLIC KEY-----
MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEAnKTCDmJOmvc0u31DLi66
sIueOSRfyHhVu3+AF2+O0vKzw0ruUfLbZ1kHPIHa/5/fDj41TK9p/IyIk9DibKip
gQ0z74qvKIFT8hjkkVRKdlMmBqYlA78yBX8jNrdDyDV6Cfhl1gYOPHVWNzqLCJw6
kdsM2ihrjIj07v6CQb3dC2b1EJGb5n1E3PMlvwF1XpzTd8Enkocyc6TRC7kDXbVM
8zPgmOsqumtKMqVqPrywqLp4qgf1/hZ2cgr1/iEA1D7l79fFtoiY5XpnS94DXIYJ
QPPJ/M02IZhAio7lBLF0gw7VZEDbqPY0ytPfirmzcLlXZnGe2pqq0E0mjTtx4mKh
jOl4TYYP88HCP2mM9q4NkrYsxMdDXXlOFcXpxI1OjsQ5owPJaUeiab008AicJuZ3
EhOTfdxPYIikMs2raXnj1icbcecNbximv1Z5sN7t3uYABuXFsHMtRDebMnfYtuJ9
ujsbzy7mt0YmPuEbmP8AU4tDNuDYXvT6zOa7QuGjkXq/AgMBAAE=
-----END PUBLIC KEY-----
KEYEOF

fail() {
  echo "[ERROR] $*"
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

json_get_string() {
  # Lightweight JSON string extractor for flat key/value responses.
  # Expected format: "key":"value"
  local key="$1"
  sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n1
}

need_cmd curl
need_cmd awk
need_cmd sed
need_cmd openssl
need_cmd sha256sum
need_cmd base64
need_cmd mktemp
need_cmd bash

if [[ "${EUID}" -ne 0 ]]; then
  fail "Run as root."
fi

if [[ "$(systemd-detect-virt 2>/dev/null || true)" == "openvz" ]]; then
  fail "OpenVZ is not supported."
fi

SERVER_IP="$(curl -4fsS https://ipv4.icanhazip.com 2>/dev/null || curl -4fsS https://api.ipify.org 2>/dev/null || true)"
SERVER_IP="$(echo "${SERVER_IP}" | tr -d '[:space:]')"
[[ -n "${SERVER_IP}" ]] || fail "Unable to detect public IPv4."

if [[ -f /etc/machine-id ]]; then
  HWID="$(cat /etc/machine-id)"
else
  HWID="$(hostname)"
fi

if [[ -z "${LICENSE_KEY}" ]]; then
  read -r -p "Enter license key: " LICENSE_KEY
fi
[[ -n "${LICENSE_KEY}" ]] || fail "License key is required."

if [[ "${AUTH_API_URL}" == "https://auth.example.workers.dev/v1/bootstrap/authorize" ]]; then
  fail "Set AUTH_API_URL to your deployed Worker endpoint before use."
fi

RESOLVED_PUBLIC_KEY_PEM="${DEFAULT_PUBLIC_KEY_PEM}"
if [[ -n "${PUBLIC_KEY_PEM_B64}" ]]; then
  RESOLVED_PUBLIC_KEY_PEM="$(echo "${PUBLIC_KEY_PEM_B64}" | base64 -d 2>/dev/null || true)"
  [[ -n "${RESOLVED_PUBLIC_KEY_PEM}" ]] || fail "PUBLIC_KEY_PEM_B64 is invalid base64 or empty."
elif [[ -n "${PUBLIC_KEY_URL}" ]]; then
  RESOLVED_PUBLIC_KEY_PEM="$(curl -fsSL "${PUBLIC_KEY_URL}" 2>/dev/null || wget -qO- "${PUBLIC_KEY_URL}" 2>/dev/null || true)"
  [[ -n "${RESOLVED_PUBLIC_KEY_PEM}" ]] || fail "Failed to download public key from PUBLIC_KEY_URL."
fi

if echo "${RESOLVED_PUBLIC_KEY_PEM}" | grep -q "REPLACE_WITH_YOUR_RSA_PUBLIC_KEY"; then
  fail "Replace embedded public key with your real RSA public key."
fi

if ! echo "${RESOLVED_PUBLIC_KEY_PEM}" | grep -q "BEGIN PUBLIC KEY"; then
  fail "Resolved public key is invalid (missing BEGIN PUBLIC KEY)."
fi

echo "[INFO] Requesting install authorization..."
AUTH_JSON="$(curl -fsS -X POST "${AUTH_API_URL}" \
  -H 'Content-Type: application/json' \
  -d "{\"license_key\":\"${LICENSE_KEY}\",\"ip\":\"${SERVER_IP}\",\"hwid\":\"${HWID}\"}")" \
  || fail "Authorization request failed."

STATUS="$(echo "${AUTH_JSON}" | json_get_string status)"
if [[ "${STATUS}" != "ok" ]]; then
  MESSAGE="$(echo "${AUTH_JSON}" | json_get_string message)"
  [[ -n "${MESSAGE}" ]] || MESSAGE="Not authorized"
  fail "${MESSAGE}"
fi

PAYLOAD_URL="$(echo "${AUTH_JSON}" | json_get_string payload_url)"
PAYLOAD_SHA256="$(echo "${AUTH_JSON}" | json_get_string payload_sha256)"
PAYLOAD_SIG_B64="$(echo "${AUTH_JSON}" | json_get_string payload_sig_b64)"

[[ -n "${PAYLOAD_URL}" ]] || fail "Missing payload_url in API response."
[[ -n "${PAYLOAD_SHA256}" ]] || fail "Missing payload_sha256 in API response."
[[ -n "${PAYLOAD_SIG_B64}" ]] || fail "Missing payload_sig_b64 in API response."

echo "[INFO] Downloading protected installer payload..."
# Force IPv4 so payload request IP matches the IPv4 bound into the token.
curl -4fsSLo "${PAYLOAD_FILE}" "${PAYLOAD_URL}" || fail "Payload download failed."

CALC_SHA256="$(sha256sum "${PAYLOAD_FILE}" | awk '{print $1}')"
if [[ "${CALC_SHA256}" != "${PAYLOAD_SHA256}" ]]; then
  fail "Payload checksum verification failed."
fi

echo "${PAYLOAD_SIG_B64}" | base64 -d > "${SIG_FILE}" || fail "Invalid payload signature encoding."
printf '%s\n' "${RESOLVED_PUBLIC_KEY_PEM}" > "${PUBKEY_FILE}"

openssl dgst -sha256 -verify "${PUBKEY_FILE}" -signature "${SIG_FILE}" "${PAYLOAD_FILE}" >/dev/null 2>&1 \
  || fail "Payload signature verification failed."

chmod +x "${PAYLOAD_FILE}"
echo "[INFO] Signature verified. Running installer..."
exec bash "${PAYLOAD_FILE}"
