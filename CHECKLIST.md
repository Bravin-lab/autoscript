# Daily Checklist

1. Health check Worker:
```bash
curl -s "https://autoscript-auth-worker.bravinlite.workers.dev/healthz"
```

2. Add/renew customer license:
```bash
cd cloudflare-auth
bash tools/add_license.sh ef7cc518a5f346d2b18d03467185e14d CUSTOMER-KEY VPS_IP YYYY-MM-DD 1 true
```

3. Verify authorize response:
```bash
curl -s -X POST "https://autoscript-auth-worker.bravinlite.workers.dev/v1/bootstrap/authorize" \
  -H "Content-Type: application/json" \
  -d '{"license_key":"CUSTOMER-KEY","ip":"VPS_IP","hwid":"test-hwid"}'
```

4. Generate customer installer command:
```bash
bash cloudflare-auth/tools/make_customer_install_command.sh \
  https://autoscript-auth-worker.bravinlite.workers.dev \
  ./private-auth/keys/public.pem \
  https://raw.githubusercontent.com/Bravin-lab/autoscript/master/setup1.sh
```

5. When payload changes, release update:
```bash
cd cloudflare-auth
bash tools/release_payload.sh \
  --payload ../private-auth/payloads/install_payload.sh \
  --private-key ../private-auth/keys/private.pem \
  --bucket autoscript-payloads \
  --object-key payload.sh \
  --deploy
```
