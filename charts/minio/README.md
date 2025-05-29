# MinIO Helm Chart

A production-ready MinIO deployment for Kubernetes with automated backups, monitoring, security features, and high availability support.

## Overview

MinIO is a high-performance, S3-compatible object storage system. This Helm chart deploys MinIO with:
- External secrets management for credentials
- Automated backup to external S3 storage
- Dual ingress for API and Console access
- Init job for bucket creation
- Prometheus monitoring integration
- Security hardening with pod security contexts
- Resource limits and requests

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- External Secrets Operator (if using external secrets)
- Traefik ingress controller
- cert-manager for TLS certificates
- Persistent storage provisioner

## Installation

### Quick Start

```bash
# Deploy with external secrets (recommended)
helm install minio ./charts/minio \
  --namespace minio \
  --create-namespace \
  --set minio.api.host=s3.example.com \
  --set minio.console.host=minio.example.com

# Deploy with local secrets (development only)
helm install minio ./charts/minio \
  --namespace minio \
  --create-namespace \
  --set externalSecrets.enabled=false \
  --set minio.auth.rootUser=admin \
  --set minio.auth.rootPassword=changeme123 \
  --set backup.credentials.accessKey=backup-key \
  --set backup.credentials.secretKey=backup-secret
```

### Production Deployment

```bash
# Create namespace
kubectl create namespace minio

# Deploy with custom values
helm install minio ./charts/minio \
  --namespace minio \
  --values production-values.yaml
```

## Configuration

### Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nameOverride` | Override chart name | `""` |
| `fullnameOverride` | Override full chart name | `""` |
| `minio.replicas` | Number of MinIO instances | `1` |
| `minio.mode` | MinIO mode (standalone or distributed) | `standalone` |

### External Secrets Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `externalSecrets.enabled` | Enable external secrets integration | `true` |
| `externalSecrets.refreshInterval` | Secret refresh interval | `1h` |
| `externalSecrets.secretStore` | Secret store name | `cluster-secret-store` |
| `externalSecrets.secretStoreKind` | Secret store kind | `ClusterSecretStore` |
| `externalSecrets.remoteRefs.rootUser` | Root user path in secret store | `wauhost/minio/root-user` |
| `externalSecrets.remoteRefs.rootPassword` | Root password path in secret store | `wauhost/minio/root-password` |
| `externalSecrets.remoteRefs.backupAccessKey` | Backup access key path | `wauhost/minio/backup-access-key` |
| `externalSecrets.remoteRefs.backupSecretKey` | Backup secret key path | `wauhost/minio/backup-secret-key` |

### MinIO Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `minio.image.repository` | MinIO image repository | `minio/minio` |
| `minio.image.tag` | MinIO image tag | `RELEASE.2024-01-01T00-00-00Z` |
| `minio.image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `minio.auth.rootUser` | Root username (when not using external secrets) | `""` |
| `minio.auth.rootPassword` | Root password (when not using external secrets) | `""` |

### Storage Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `minio.persistence.enabled` | Enable persistent storage | `true` |
| `minio.persistence.size` | Storage size | `50Gi` |
| `minio.persistence.storageClass` | Storage class name | `""` |
| `minio.persistence.accessMode` | PVC access mode | `ReadWriteOnce` |

### Resource Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `minio.resources.requests.memory` | Memory request | `"2Gi"` |
| `minio.resources.requests.cpu` | CPU request | `"1000m"` |
| `minio.resources.limits.memory` | Memory limit | `"4Gi"` |
| `minio.resources.limits.cpu` | CPU limit | `"2000m"` |

### Ingress Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `minio.api.host` | API endpoint hostname | `images.example.com` |
| `minio.api.ingressClassName` | API ingress class | `traefik` |
| `minio.api.clusterIssuer` | cert-manager issuer for API | `letsencrypt` |
| `minio.console.host` | Console hostname | `minio-console.example.com` |
| `minio.console.ingressClassName` | Console ingress class | `traefik` |
| `minio.console.clusterIssuer` | cert-manager issuer for console | `letsencrypt` |

### Backup Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `backup.enabled` | Enable automated backups | `true` |
| `backup.schedule` | Backup cron schedule | `"0 2 * * *"` |
| `backup.destination` | S3 destination for backups | `s3://backup-bucket/minio/` |
| `backup.endpoint` | S3 endpoint for backups | `https://s3.amazonaws.com` |
| `backup.credentials.accessKey` | Backup S3 access key (when not using external secrets) | `""` |
| `backup.credentials.secretKey` | Backup S3 secret key (when not using external secrets) | `""` |

### Init Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `init.enabled` | Enable init job for bucket creation | `true` |
| `init.buckets` | List of buckets to create | `["images", "backups", "documents"]` |

## Configuration

The chart can be configured using the following approaches:

### Option 1: Command Line Parameters
```bash
helm install minio ./charts/minio \
  --namespace minio \
  --create-namespace \
  --set minio.api.host=s3.example.com \
  --set minio.console.host=minio.example.com
```

### Option 2: Custom Values File
```bash
# Create your custom values
cp charts/minio/values.yaml my-values.yaml
# Edit my-values.yaml with your settings
helm install minio ./charts/minio \
  --namespace minio \
  --create-namespace \
  --values my-values.yaml
```

## Troubleshooting

### MinIO Pod Not Starting

1. Check pod status:
```bash
kubectl get pods -n minio
kubectl describe pod <pod-name> -n minio
```

