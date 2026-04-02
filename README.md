# Wauhost Kubernetes Infrastructure

Helm charts for running shared cluster infrastructure, services, and network configuration.

## Repository Structure

```
wauhost/
├── infra/                      # Cluster-wide infrastructure
│   ├── cert-manager/           # TLS certificates (ClusterIssuer + Let's Encrypt)
│   ├── external-secrets/       # Vault + External Secrets Operator
│   └── mysql/                  # Shared MySQL instance
├── services/                   # Deployable service templates
│   └── ghost/                  # Ghost blog (deployed as multiple instances)
└── network/                    # Network / ingress configuration
    └── unifi/                  # UniFi controller networking
```

## Deployment Order

```
1. infra/external-secrets   → Vault + ClusterSecretStore
2. infra/cert-manager       → ClusterIssuer for TLS
3. infra/mysql              → Shared database
4. services/ghost           → Blog instances (one release per site)
5. network/unifi            → UniFi controller routing
```

## Prerequisites

- k3s cluster with kubeconfig
- Traefik ingress controller (bundled with k3s)
- HashiCorp Vault instance
- DNS records pointing to the cluster

## Deploying

Each chart is deployed with Helm:

```bash
# Infrastructure
helm install external-secrets ./infra/external-secrets -n vault --create-namespace
helm install cert-manager ./infra/cert-manager -n cert-manager --create-namespace
helm install mysql ./infra/mysql -n mysql --create-namespace

# Ghost blog instance (one per site, with per-site values)
helm install my-blog ./services/ghost -n my-blog --create-namespace -f my-blog-values.yaml
```

## Contact

Maintained by Siim Vaus — siim@wauhost.ee
