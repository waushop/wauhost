# cert-manager

Helm chart that deploys a Let's Encrypt `ClusterIssuer` for cert-manager. Uses HTTP01 challenges via Traefik.

## Prerequisites

- cert-manager installed in the cluster with its CRDs
- Traefik ingress controller

## What it deploys

- A `ClusterIssuer` named `letsencrypt` (configurable) pointing at the Let's Encrypt ACME v2 API
- Optionally: a post-install/post-upgrade Job that patches the ClusterIssuer email from a Kubernetes secret, along with the ServiceAccount, ClusterRole, and ClusterRoleBinding it needs

The patch job is only created when `externalSecrets.enabled=true`. It waits for a secret named `<release>-email-secret` to exist, reads the `email` key from it, and patches the ClusterIssuer via `kubectl`.

Secrets (i.e. the email secret the job reads from) are managed externally — for example via Sealed Secrets — and must exist before the job runs.

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `certManager.email` | Email for Let's Encrypt registration | `admin@example.com` |
| `certManager.acmeServer` | ACME server URL | `https://acme-v02.api.letsencrypt.org/directory` |
| `certManager.ingressClass` | Ingress class for HTTP01 solver | `traefik` |
| `clusterIssuer.name` | Name of the ClusterIssuer resource | `letsencrypt` |
| `externalSecrets.enabled` | Deploy the email patch job | `false` |
| `image.repository` | Image used by the patch job | `bitnami/kubectl` |
| `image.tag` | Image tag | `latest` |

## Deploy

```bash
helm install cert-manager ./infra/cert-manager \
  --namespace cert-manager \
  --set certManager.email="your@email.com"
```

If the email is injected from a secret (e.g. via Sealed Secrets), enable the patch job:

```bash
helm install cert-manager ./infra/cert-manager \
  --namespace cert-manager \
  --set externalSecrets.enabled=true
```

The secret `<release>-email-secret` with key `email` must exist in the same namespace before the post-install job runs.

## Using the issuer

Add this annotation to any Ingress:

```yaml
cert-manager.io/cluster-issuer: "letsencrypt"
```

And a `tls` block with the desired secret name. cert-manager will handle certificate issuance automatically.
