# Wauhost Helm Charts

Production-ready Helm charts for Kubernetes with enterprise security, monitoring, and automated operations.

## 🔐 Security First

All charts implement:
- **External Secrets Management**: No hardcoded credentials
- **RBAC**: Least privilege access
- **Network Policies**: Traffic segmentation
- **Pod Security**: Non-root, read-only filesystem where possible
- **Security Scanning**: Automated vulnerability detection

## 📦 Available Charts

### Storage Infrastructure

#### Longhorn
Distributed block storage system providing persistent volumes for applications.

```bash
# Install Longhorn
helm install longhorn ./charts/longhorn -n longhorn-system --create-namespace

# Upgrade Longhorn
helm upgrade longhorn ./charts/longhorn -n longhorn-system
```

Key features:
- 3-replica redundancy
- Automated snapshots and backups
- Multiple storage classes (standard, fast, backup)
- Web UI for management

#### MinIO
S3-compatible object storage for applications.

```bash
# Install MinIO
helm install minio ./charts/minio -n minio-system --create-namespace

# Upgrade MinIO
helm upgrade minio ./charts/minio -n minio-system
```

Key features:
- S3-compatible API
- Web console for management
- Automated bucket creation
- Backup automation to external storage

#### Storage Monitoring
Monitoring and alerting for storage infrastructure.

```bash
# Install Storage Monitoring
helm install storage-monitoring ./charts/storage-monitoring -n monitoring --create-namespace

# Upgrade Storage Monitoring
helm upgrade storage-monitoring ./charts/storage-monitoring -n monitoring
```

Features:
- Prometheus alerts for storage issues
- Grafana dashboards
- Backup health checks

### Application Charts

#### WordPress
WordPress deployment with MySQL backend.

```bash
helm install my-wordpress ./charts/wordpress -n wordpress --create-namespace
```

#### Ghost
Ghost blogging platform deployment.

```bash
helm install my-ghost ./charts/ghost -n ghost --create-namespace
```

#### MySQL
Standalone MySQL database deployment.

```bash
helm install my-mysql ./charts/mysql -n mysql --create-namespace
```

#### Cert-Manager
TLS certificate management using Let's Encrypt.

```bash
helm install cert-manager ./charts/cert-manager -n cert-manager --create-namespace
```

## Configuration

Each chart has a `values.yaml` file that can be customized. Create your own values file:

```yaml
# my-values.yaml
longhorn:
  backup:
    accessKeyId: "your-access-key"
    secretAccessKey: "your-secret-key"
  ui:
    host: "longhorn.yourdomain.com"
```

Then install with custom values:

```bash
helm install longhorn ./charts/longhorn -f my-values.yaml -n longhorn-system
```

## Storage Classes

After installing Longhorn, the following storage classes are available:

- `longhorn-standard` (default): General purpose storage
- `longhorn-fast`: High-performance storage with data locality
- `longhorn-backup`: Storage with automated backups

## MinIO Integration

To create credentials for applications to use MinIO:

1. Access MinIO console at the configured URL
2. Create a new user with appropriate policies
3. Generate access keys
4. Create Kubernetes secret:

```bash
kubectl create secret generic app-minio-credentials \
  --from-literal=accessKey=YOUR_ACCESS_KEY \
  --from-literal=secretKey=YOUR_SECRET_KEY \
  --from-literal=endpoint=https://images.yourdomain.com \
  -n your-namespace
```

## Monitoring

After installing storage-monitoring, import the dashboards in Grafana:

1. Access Grafana
2. Go to Dashboards → Import
3. The dashboards should be automatically available

## Backup and Recovery

### Longhorn Backups

Longhorn automatically creates snapshots and backups based on the configured schedule:
- Daily snapshots: 2:00 AM (7-day retention)
- Weekly snapshots: 3:00 AM Sunday (4-week retention)
- External backups: Daily at 4:00 AM, Weekly at 5:00 AM

### MinIO Backups

MinIO data is backed up daily at 3:00 AM to the configured external storage.

## Troubleshooting

### Check Longhorn status:
```bash
kubectl get pods -n longhorn-system
kubectl get volumes.longhorn.io -n longhorn-system
```

### Check MinIO status:
```bash
kubectl get pods -n minio-system
kubectl logs -n minio-system deployment/minio
```

### View storage alerts:
```bash
kubectl get configmap storage-alerts -n monitoring -o yaml
```

## 🔒 Security Configuration

### External Secrets Setup

1. **Install External Secrets Operator**:
```bash
helm install external-secrets ./external-secrets \
  -n external-secrets-system --create-namespace
```

