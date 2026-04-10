# AutoScript Installer

Only the installer bootstrap scripts are public:

- `setup.sh`
- `setup1.sh`

## Customer install command

Run this on the VPS:

```bash
AUTH_API_URL='https://autoscript-auth-worker.bravinlite.workers.dev/v1/bootstrap/authorize' bash <(curl -fsSL 'https://raw.githubusercontent.com/Bravin-lab/autoscript/master/setup1.sh')
```

If you need a new customer key, add their VPS IP to the whitelist first.
