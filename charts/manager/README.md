# manager ⚓

> 🛰️ Helm chart for the CryptOS-PKI Fleet Manager.

The chart renders the manager's config file into the `<release>-config` ConfigMap and mounts it at `/etc/cryptos/fleet/config.yaml`, the path the image reads at startup. A change to any value that feeds the config rolls the pods, because the manager reads its config only once. See the [repository README](../../README.md) for the quickstart and the full values overview.

## 🤖 MCP endpoint

The manager can serve a Model Context Protocol endpoint for AI agents at `/mcp`, on the same listener as the UI and API. It is off by default.

| Key | Default | Notes |
|---|---|---|
| `mcp.enabled` | `false` | Serves `/mcp`. Rendered as `mcp.enabled` in the manager config. |
| `mcp.publicURL` | `""` | The manager's external https origin with no path, exactly as agents and browsers reach it, for example `https://fleetos.example.org`. It is the OAuth issuer and the base of the protected resource URL (`<publicURL>/mcp`). Rendered as `mcp.public_url`. |
| `operatorCANode` | `""` | Inventory name of the fleet node that acts as the operator CA. Operator credential issuance and revocation route to it, and the manager enforces operator-certificate revocation from it. Useful on its own; empty disables both. Rendered as `operator_ca_node`. |
| `operatorCA.configMap` | `""` | ConfigMap in the release namespace holding `operator-ca.pem`, the trust anchor for operator client certificates. Mounted into the pod and rendered as `operatorCAPath` when set. |

⚠️ **Startup requirement:** the manager refuses to start with MCP enabled unless `operatorCANode` is set, because each MCP key stands for an operator certificate and without a revocation source a revoked operator's keys would keep working. It also needs the operator CA (`operatorCA.configMap`) and an https `mcp.publicURL`. The chart checks all three and fails the render with a message naming the missing value, rather than leaving a pod in a crash loop.

```yaml
operatorCANode: operator-ca
operatorCA:
  configMap: fm-operator-ca
mcp:
  enabled: true
  publicURL: https://fleetos.example.org
```

Create the operator CA ConfigMap before installing:

```bash
kubectl -n cryptos-fm create configmap fm-operator-ca \
  --from-file=operator-ca.pem=./operator-ca.pem
```
