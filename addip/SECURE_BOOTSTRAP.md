# Secure Bootstrap Flow

This repo now uses a public bootstrap loader (`setup.sh` -> `setup1.sh`) and expects the real installer to be served by your private backend.

## 1) Configure bootstrap variables

Edit `setup1.sh` and set:

- `AUTH_API_URL` to your private auth endpoint.
- `DEFAULT_PUBLIC_KEY_PEM` to your RSA public key used to sign payloads.

## 2) API request format

`setup1.sh` sends JSON:

```json
{
  "license_key": "YOUR_LICENSE",
  "ip": "SERVER_PUBLIC_IP",
  "hwid": "MACHINE_ID"
}
```

## 3) API success response format

Your API must return JSON with string fields:

```json
{
  "status": "ok",
  "message": "authorized",
  "payload_url": "https://private.example.com/payloads/install-2026-04-08.sh",
  "payload_sha256": "<sha256 of payload file>",
  "payload_sig_b64": "<base64 RSA-SHA256 signature bytes>"
}
```

If blocked/expired:

```json
{
  "status": "deny",
  "message": "license expired"
}
```

## 4) How to sign payload

Generate RSA keypair once:

```bash
openssl genpkey -algorithm RSA -out private.pem -pkeyopt rsa_keygen_bits:3072
openssl rsa -pubout -in private.pem -out public.pem
```

Sign payload:

```bash
openssl dgst -sha256 -sign private.pem -out payload.sig payload.sh
base64 -w 0 payload.sig
sha256sum payload.sh | awk '{print $1}'
```

Put public key from `public.pem` into `setup1.sh`.

## 5) Recommended backend checks

- Validate `license_key` exists and active.
- Match/allow the requesting `ip`.
- Enforce expiry and max VPS count.
- Optionally bind `hwid` after first activation.
- Issue short-lived payload URLs.
