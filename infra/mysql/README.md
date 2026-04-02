# MySQL Helm Chart

A production-ready MySQL 8.0 deployment for Kubernetes with security hardening, automated backups, and external secrets management.

## Overview

This Helm chart deploys MySQL 8.0 with:
- External secrets management for credentials
- Persistent storage for data
- Security hardening with pod security contexts
- Resource limits and health checks
- Support for custom configuration
- Automated backup capabilities
- Multiple database and user creation

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- External Secrets Operator (if using external secrets)
- Persistent storage provisioner
- Sufficient resources (minimum 2GB RAM recommended)

## Installation

### Quick Start

```bash
# Deploy with external secrets (recommended)
helm install mysql ./charts/mysql \
  --namespace mysql \
  --create-namespace

# Deploy with local secrets (development only)
helm install mysql ./charts/mysql \
  --namespace mysql \
  --create-namespace \
  --set externalSecrets.enabled=false \
  --set mysql.auth.rootPassword=rootpassword123 \
  --set mysql.auth.password=userpassword123
```

### Production Deployment

```bash
# Create namespace
kubectl create namespace mysql

# Deploy with custom values
helm install mysql ./charts/mysql \
  --namespace mysql \
  --values production-values.yaml
```

## Configuration

### Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nameOverride` | Override chart name | `""` |
| `fullnameOverride` | Override full chart name | `""` |
| `replicaCount` | Number of MySQL replicas (only 1 supported) | `1` |

### Image Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | MySQL image repository | `mysql` |
| `image.tag` | MySQL image tag | `"8.0"` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |

### External Secrets Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `externalSecrets.enabled` | Enable external secrets integration | `true` |
| `externalSecrets.refreshInterval` | Secret refresh interval | `1h` |
| `externalSecrets.secretStore` | Secret store name | `cluster-secret-store` |
| `externalSecrets.secretStoreKind` | Secret store kind | `ClusterSecretStore` |
| `externalSecrets.remoteRefs.rootPassword` | Root password path in secret store | `wauhost/mysql/root-password` |
| `externalSecrets.remoteRefs.password` | User password path in secret store | `wauhost/mysql/user-password` |
| `externalSecrets.remoteRefs.replicationPassword` | Replication password path | `wauhost/mysql/replication-password` |

### MySQL Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `mysql.auth.rootPassword` | Root password (when not using external secrets) | `""` |
| `mysql.auth.database` | Default database to create | `"appdb"` |
| `mysql.auth.username` | Default username to create | `"appuser"` |
| `mysql.auth.password` | User password (when not using external secrets) | `""` |

### Storage Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `persistence.enabled` | Enable persistent storage | `true` |
| `persistence.storageClass` | Storage class name | `""` |
| `persistence.accessMode` | PVC access mode | `ReadWriteOnce` |
| `persistence.size` | Storage size | `10Gi` |
| `persistence.dataDir` | MySQL data directory | `/var/lib/mysql` |

### Service Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `3306` |
| `service.nodePort` | Node port (if type is NodePort) | `""` |

### Resource Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `resources.limits.cpu` | CPU limit | `1000m` |
| `resources.limits.memory` | Memory limit | `2Gi` |
| `resources.requests.cpu` | CPU request | `500m` |
| `resources.requests.memory` | Memory request | `1Gi` |

### Security Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `podSecurityContext.fsGroup` | Pod security context fsGroup | `999` |
| `podSecurityContext.runAsUser` | Pod security context runAsUser | `999` |
| `podSecurityContext.runAsNonRoot` | Run as non-root user | `true` |
| `securityContext.allowPrivilegeEscalation` | Allow privilege escalation | `false` |
| `securityContext.readOnlyRootFilesystem` | Read-only root filesystem | `false` |
| `securityContext.runAsNonRoot` | Container runs as non-root | `true` |
| `securityContext.runAsUser` | Container user ID | `999` |

### MySQL Custom Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `mysql.config` | Custom MySQL configuration | See values.yaml |

## Examples

### Production Configuration with External Secrets

