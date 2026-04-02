# Wauhost Kubernetes Infrastructure

Helm charts for running shared cluster infrastructure, services, and network configuration.

## Repository Structure

```
wauhost/
├── infra/                      # Cluster-wide infrastructure
│   ├── cert-manager/           # TLS certificates (ClusterIssuer + Let's Encrypt)
│   ├── sealed-secrets/         # Bitnami Sealed Secrets controller
│   └── mysql/                  # Shared MySQL instance
├── services/                   # Deployable service templates
│   └── ghost/                  # Ghost blog (deployed as multiple instances)
├── secrets/                    # Sealed secrets (encrypted, safe in git)
└── network/                    # Network / ingress configuration
    └── unifi/                  # UniFi controller networking
```

## Deployment Order

```
1. infra/sealed-secrets     → Sealed Secrets controller
2. infra/cert-manager       → ClusterIssuer for TLS
3. infra/mysql              → Shared database
4. secrets/                 → Apply sealed secrets
5. services/ghost           → Blog instances (one release per site)
6. network/unifi            → UniFi controller routing
```

## Prerequisites

- k3s cluster with kubeconfig
- Traefik ingress controller (bundled with k3s)
- DNS records pointing to the cluster

## Deploying

Each chart is deployed with Helm:

```bash
# Infrastructure
helm dependency build ./infra/sealed-secrets
helm install sealed-secrets ./infra/sealed-secrets -n sealed-secrets --create-namespace
helm install cert-manager ./infra/cert-manager -n cert-manager --create-namespace
helm install mysql ./infra/mysql -n mysql --create-namespace

# Secrets (after sealing with kubeseal, see secrets/README.md)
kubectl apply -f secrets/

# Ghost blog instance (one per site, with per-site values)
helm install my-blog ./services/ghost -n my-blog --create-namespace -f my-blog-values.yaml
```
