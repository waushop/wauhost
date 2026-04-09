# Wauhost Kubernetes Infrastructure

Personal k3s cluster managed via Flux CD GitOps. Single node, single operator.

## Repository Structure

```
wauhost/
├── clusters/wauhost/           # Flux Kustomizations + HelmReleases
│   ├── flux-system/            # Flux bootstrap (gotk-components, gotk-sync)
│   ├── infra/controllers/      # cert-manager, sealed-secrets
│   ├── infra/data/             # mysql
│   ├── secrets/                # Kustomization pointing to ../../secrets/
│   ├── services/               # Ghost blog instances
│   ├── weave-gitops/           # Flux dashboard (flux.waushop.ee)
│   └── network.yaml            # UniFi controller
├── infra/                      # Local Helm charts
│   ├── cert-manager/           # ClusterIssuer config
│   ├── mysql/                  # MySQL deployment
│   └── sealed-secrets/         # Sealed Secrets controller
├── services/                   # Reusable service charts
│   └── ghost/                  # Ghost blog (S3 storage via Hetzner Object Storage)
├── secrets/                    # Bitnami SealedSecrets (encrypted, safe in git)
└── network/                    # Network configuration
    └── unifi/                  # UniFi controller (flat manifests)
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

All resources are reconciled automatically by Flux from git.

## Prerequisites

- k3s cluster with kubeconfig
- Traefik ingress controller (bundled with k3s)
- DNS records pointing to the cluster
- `kubeseal` CLI for encrypting secrets

## Deploying

Managed by Flux CD — push to `main` and Flux reconciles automatically.

```bash
# Force reconcile
flux reconcile kustomization flux-system -n flux-system

# Check status
kubectl get helmrelease -A
kubectl get kustomization -A

# Seal a secret
kubectl create secret generic my-secret -n my-ns \
  --from-literal=key=value --dry-run=client -o yaml | \
  kubeseal --controller-name=sealed-secrets \
  --controller-namespace=sealed-secrets --format yaml > secrets/my-secret.yaml
```