2. Check logs:
```bash
kubectl logs -n minio deployment/minio
```

3. Verify PVC is bound:
```bash
kubectl get pvc -n minio
```

### Connection Issues

1. Test S3 API endpoint:
```bash
curl -I https://s3.example.com/minio/health/live
```

2. Test console access:
```bash
curl -I https://minio-console.example.com/
```

3. Check service endpoints:
```bash
kubectl get svc -n minio
kubectl get endpoints -n minio
```

### Authentication Issues

1. Verify credentials secret:
```bash
kubectl get secret minio-credentials -n minio
kubectl get secret minio-credentials -n minio -o jsonpath='{.data.MINIO_ROOT_USER}' | base64 -d
```

2. Test with MinIO client:
```bash
mc alias set myminio https://s3.example.com minioadmin minioadmin
mc admin info myminio
```

### External Secrets Not Working

1. Check ExternalSecret status:
```bash
kubectl get externalsecret -n minio
kubectl describe externalsecret minio-credentials -n minio
```

2. Check secret creation:
```bash
kubectl get secrets -n minio
```

3. Verify secret store:
```bash
kubectl logs -n external-secrets deployment/external-secrets
```

### Backup Issues

1. Check backup cronjob:
```bash
kubectl get cronjob -n minio
kubectl describe cronjob minio-backup -n minio
```

2. Check last backup job:
```bash
kubectl get jobs -n minio | grep backup
kubectl logs job/minio-backup-<timestamp> -n minio
```

3. Test backup manually:
```bash
kubectl create job --from=cronjob/minio-backup test-backup -n minio
```

### Storage Issues

1. Check disk usage:
```bash
kubectl exec -n minio deployment/minio -- df -h /data
```

2. Check MinIO storage info:
```bash
kubectl exec -n minio deployment/minio -- mc admin info local
```

3. Verify distributed setup (if applicable):
```bash
kubectl exec -n minio deployment/minio -- mc admin heal local
```

## Operations

### Create User

```bash
# Access MinIO pod
kubectl exec -it -n minio deployment/minio -- sh

# Create user
mc admin user add local newuser newpassword

# Attach policy
mc admin policy attach local readwrite --user=newuser
```

### Create Service Account

```bash
# Create service account for application access
kubectl exec -n minio deployment/minio -- \
  mc admin user svcacct add local minioadmin \
  --access-key "app-access-key" \
  --secret-key "app-secret-key"
```

### Monitor Storage

```bash
# Check server info
kubectl exec -n minio deployment/minio -- mc admin info local

# Check disk usage
kubectl exec -n minio deployment/minio -- mc admin disk local

# Monitor bandwidth
kubectl exec -n minio deployment/minio -- mc admin bandwidth local
```

### Backup and Restore

#### Manual Backup

```bash
# Backup all buckets
kubectl exec -n minio deployment/minio -- \
  mc mirror local/images s3://backup-bucket/minio/images/

# Backup specific bucket with versioning
kubectl exec -n minio deployment/minio -- \
  mc mirror --preserve local/documents s3://backup-bucket/minio/documents/
```

#### Restore from Backup

```bash
# Restore bucket
kubectl exec -n minio deployment/minio -- \
  mc mirror s3://backup-bucket/minio/images/ local/images
```

## Performance Tuning

### Memory Configuration

```yaml
minio:
  env:
    - name: MINIO_CACHE
      value: "on"
    - name: MINIO_CACHE_SIZE
      value: "10GB"
    - name: MINIO_CACHE_WATERMARK_LOW
      value: "70"
    - name: MINIO_CACHE_WATERMARK_HIGH
      value: "90"
```

### Connection Tuning

```yaml
minio:
  env:
    - name: MINIO_API_REQUESTS_MAX
      value: "10000"
    - name: MINIO_API_REQUESTS_DEADLINE
      value: "30s"
```

### Storage Optimization

```yaml
minio:
  env:
    - name: MINIO_STORAGE_CLASS_STANDARD
      value: "EC:2"  # Erasure coding
    - name: MINIO_STORAGE_CLASS_RRS
      value: "EC:1"
```

## Security Considerations

1. **Credentials**: Always use external secrets for production
2. **TLS**: Enable TLS for all endpoints
3. **Network Policies**: Restrict traffic between MinIO and clients
4. **Access Control**: Use IAM policies for fine-grained access
5. **Encryption**: Enable server-side encryption for sensitive data
6. **Audit Logging**: Enable audit logs for compliance

### Enable Encryption

```yaml
minio:
  env:
    - name: MINIO_KMS_SECRET_KEY
      value: "my-minio-key:6368616e676520746869732070617373776f726420746f206120736563726574"
```

### Enable Audit Logging

```yaml
minio:
  env:
    - name: MINIO_LOGGER_WEBHOOK_ENABLE_PRIMARY
      value: "on"
    - name: MINIO_LOGGER_WEBHOOK_ENDPOINT_PRIMARY
      value: "http://audit-logger:8080/minio/audit"
```

## Additional Resources

- [MinIO Documentation](https://min.io/docs/minio/kubernetes/upstream/)
- [MinIO Client Guide](https://min.io/docs/minio/linux/reference/minio-mc.html)
- [MinIO Security Best Practices](https://min.io/docs/minio/linux/administration/identity-access-management.html)
- [S3 API Reference](https://docs.aws.amazon.com/AmazonS3/latest/API/Welcome.html)