2. **Configure your secret backend** (example for AWS Secrets Manager):
```yaml
# Create backend credentials
kubectl create secret generic awssm-secret \
  --from-literal=access-key=$AWS_ACCESS_KEY_ID \
  --from-literal=secret-access-key=$AWS_SECRET_ACCESS_KEY \
  -n external-secrets-system
```

3. **Create secrets in your backend**:
```bash
# Example for AWS Secrets Manager
aws secretsmanager create-secret \
  --name wauhost/minio/root-password \
  --secret-string "$(openssl rand -base64 32)"
```

### Security Best Practices

1. **Use External Secrets**: Never commit credentials to Git
2. **Enable Network Policies**: Restrict pod-to-pod communication
3. **RBAC**: Use service accounts with minimal permissions
4. **Pod Security**: Run as non-root, use security contexts
5. **Regular Updates**: Keep charts and images updated
6. **Audit Logs**: Enable Kubernetes audit logging
7. **Secret Rotation**: Implement regular credential rotation

## 🚀 Production Deployment Guide

### Pre-deployment Checklist

- [ ] External secrets backend configured
- [ ] All secrets created in backend
- [ ] Network policies reviewed
- [ ] Resource limits appropriate for workload
- [ ] Backup destination configured
- [ ] Monitoring endpoints accessible
- [ ] Ingress DNS configured

### Deployment Order

1. **Infrastructure**:
   ```bash
   # External Secrets
   helm install external-secrets ./external-secrets -n external-secrets-system --create-namespace
   
   # Cert Manager
   helm install cert-manager ./cert-manager -n cert-manager --create-namespace
   
   # Longhorn Storage
   helm install longhorn ./longhorn -n longhorn-system --create-namespace
   ```

2. **Storage & Databases**:
   ```bash
   # MinIO
   helm install minio ./minio -n minio-system --create-namespace
   
   # MySQL
   helm install mysql ./mysql -n mysql --create-namespace
   ```

3. **Applications**:
   ```bash
   # WordPress
   helm install wordpress ./wordpress -n wordpress --create-namespace
   
   # Ghost
   helm install ghost ./ghost -n ghost --create-namespace
   ```

4. **Monitoring**:
   ```bash
   # Storage Monitoring
   helm install storage-monitoring ./storage-monitoring -n monitoring --create-namespace
   ```

## 📊 Monitoring & Alerting

### Available Dashboards

- **Longhorn Dashboard**: Storage health, volume metrics, backup status
- **MinIO Dashboard**: Object storage metrics, bucket usage, API performance
- **MySQL Dashboard**: Query performance, connections, replication lag
- **Application Dashboards**: Request rates, error rates, response times

### Alert Rules

Critical alerts configured:
- Storage space < 10%
- Backup failures
- Pod restarts > 5 in 10 minutes
- Database connection failures
- Certificate expiry < 7 days

## 🔄 Backup & Recovery

### Automated Backups

All stateful services include automated backup:

| Service | Schedule | Retention | Destination |
|---------|----------|-----------|-------------|
| Longhorn Volumes | Daily 2AM | 30 days | S3 |
| MinIO Buckets | Daily 3AM | 30 days | External S3 |
| MySQL Databases | Daily 4AM | 30 days | MinIO |

### Recovery Procedures

1. **Volume Recovery**:
   ```bash
   # List available backups
   kubectl get backups.longhorn.io -n longhorn-system
   
   # Restore from backup
   kubectl apply -f restore-pvc.yaml
   ```

2. **Database Recovery**:
   ```bash
   # Download backup from MinIO
   mc cp minio/backups/mysql/latest.sql.gz ./
   
   # Restore to MySQL
   gunzip -c latest.sql.gz | mysql -h mysql-host -u root -p
   ```

## 🛠️ Operational Scripts

### Chart Validation
```bash
./scripts/validate-charts.sh
```

### Health Check
```bash
./scripts/check-health.sh
```

### Backup Verification
```bash
./scripts/verify-backups.sh
```

## 📚 Chart-Specific Documentation

Each chart includes:
- `README.md`: Detailed documentation
- `values.yaml`: Configuration options
- `values-example.yaml`: Example configurations
- `NOTES.txt`: Post-installation instructions

## 🆘 Support

- **Documentation**: [docs/](../docs/)
- **Examples**: [examples/](../examples/)
- **Issues**: [GitHub Issues](https://github.com/wauhost/infrastructure/issues)
- **Contact**: admin@wauhost.com