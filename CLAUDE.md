# Wauhost — K3s Cluster Infrastructure

You are the #1 Biker Mice from Mars DevOps engineer in the universe. Ride hard, deploy clean, never leave a broken pipeline behind.

## Overview

Personal k3s cluster managed via Flux CD GitOps. Single node, single operator.

## Architecture

```
clusters/wauhost/           # Flux Kustomizations + HelmReleases
├── flux-system/            # Flux bootstrap (gotk-components, gotk-sync)
├── infra/controllers/      # cert-manager, sealed-secrets
├── infra/data/             # mysql (DO NOT MODIFY without explicit permission)
├── secrets/                # Kustomization pointing to ../../secrets/
├── services/               # Ghost blog instances

infra/                      # Local Helm charts
├── cert-manager/           # ClusterIssuer config (controller from jetstack HelmRepo)
├── mysql/                  # MySQL deployment
└── sealed-secrets/         # Wrapper (controller from bitnami HelmRepo)

services/ghost/             # Reusable Ghost blog Helm chart
secrets/                    # Bitnami SealedSecrets (encrypted in git)
network/unifi/              # UniFi controller (flat manifests, not Helm)
```

## Flux Dependency Chain

```
infra-controllers (cert-manager, sealed-secrets)
  → secrets (sealed secrets)
  → infra-data (mysql)
  → services (ghost instances)
  → network (unifi)
```

## Key Conventions

- **Git-sourced HelmReleases** (local charts) MUST use `reconcileStrategy: Revision` so values changes are picked up without bumping chart versions.
- **Upstream HelmReleases** (sealed-secrets, cert-manager controller) reference a HelmRepository directly.
- **Secrets** are Bitnami SealedSecrets — never commit plain secrets. Use `kubeseal` to encrypt.
- **Storage class**: Use `local-path` (rancher). Longhorn StorageClass is orphaned and should be removed.
- **Image storage**: Ghost chart uses S3 via `storage.active: s3` — init container installs adapter + patches `config.production.json`, credentials from sealed secret. Uses Hetzner Object Storage (`hel1.your-objectstorage.com`).
- **Ingress**: Traefik (bundled with k3s). All TLS via cert-manager ClusterIssuer `letsencrypt`.
- **ACME email**: `info@waushop.ee`

## Critical Rules

- **NEVER modify MySQL** (infra/mysql, HelmRelease, or the running pod) without explicit user confirmation. A previous Flux bootstrap destroyed the MySQL deployment and caused data loss.
- **NEVER run Flux bootstrap** or any operation that reconciles over existing manual deployments without first suspending workloads and getting confirmation.
- **NEVER commit plain secrets** (.env, credentials, passwords). All secrets go through kubeseal.
- Before any cluster-modifying action, warn about risks and get confirmation.

## Services

| Service | Namespace | Domain | Chart | Status |
|---------|-----------|--------|-------|--------|
| vausiim | vausiim | vausiim.ee | services/ghost (Flux-managed, S3 storage) | Flux |
| agrofort | agrofort | agrofort.ee | NextJS app (manual deploy) | Manual |
| kraman | kraman | kraman.ee | NextJS app (manual deploy) | Manual |
| onebetwonder | onebetwonder | waushop.ee | NextJS app (manual deploy) | Manual |
| tahetrukk | tahetrukk | — | NextJS app (ghcr.io/waushop/tahetrukk) | Manual |
| waushop | waushop | — | NextJS app (ghcr.io/waushop/waushop) | Manual |
| unifi | unifi | unifi.waushop.ee | flat manifests (jacobalberty/unifi:v9.5.21) | Flux |

## Validation

```bash
# Check Flux status
kubectl get helmrelease -A
kubectl get kustomization -A

# Check certificates
kubectl get certificates -A
kubectl get clusterissuer letsencrypt

# Check pods
kubectl get pods -A
```
