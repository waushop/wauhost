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
├── services/               # All HelmReleases (Ghost, NextJS apps, wauhive)

infra/                      # Local Helm charts
├── cert-manager/           # ClusterIssuer config (controller from jetstack HelmRepo)
├── mysql/                  # MySQL deployment
└── sealed-secrets/         # Wrapper (controller from bitnami HelmRepo)

services/                   # Local Helm charts: ghost, wauhive, and one per NextJS app
                            # (agrofort, kraman, onebetwonder, tahetrukk, waushop)
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

All NextJS app HRs use `releaseName: web` and **must** set `storageNamespace: <targetNamespace>` to avoid colliding on a shared `flux-system/sh.helm.release.v1.web.v1` storage entry. Without it, every reconcile triggers a fresh install and replaces the pod every 30 min.

| Service | Namespace | Domain | Chart | Status |
|---------|-----------|--------|-------|--------|
| vausiim | vausiim | vausiim.ee | services/ghost (S3 storage) | Flux |
| wauhive | wauhive | hive.waushop.ee | services/wauhive | Flux |
| agrofort | agrofort | agrofort.ee | services/agrofort (NextJS) | Flux |
| kraman | kraman | kraman.ee | services/kraman (NextJS) | Flux |
| onebetwonder | onebetwonder | obw.waushop.ee | services/onebetwonder (NextJS) | Flux |
| tahetrukk | tahetrukk | tahetrukk.ee | services/tahetrukk (NextJS) | Flux |
| waushop | waushop | waushop.ee | services/waushop (NextJS) | Flux |
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