```yaml
# production-values.yaml
nameOverride: "mysql-prod"

image:
  tag: "8.0.35"

externalSecrets:
  enabled: true
  remoteRefs:
    rootPassword: production/mysql/root-password
    password: production/mysql/app-password
    replicationPassword: production/mysql/replication-password

mysql:
  auth:
    database: "production_db"
    username: "prod_app"
  config: |
    [mysqld]
    default_authentication_plugin=mysql_native_password
    skip-name-resolve
    max_connections=500
    innodb_buffer_pool_size=1G
    innodb_log_file_size=256M
    slow_query_log=1
    long_query_time=2
    log_error=/var/lib/mysql/error.log

persistence:
  enabled: true
  storageClass: "fast-ssd"
  size: 100Gi

resources:
  limits:
    cpu: 4000m
    memory: 8Gi
  requests:
    cpu: 2000m
    memory: 4Gi

backup:
  enabled: true
  schedule: "0 2 * * *"
  retention: 30
```

### Development Configuration

```yaml
# dev-values.yaml
nameOverride: "mysql-dev"

externalSecrets:
  enabled: false

mysql:
  auth:
    rootPassword: "devroot123"
    database: "devdb"
    username: "devuser"
    password: "devpass123"
  config: |
    [mysqld]
    default_authentication_plugin=mysql_native_password
    skip-name-resolve
    max_connections=100

persistence:
  size: 5Gi

resources:
  limits:
    cpu: 500m
    memory: 1Gi
  requests:
    cpu: 250m
    memory: 512Mi
```

### Multiple Database Configuration

```yaml
# multi-db-values.yaml
mysql:
  auth:
    rootPassword: "rootpass"
    database: "primary_db"
    username: "primary_user"
    password: "primary_pass"
  
  additionalDatabases:
    - name: "analytics_db"
      user: "analytics_user"
      password: "analytics_pass"
    - name: "reporting_db"
      user: "reporting_user"
      password: "reporting_pass"
```

## Troubleshooting

### MySQL Pod Not Starting

1. Check pod status:
```bash
kubectl get pods -n mysql
kubectl describe pod mysql-0 -n mysql
```

2. Check logs:
```bash
kubectl logs -n mysql mysql-0
kubectl logs -n mysql mysql-0 --previous  # if pod is restarting
```

3. Common issues:
   - Insufficient resources
   - PVC not bound
   - Invalid configuration

### Connection Issues

1. Test connection from within cluster:
```bash
kubectl run -it --rm debug --image=mysql:8.0 --restart=Never -- \
  mysql -h mysql.mysql.svc.cluster.local -u root -p
```

2. Check service:
```bash
kubectl get svc -n mysql
kubectl get endpoints -n mysql
```

3. Verify credentials:
```bash
kubectl get secret mysql-credentials -n mysql -o jsonpath='{.data.mysql-root-password}' | base64 -d
```

### Performance Issues

1. Check slow query log:
```bash
kubectl exec -n mysql mysql-0 -- \
  mysql -u root -p -e "SHOW VARIABLES LIKE 'slow_query%';"
```

2. View process list:
```bash
kubectl exec -n mysql mysql-0 -- \
  mysql -u root -p -e "SHOW PROCESSLIST;"
```

3. Check InnoDB status:
```bash
kubectl exec -n mysql mysql-0 -- \
  mysql -u root -p -e "SHOW ENGINE INNODB STATUS\G"
```

### External Secrets Not Working

1. Check ExternalSecret:
```bash
kubectl get externalsecret -n mysql
kubectl describe externalsecret mysql-credentials -n mysql
```

2. Verify secret creation:
```bash
kubectl get secret mysql-credentials -n mysql
```

3. Check External Secrets Operator logs:
```bash
kubectl logs -n external-secrets deployment/external-secrets
```

### Storage Issues

1. Check PVC status:
```bash
kubectl get pvc -n mysql
kubectl describe pvc mysql-data -n mysql
```

2. Check disk usage:
```bash
kubectl exec -n mysql mysql-0 -- df -h /var/lib/mysql
```

