Store each license as one KV key:

- Key format: `license:<LICENSE_KEY>`
- Value format: JSON like `example-license.json`

Example:

```bash
wrangler kv key put --namespace-id <KV_NAMESPACE_ID> \
  "license:DEMO-KEY-001" \
  --path ./licenses/example-license.json
```
