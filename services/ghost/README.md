# ghost

Reusable Helm chart for deploying Ghost blog instances. Each site gets its own release with a per-site values file.

## What it deploys

- `Deployment` running Ghost 5 on Node.js
- `Service` (ClusterIP, port 80 -> 2368)
- `Ingress` via Traefik with TLS (cert-manager)
- `PersistentVolumeClaim` for Ghost content
- `NetworkPolicy` (optional)

Database and mail passwords are read from a Kubernetes Secret named `<release>-secrets`. That secret is managed by Sealed Secrets and must exist before the pod starts.

## Deploy a new site

1. Create a Sealed Secret with the DB and mail passwords in the target namespace
2. Create a values file for the site:

```yaml
# my-blog-values.yaml
namespace: my-blog
releaseName: my-blog
host: my-blog.com

database:
  user: my_blog
  database: my_blog

mail:
  from: "noreply@my-blog.com"
  options:
    auth:
      user: "postmaster@mg.my-blog.com"
```

3. Deploy:

```bash
helm install my-blog ./services/ghost -n my-blog --create-namespace -f my-blog-values.yaml
```

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `namespace` | Target namespace | `""` |
| `releaseName` | Release name for PVC/TLS naming | `""` |
| `host` | Blog hostname | `example.com` |
| `replicaCount` | Replicas | `1` |
| `image.tag` | Ghost version | `5` |
| `database.host` | MySQL host | `mysql.mysql.svc.cluster.local` |
| `database.user` | MySQL user | `""` |
| `database.database` | MySQL database | `""` |
| `pvc.size` | Content storage size | `5Gi` |
| `mail.enabled` | Enable SMTP | `true` |
| `mail.from` | From address | `""` |
| `mail.options.host` | SMTP host | `smtp.eu.mailgun.org` |
| `ingress.className` | Ingress class | `traefik` |
| `networkPolicy.enabled` | Enable network policy | `false` |
| `resources.requests.memory` | Memory request | `256Mi` |
| `resources.limits.memory` | Memory limit | `512Mi` |

## Prerequisites

- Sealed Secret `<release>-secrets` with keys `database__connection__password` and `mail__options__auth__pass`
- MySQL database and user created in the shared MySQL instance
- cert-manager ClusterIssuer named `letsencrypt`
