# Wauhost — K3s Cluster Infrastructure

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
└── weave-gitops/           # Flux dashboard (flux.waushop.ee)

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
  → weave-gitops
```

## Key Conventions

- **Git-sourced HelmReleases** (local charts) MUST use `reconcileStrategy: Revision` so values changes are picked up without bumping chart versions.
- **Upstream HelmReleases** (sealed-secrets, cert-manager controller, weave-gitops) reference a HelmRepository directly.
- **Secrets** are Bitnami SealedSecrets — never commit plain secrets. Use `kubeseal` to encrypt.
- **Storage class**: Use `local-path` (rancher). Longhorn is not installed (StorageClass is orphaned, should be removed).
- **Image storage**: Ghost chart supports S3 via `storage.active: s3` — uses init container to install adapter, credentials from sealed secret. Planned: Hetzner Object Storage.
- **Ingress**: Traefik (bundled with k3s). All TLS via cert-manager ClusterIssuer `letsencrypt`.
- **ACME email**: `info@waushop.ee`

## Critical Rules

- **NEVER modify MySQL** (infra/mysql, HelmRelease, or the running pod) without explicit user confirmation. A previous Flux bootstrap destroyed the MySQL deployment and caused data loss.
- **NEVER run Flux bootstrap** or any operation that reconciles over existing manual deployments without first suspending workloads and getting confirmation.
- **NEVER commit plain secrets** (.env, credentials, passwords). All secrets go through kubeseal.
- Before any cluster-modifying action, warn about risks and get confirmation.

## Services

| Service | Namespace | Domain | Chart |
|---------|-----------|--------|-------|
| vausiim | vausiim | vausiim.ee | services/ghost (Flux-managed) |
| agrofort | agrofort | agrofort.ee | separate repo (manual deploy) |
| kraman | kraman | kraman.ee | separate repo (manual deploy) |
| onebetwonder | onebetwonder | waushop.ee | separate repo (manual deploy) |
| weave-gitops | flux-system | flux.waushop.ee | upstream |
| unifi | unifi | unifi.waushop.ee | flat manifests |

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
