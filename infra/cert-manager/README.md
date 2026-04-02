# Cert-Manager Helm Chart

This Helm chart deploys cert-manager configuration including ClusterIssuer for Let's Encrypt.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- cert-manager CRDs installed in the cluster
- (Optional) External Secrets Operator for external secret management

## Installation

```bash
helm install cert-manager ./charts/cert-manager
```

## Configuration

### Basic Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `certManager.email` | Email address for Let's Encrypt registration | `admin@example.com` |
| `certManager.acmeServer` | ACME server URL | `https://acme-v02.api.letsencrypt.org/directory` |
| `certManager.ingressClass` | Ingress class for HTTP01 challenge | `nginx` |
| `clusterIssuer.name` | Name of the ClusterIssuer | `letsencrypt` |

### External Secrets Configuration

When using External Secrets Operator, you can store the email address in an external secret store:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `externalSecrets.enabled` | Enable external secrets integration | `true` |
| `externalSecrets.refreshInterval` | How often to refresh the secret | `1h` |
| `externalSecrets.secretStore` | Name of the SecretStore/ClusterSecretStore | `cluster-secret-store` |
| `externalSecrets.secretStoreKind` | Kind of secret store (SecretStore or ClusterSecretStore) | `ClusterSecretStore` |
| `externalSecrets.remoteRefs.email` | Path to email in external secret store | `wauhost/cert-manager/email` |

## Usage

### With External Secrets

1. Store your email address in your external secret store at the path specified in `externalSecrets.remoteRefs.email`

2. Install the chart:
```bash
helm install cert-manager ./charts/cert-manager \
  --set externalSecrets.enabled=true \
  --set externalSecrets.remoteRefs.email="my-org/cert-manager/email"
```

The chart will:
- Create an ExternalSecret that fetches the email from your secret store
- Deploy a post-install job that patches the ClusterIssuer with the retrieved email

### Without External Secrets

```bash
helm install cert-manager ./charts/cert-manager \
  --set externalSecrets.enabled=false \
  --set certManager.email="your-email@example.com"
```

## Certificate Creation

Once installed, you can create certificates by adding annotations to your Ingress resources:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt"
spec:
  tls:
  - hosts:
    - example.com
    secretName: example-com-tls
```

## Troubleshooting

### External Secret Not Working

1. Check if the ExternalSecret is created:
```bash
kubectl get externalsecret -n <namespace>
```

2. Check if the secret was created by the ExternalSecret:
```bash
kubectl get secret <release-name>-cert-manager-email-secret -n <namespace>
```

3. Check the patch job logs:
```bash
kubectl logs job/<release-name>-cert-manager-patch-issuer -n <namespace>
```

### Certificate Not Issuing

1. Check cert-manager logs:
```bash
kubectl logs -n cert-manager deployment/cert-manager
```

2. Check certificate status:
```bash
kubectl describe certificate <certificate-name>
```

3. Check ClusterIssuer status:
```bash
kubectl describe clusterissuer letsencrypt
```