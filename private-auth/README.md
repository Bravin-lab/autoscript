# Private Auth API (for secure bootstrap)

This service is the private backend expected by `setup1.sh`.

## What it does

- Validates `license_key`, IP whitelist, expiry, and optional HWID binding.
- Returns short-lived payload URL + SHA256 + RSA signature.
- Serves installer payload only with a valid token.

## Files

- `app.py` - Flask API server.
- `config.example.json` - Example runtime config.
- `licenses.example.json` - Example license database.
- `tools/generate_keys.sh` - Generate RSA keys.
- `keys/` - Key directory.

## 1) Setup

```bash
cd private-auth
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## 2) Create keys

```bash
bash tools/generate_keys.sh
```

## 3) Prepare config and licenses

```bash
cp config.example.json config.json
cp licenses.example.json licenses.json
```

Edit `config.json`:

- `base_url`: Public URL of this API, e.g. `https://auth.example.com`
- `token_secret`: Long random secret
- `payload_file`: Absolute path to your real private installer script
- `private_key_pem`: Usually `./keys/private.pem`
- `licenses_file`: Usually `./licenses.json`

Edit `licenses.json` to add real customer keys and allowed IPs.

## 3.1) Use your current installer as private payload

This repo now includes an extracted payload copy:

- `payloads/install_payload.sh`

Publish it to the private backend path:

```bash
chmod +x tools/publish_payload.sh
sudo bash tools/publish_payload.sh "$PWD/payloads/install_payload.sh"
```

Then ensure `config.json` points to:

```json
"payload_file": "/opt/autoscript-private/payload.sh"
```

## 4) Run server

```bash
python app.py
```

Health check:

```bash
curl -s http://127.0.0.1:8080/healthz
```

## 4.1) Production deploy (systemd + nginx)

From your main repo root:

```bash
chmod +x private-auth/tools/install_production.sh
sudo bash private-auth/tools/install_production.sh "$PWD/private-auth" auth.example.com
```

Then issue TLS:

```bash
sudo certbot --nginx -d auth.example.com
```

Files used:

- `deploy/private-auth.service`
- `deploy/nginx-auth.conf`
- `tools/install_production.sh`
- `tools/publish_payload.sh`

After editing config/license files:

```bash
sudo systemctl restart private-auth
sudo systemctl status private-auth --no-pager
```

## 5) Hook into bootstrap loader

In `setup1.sh`:

- Set `AUTH_API_URL` to your endpoint, e.g. `https://auth.example.com/v1/bootstrap/authorize`
- Replace embedded placeholder public key with contents of `private-auth/keys/public.pem`

Quick helper to print public key for copy/paste:

```bash
cat private-auth/keys/public.pem
```

## Authorize API contract

Request JSON:

```json
{
  "license_key": "YOUR_KEY",
  "ip": "SERVER_PUBLIC_IP",
  "hwid": "MACHINE_ID"
}
```

Success response:

```json
{
  "status": "ok",
  "message": "authorized",
  "payload_url": "https://auth.example.com/v1/bootstrap/payload?token=...",
  "payload_sha256": "...",
  "payload_sig_b64": "..."
}
```

Deny response:

```json
{
  "status": "deny",
  "message": "reason"
}
```

## Notes

- Keep `private.pem` secret and never commit it publicly.
- Use HTTPS in production.
- If using reverse proxy/CDN, pass real client IP so token-IP check remains accurate.
