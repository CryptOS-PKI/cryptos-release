# helm ⚓

> ☸️ Helm charts for deploying the [CryptOS-PKI](https://github.com/CryptOS-PKI) control plane on Kubernetes.

This repo ships one chart, `charts/manager`, and it is **deprecated**. The supported chart for the **Fleet Manager** (the [`manager`](https://github.com/CryptOS-PKI/manager) Go backend that talks to CryptOS CA nodes over mTLS gRPC and serves the static [`web`](https://github.com/CryptOS-PKI/web) frontend) is `fleet-manager`, which lives in the manager repo. See [Install the Fleet Manager](#-install-the-fleet-manager).

> [!WARNING]
> 🚨 **Status: pre-alpha.** The chart compiles, lints clean, and renders sensible Kubernetes objects, but a production-ready `manager` container image is not yet published to the default registry. Treat this chart as a deployment template you can iterate against, not a turnkey install.

## 📥 Install the Fleet Manager

Install the Fleet Manager with manager's own chart, [`chart/fleet-manager`](https://github.com/CryptOS-PKI/manager/tree/main/chart/fleet-manager). Each manager release tag publishes it to `oci://ghcr.io/cryptos-pki/charts/fleet-manager`:

```bash
helm install fleet oci://ghcr.io/cryptos-pki/charts/fleet-manager --version X.Y.Z
```

Its values (TLS secret, operator CA, fleet nodes, MCP) are documented in the [manager README](https://github.com/CryptOS-PKI/manager#readme), not here.

> [!WARNING]
> **`charts/manager` can't start the manager.** It passes its settings as `FM_*` environment variables, which the manager never reads, and it mounts no `config.yaml`, which is where the manager takes its configuration from. A release installed from it never comes up. Use `fleet-manager` instead. `charts/manager` stays in this repo for now and will be removed in a later change, once manager has published `fleet-manager`.

## 📦 What's in this repo

```
charts/
  manager/                # Fleet Manager Helm chart
    Chart.yaml
    values.yaml
    templates/
      _helpers.tpl
      configmap.yaml
      deployment.yaml
      ingress.yaml
      service.yaml
      serviceaccount.yaml
      NOTES.txt
LICENSE                   # Apache License 2.0
NOTICE
Taskfile.yml              # lint / package / ci targets
.golic.yaml               # license-header injector config
.licignore                # which files golic should touch
```

## ⚙️ Prerequisites

- Helm 3.12+.
- A Kubernetes cluster running 1.27 or newer (the chart's `kubeVersion` constraint enforces this).
- A Kubernetes Secret of type `kubernetes.io/tls` holding the TLS cert and key the Fleet Manager will terminate on. The chart never creates this for you, by design - the cert path is on you.
- A Postgres database reachable from the cluster, and a Kubernetes Secret containing its DSN under the key `dsn` (or whatever you set `postgres.dsnSecretKey` to).

## 🚀 Quickstart

> [!CAUTION]
> These steps install the deprecated `charts/manager`, which can't start the manager. For a working install, see [Install the Fleet Manager](#-install-the-fleet-manager).

Create the supporting secrets in your target namespace, then install:

```bash
kubectl create namespace cryptos-fm

kubectl -n cryptos-fm create secret tls fm-tls \
  --cert=./fm.crt --key=./fm.key

kubectl -n cryptos-fm create secret generic fm-postgres \
  --from-literal=dsn='postgres://fm:password@db.cryptos-fm.svc:5432/fm?sslmode=require'

helm install fm ./charts/manager \
  --namespace cryptos-fm \
  --set fm.tlsSecretName=fm-tls \
  --set postgres.dsnSecretName=fm-postgres
```

Render-only (no install) if you want to eyeball the manifests first:

```bash
helm template fm ./charts/manager \
  --set fm.tlsSecretName=fm-tls \
  --set postgres.dsnSecretName=fm-postgres
```

## 🔧 Values overview

The full schema lives in [`charts/manager/values.yaml`](charts/manager/values.yaml). Highlights:

| Key | Default | Notes |
|---|---|---|
| `replicaCount` | `1` | Backend is stateless; scale horizontally as needed. |
| `image.repository` | `ghcr.io/cryptos-pki/manager` | Backend image. No production tag is published yet. |
| `image.tag` | `""` | Falls back to `.Chart.AppVersion` when empty. |
| `service.type` | `ClusterIP` | Use `ingress` (below) or a `LoadBalancer` override to expose externally. |
| `service.port` / `service.targetPort` | `443` / `8443` | The backend terminates TLS itself; both ports speak HTTPS. |
| `ingress.enabled` | `false` | Off by default. When enabled, only `networking.k8s.io/v1` is supported. |
| `podSecurityContext` / `securityContext` | non-root, read-only rootfs, dropped caps | The container only needs to read the mounted TLS secret and write to `/tmp`. |
| `fm.tlsSecretName` | `""` | Required at runtime. Pre-create the Secret yourself. |
| `postgres.dsnSecretName` | `""` | Required at runtime. DSN read via `secretKeyRef`. |

## 🛠️ Local development

[`go-task`](https://taskfile.dev) wraps the common workflows:

```bash
task lint        # helm lint charts/*
task package     # helm package charts/manager (produces manager-<version>.tgz)
task license     # re-inject Apache 2.0 headers via golic
task ci          # currently equivalent to `task lint`
```

## 🧭 Companion repos

- 🧠 [`cryptos`](https://github.com/CryptOS-PKI/cryptos) - the OS and CA engine (UKI; runs on bare metal or in a VM).
- 🛰️ [`manager`](https://github.com/CryptOS-PKI/manager) - Fleet Manager backend, and its supported Helm chart, `chart/fleet-manager`.
- 🎨 [`web`](https://github.com/CryptOS-PKI/web) - Fleet Manager web frontend (compiled into the `manager` image).
- 📡 [`api`](https://github.com/CryptOS-PKI/api) - shared `.proto` definitions and generated gRPC stubs.

## 📄 License

[Apache License 2.0](LICENSE). Copyright 2026 Shane.
