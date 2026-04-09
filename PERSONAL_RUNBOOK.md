# Personal Runbook (Cloudflare Auth + AutoScript)

This is your quick operational guide.

## Current live worker

- Worker URL: `https://autoscript-auth-worker.bravinlite.workers.dev`
- Authorize endpoint: `https://autoscript-auth-worker.bravinlite.workers.dev/v1/bootstrap/authorize`
- KV Namespace ID: `ef7cc518a5f346d2b18d03467185e14d`
- R2 Bucket: `autoscript-payloads`
- Payload object key: `payload.sh`

## 1) Add a customer license

Run from `cloudflare-auth/`:

```bash
bash tools/add_license.sh \
  ef7cc518a5f346d2b18d03467185e14d \
  CUSTOMER-KEY-001 \
  1.2.3.4 \
  2026-12-31 \
  1 \
  true
```

Arguments:
- `KV_NAMESPACE_ID`
- `LICENSE_KEY`
- `VPS_IP`
- `EXPIRES_AT` (`YYYY-MM-DD` or `LIFETIME`)
- `MAX_IPS` (default `1`)
- `BIND_HWID` (`true/false`, default `true`)

## 2) Test authorization

```bash
curl -s -X POST "https://autoscript-auth-worker.bravinlite.workers.dev/v1/bootstrap/authorize" \
  -H "Content-Type: application/json" \
  -d '{"license_key":"CUSTOMER-KEY-001","ip":"1.2.3.4","hwid":"test-hwid"}'
```

Expected: `"status":"ok"`.

## 3) Generate customer install command

Run from repo root:

```bash
bash cloudflare-auth/tools/make_customer_install_command.sh \
  https://autoscript-auth-worker.bravinlite.workers.dev \
  ./private-auth/keys/public.pem \
  https://raw.githubusercontent.com/Bravin-lab/autoscript/master/setup1.sh
```

Copy the output one-liner and send to customer.

## 4) Release updated payload (when script changes)

Run from `cloudflare-auth/`:

```bash
bash tools/release_payload.sh \
  --payload ../private-auth/payloads/install_payload.sh \
  --private-key ../private-auth/keys/private.pem \
  --bucket autoscript-payloads \
  --object-key payload.sh \
  --deploy
```

This signs payload, uploads to remote R2, updates secrets, and deploys Worker.

## 5) Health check

```bash
curl -s "https://autoscript-auth-worker.bravinlite.workers.dev/healthz"
```

Expected: `{"status":"ok"}`.

## 6) Common issues

- `license not found`:
  - License not in remote KV. Re-run `add_license.sh` (it uses `--remote`).
- `payload_url` wrong domain:
  - Check `BASE_URL` in `cloudflare-auth/wrangler.toml`, then `wrangler deploy`.
- signature mismatch on client:
  - Re-run `release_payload.sh` after payload changes.
- auth denied by IP:
  - Ensure customer VPS public IP matches the license `allowed_ips`.

## 7) Security reminders

- Never commit `private-auth/keys/private.pem`.
- Keep `TOKEN_SECRET` private.
- Rotate `TOKEN_SECRET` if compromised.
- Prefer short license durations and renew when needed.