3. Check MySQL data directory:
```bash
kubectl exec -n mysql mysql-0 -- ls -la /var/lib/mysql
```

## Maintenance

### Backup Database

```bash
# Manual backup
kubectl exec -n mysql mysql-0 -- \
  mysqldump -u root -p --all-databases --single-transaction > backup.sql

# Backup specific database
kubectl exec -n mysql mysql-0 -- \
  mysqldump -u root -p mydb --single-transaction > mydb-backup.sql
```

### Restore Database

```bash
# Restore from backup
kubectl exec -i -n mysql mysql-0 -- \
  mysql -u root -p < backup.sql

# Restore specific database
kubectl exec -i -n mysql mysql-0 -- \
  mysql -u root -p mydb < mydb-backup.sql
```

### Update MySQL Configuration

```bash
# Edit configmap
kubectl edit configmap mysql-config -n mysql

# Restart MySQL to apply changes
kubectl rollout restart deployment mysql -n mysql
```

### Monitor Replication (if configured)

```bash
# Check replication status
kubectl exec -n mysql mysql-0 -- \
  mysql -u root -p -e "SHOW SLAVE STATUS\G"

# Check binary log position
kubectl exec -n mysql mysql-0 -- \
  mysql -u root -p -e "SHOW MASTER STATUS;"
```

## Performance Tuning

### Memory Configuration

```yaml
mysql:
  config: |
    [mysqld]
    # Buffer pool (70-80% of available memory)
    innodb_buffer_pool_size=6G
    innodb_buffer_pool_instances=4
    
    # Log files
    innodb_log_file_size=1G
    innodb_log_buffer_size=256M
    
    # Other buffers
    key_buffer_size=256M
    sort_buffer_size=4M
    read_buffer_size=4M
    join_buffer_size=4M
```

### Connection Optimization

```yaml
mysql:
  config: |
    [mysqld]
    max_connections=1000
    max_connect_errors=10000
    connect_timeout=30
    wait_timeout=600
    interactive_timeout=600
```

### Query Optimization

```yaml
mysql:
  config: |
    [mysqld]
    query_cache_type=1
    query_cache_size=256M
    query_cache_limit=2M
    
    # Temp tables
    tmp_table_size=256M
    max_heap_table_size=256M
```

## Security Best Practices

1. **Password Management**: Always use external secrets for production
2. **Network Security**: Use network policies to restrict access
3. **SSL/TLS**: Enable SSL for client connections
4. **User Privileges**: Create users with minimal required privileges
5. **Audit Logging**: Enable audit logs for compliance

### Enable SSL

```yaml
mysql:
  ssl:
    enabled: true
    certificatesSecret: mysql-ssl-certs
  config: |
    [mysqld]
    require_secure_transport=ON
```

### Create Restricted User

```bash
kubectl exec -n mysql mysql-0 -- mysql -u root -p <<EOF
CREATE USER 'app_user'@'%' IDENTIFIED BY 'secure_password';
GRANT SELECT, INSERT, UPDATE, DELETE ON mydb.* TO 'app_user'@'%';
FLUSH PRIVILEGES;
EOF
```

## Monitoring

### Prometheus Metrics

```yaml
metrics:
  enabled: true
  image: prom/mysqld-exporter:v0.14.0
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
```

### Health Checks

The chart includes comprehensive health checks:
- **Liveness Probe**: Ensures MySQL process is running
- **Readiness Probe**: Verifies MySQL is accepting connections
- **Startup Probe**: Allows time for initial startup

## Additional Resources

- [MySQL 8.0 Documentation](https://dev.mysql.com/doc/refman/8.0/en/)
- [MySQL Performance Tuning](https://dev.mysql.com/doc/refman/8.0/en/optimization.html)
- [MySQL Security](https://dev.mysql.com/doc/refman/8.0/en/security.html)
- [MySQL Backup and Recovery](https://dev.mysql.com/doc/refman/8.0/en/backup-and-recovery.html)