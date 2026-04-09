# Cloudflare Auth Backend (Workers + KV + R2)

This is the Cloudflare-hosted replacement for the VPS backend.
It matches your bootstrap contract used by `setup1.sh`.

## Endpoints

- `GET /healthz`
- `POST /v1/bootstrap/authorize`
- `GET /v1/bootstrap/payload?token=...`

## What each component stores

- Worker code: auth logic + token verification
- KV (`LICENSES`): license records (`license:<KEY>`)
- R2 (`PAYLOAD_BUCKET`): installer payload file (e.g. `payload.sh`)
- Worker secrets: `TOKEN_SECRET`, `PAYLOAD_SHA256`, `PAYLOAD_SIG_B64`

## 1) Prerequisites

- Node.js + npm installed
- Cloudflare account

```bash
npm install -g wrangler
wrangler login
```

## 2) Create KV and R2

```bash
cd cloudflare-auth
wrangler kv namespace create LICENSES
wrangler r2 bucket create autoscript-payloads
```

Then update `wrangler.toml` with the real KV namespace `id`.

## 3) Upload payload to R2

Use your private payload file (example from this repo):

```bash
wrangler r2 object put autoscript-payloads/payload.sh --file ../private-auth/payloads/install_payload.sh
```

## 4) Compute signature + hash for bootstrap verification

```bash
bash tools/sign_payload.sh ../private-auth/payloads/install_payload.sh ../private-auth/keys/private.pem
```

This prints:

- `PAYLOAD_SHA256=...`
- `PAYLOAD_SIG_B64=...`

Store both as Worker secrets:

```bash
wrangler secret put PAYLOAD_SHA256
wrangler secret put PAYLOAD_SIG_B64
```

Set token secret:

```bash
wrangler secret put TOKEN_SECRET
```

## 5) Add license records to KV

Use the sample JSON in `licenses/example-license.json`.

```bash
bash tools/put_license.sh <KV_NAMESPACE_ID> DEMO-KEY-001 ./licenses/example-license.json
```

## 6) Set BASE_URL and deploy

Edit `wrangler.toml`:

- `BASE_URL` -> your worker/custom-domain URL

Deploy:

```bash
wrangler deploy
```

Quick test:

```bash
curl -s https://<your-worker-domain>/healthz
```

## 7) Point bootstrap to Worker

In `setup1.sh`:

- `AUTH_API_URL="https://<your-worker-domain>/v1/bootstrap/authorize"`
- Keep the embedded public key matching the private key used in `tools/sign_payload.sh`

You can avoid editing `setup1.sh` by exporting env vars:

```bash
bash cloudflare-auth/tools/make_bootstrap_env.sh https://<your-worker-domain> ./private-auth/keys/public.pem
```

Then copy/eval the printed exports before running installer.

If you want one single customer command, generate it with:

```bash
bash cloudflare-auth/tools/make_customer_install_command.sh \
  https://<your-worker-domain> \
  ./private-auth/keys/public.pem \
  https://raw.githubusercontent.com/<owner>/<repo>/main/setup1.sh
```

Output format:

```bash
AUTH_API_URL='https://.../v1/bootstrap/authorize' PUBLIC_KEY_PEM_B64='...' bash <(curl -fsSL 'https://raw.githubusercontent.com/.../setup1.sh')
```

Supported bootstrap key inputs:

- `PUBLIC_KEY_PEM_B64` (recommended)
- `PUBLIC_KEY_URL` (download PEM at runtime)

## 8) Next steps (daily operations)

### Add a customer license quickly

```bash
bash tools/add_license.sh \
  ef7cc518a5f346d2b18d03467185e14d \
  CUSTOMER-KEY-001 \
  1.2.3.4 \
  2026-12-31 \
  1 \
  true
```

### Verify customer authorization

```bash
curl -s -X POST "https://autoscript-auth-worker.bravinlite.workers.dev/v1/bootstrap/authorize" \
  -H "Content-Type: application/json" \
  -d '{"license_key":"CUSTOMER-KEY-001","ip":"1.2.3.4","hwid":"test-hwid"}'
```

Expected: `"status":"ok"`

### Generate customer install command

```bash
bash tools/make_customer_install_command.sh \
  https://autoscript-auth-worker.bravinlite.workers.dev \
  ../private-auth/keys/public.pem \
  https://raw.githubusercontent.com/Bravin-lab/autoscript/master/setup1.sh
```

Copy the output command and send it to that customer.

### One-command payload update release

When you change installer payload, run one command to sign, upload, update secrets, and deploy:

```bash
bash tools/release_payload.sh \
  --payload ../private-auth/payloads/install_payload.sh \
  --private-key ../private-auth/keys/private.pem \
  --bucket autoscript-payloads \
  --object-key payload.sh \
  --deploy
```

If you want to update payload+secrets without deploying immediately, omit `--deploy`.

## License JSON format (KV value)

```json
{
  "status": "active",
  "expires_at": "2027-12-31",
  "allowed_ips": ["1.2.3.4"],
  "max_ips": 1,
  "bind_hwid_on_first_use": true,
  "bound_hwid": ""
}
```

Notes:
- `expires_at` can be `LIFETIME`.
- If `allowed_ips` is empty and `max_ips` > 0, first installs can auto-bind IP until limit.
