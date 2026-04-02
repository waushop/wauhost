# mysql

Helm chart for a shared MySQL 8.0 instance. Currently serves the `vausiim` and `agrofort` databases.

## What it deploys

- `Deployment` running `mysql:8.0` (single replica)
- `PersistentVolumeClaim` for `/var/lib/mysql`
- `ClusterIP` Service on port 3306

The root password is read from a Kubernetes secret named `mysql-secret` (key: `mysql-root-password`). That secret is managed by Sealed Secrets and must exist before the pod starts.

The chart does not create databases or users — those must be set up manually or via init scripts outside this chart.

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `namespace` | Namespace to deploy into | `mysql` |
| `auth.rootPassword` | Root password (not used directly; managed by Sealed Secret) | `""` |
| `pvc.size` | Storage size | `10Gi` |
| `pvc.storageClass` | Storage class (empty = cluster default) | `""` |
| `pvc.accessMode` | PVC access mode | `ReadWriteOnce` |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `3306` |
| `resources.requests.cpu` | CPU request | `250m` |
| `resources.requests.memory` | Memory request | `512Mi` |
| `resources.limits.cpu` | CPU limit | `1` |
| `resources.limits.memory` | Memory limit | `1Gi` |
| `mysql.config` | Custom `[mysqld]` config block | See values.yaml |

The default MySQL config sets `innodb_buffer_pool_size=512M`, `max_connections=200`, `utf8mb4` charset, and enables the slow query log.

## Prerequisites

- Sealed Secret named `mysql-secret` with key `mysql-root-password` must exist in the target namespace

## Deploy

```bash
helm install mysql ./infra/mysql --namespace mysql --create-namespace
```

## Verify

```bash
kubectl get pods -n mysql
kubectl get pvc -n mysql
```

Test connectivity from within the cluster:

```bash
kubectl run -it --rm debug --image=mysql:8.0 --restart=Never -- \
  mysql -h mysql.mysql.svc.cluster.local -u root -p
```
