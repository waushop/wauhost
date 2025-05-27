# Longhorn Helm Chart

A production-ready deployment of Longhorn distributed block storage for Kubernetes with automated backups, monitoring, and security features.

## Overview

Longhorn is a lightweight, reliable, and powerful distributed block storage system for Kubernetes. This Helm chart deploys Longhorn with:
- Automated S3-compatible backup configuration
- External secrets management for credentials
- Multiple storage classes with different backup policies
- Web UI with authentication
- Prometheus monitoring integration
- Security hardening and RBAC

## Prerequisites

- Kubernetes 1.21+
- Helm 3.0+
- External Secrets Operator (if using external secrets)
- S3-compatible storage for backups (MinIO, AWS S3, etc.)
- Traefik ingress controller
- cert-manager for TLS certificates
- Open-iSCSI installed on all nodes

### Node Prerequisites

Install open-iscsi on all nodes:

```bash
# Ubuntu/Debian
sudo apt-get install open-iscsi

# CentOS/RHEL
sudo yum install iscsi-initiator-utils

# Start and enable the service
sudo systemctl enable iscsid
sudo systemctl start iscsid
```

## Installation

### Quick Start

```bash
# Deploy with external secrets (recommended)
helm install longhorn ./charts/longhorn \
  --namespace longhorn-system \
  --create-namespace \
  --set longhorn.backup.target="s3://longhorn-backup@eu-central/" \
  --set longhorn.ui.host=longhorn.example.com

# Deploy with local secrets (development only)
helm install longhorn ./charts/longhorn \
  --namespace longhorn-system \
  --create-namespace \
  --set externalSecrets.enabled=false \
  --set longhorn.ui.auth.users="admin:$2y$10$..." \
  --set longhorn.backup.secret.AWS_ACCESS_KEY_ID=your-key \
  --set longhorn.backup.secret.AWS_SECRET_ACCESS_KEY=your-secret
```

### Production Deployment

```bash
# Create namespace
kubectl create namespace longhorn-system

# Deploy with custom values
helm install longhorn ./charts/longhorn \
  --namespace longhorn-system \
  --values production-values.yaml
```

## Configuration

### Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `longhorn.defaultSettings.backupTarget` | S3 backup target URL | `""` |
| `longhorn.defaultSettings.backupTargetCredentialSecret` | Secret name for backup credentials | `"longhorn-backup-secret"` |
| `longhorn.defaultSettings.defaultReplicaCount` | Default number of replicas | `3` |
| `longhorn.defaultSettings.guaranteedEngineManagerCPU` | CPU guarantee for engine manager | `12` |
| `longhorn.defaultSettings.guaranteedReplicaManagerCPU` | CPU guarantee for replica manager | `12` |

### External Secrets Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `externalSecrets.enabled` | Enable external secrets integration | `true` |
| `externalSecrets.refreshInterval` | Secret refresh interval | `1h` |
| `externalSecrets.secretStore` | Secret store name | `cluster-secret-store` |
| `externalSecrets.secretStoreKind` | Secret store kind | `ClusterSecretStore` |
| `externalSecrets.remoteRefs.awsAccessKeyId` | AWS access key path in secret store | `wauhost/longhorn/aws-access-key-id` |
| `externalSecrets.remoteRefs.awsSecretAccessKey` | AWS secret key path in secret store | `wauhost/longhorn/aws-secret-access-key` |
| `externalSecrets.remoteRefs.awsEndpoints` | AWS endpoints path in secret store | `wauhost/longhorn/aws-endpoints` |
| `externalSecrets.remoteRefs.authUsers` | UI auth users path in secret store | `wauhost/longhorn/auth-users` |

### Backup Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `longhorn.backup.enabled` | Enable backup configuration | `true` |
| `longhorn.backup.target` | S3 backup target URL | `"s3://longhorn-backup@eu-central/"` |
| `longhorn.backup.endpoint` | S3 endpoint URL | `"https://s3.example.com"` |
| `longhorn.backup.region` | S3 region | `"eu-central"` |
| `longhorn.backup.secret.AWS_ACCESS_KEY_ID` | AWS access key (when not using external secrets) | `""` |
| `longhorn.backup.secret.AWS_SECRET_ACCESS_KEY` | AWS secret key (when not using external secrets) | `""` |
| `longhorn.backup.secret.AWS_ENDPOINTS` | AWS endpoints (when not using external secrets) | `""` |

### UI Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `longhorn.ui.enabled` | Enable Longhorn UI | `true` |
| `longhorn.ui.host` | UI hostname | `"longhorn.example.com"` |
| `longhorn.ui.ingressClassName` | Ingress class name | `"traefik"` |
| `longhorn.ui.clusterIssuer` | cert-manager cluster issuer | `"letsencrypt-prod"` |
| `longhorn.ui.auth.users` | Basic auth users (when not using external secrets) | `""` |

### Storage Classes

The chart creates multiple storage classes:

| Storage Class | Description | Replicas | Backup |
|--------------|-------------|----------|---------|
| `longhorn` | Default storage class | 3 | Hourly |
| `longhorn-single` | Single replica for non-critical data | 1 | Daily |
| `longhorn-critical` | Critical data with frequent backups | 3 | Every 6 hours |

## Examples

### Production Configuration with External Secrets

```yaml
# production-values.yaml
externalSecrets:
  enabled: true
  remoteRefs:
    awsAccessKeyId: production/longhorn/aws-access-key-id
    awsSecretAccessKey: production/longhorn/aws-secret-access-key
    awsEndpoints: production/longhorn/aws-endpoints
    authUsers: production/longhorn/ui-auth

longhorn:
  defaultSettings:
    defaultReplicaCount: 3
    guaranteedEngineManagerCPU: 20
    guaranteedReplicaManagerCPU: 20
    storageMinimalAvailablePercentage: 15
    
  backup:
    enabled: true
    target: "s3://prod-longhorn-backup@us-east-1/"
    endpoint: "https://s3.amazonaws.com"
    region: "us-east-1"
    
  ui:
    enabled: true
    host: longhorn.prod.example.com
    
  persistence:
    defaultClass: true
    defaultClassReplicaCount: 3
```

### Development Configuration

```yaml
# dev-values.yaml
externalSecrets:
  enabled: false

longhorn:
  defaultSettings:
    defaultReplicaCount: 1
    guaranteedEngineManagerCPU: 5
    guaranteedReplicaManagerCPU: 5
    
  backup:
    enabled: true
    target: "s3://dev-longhorn@minio/"
    endpoint: "http://minio.minio.svc.cluster.local:9000"
    secret:
      AWS_ACCESS_KEY_ID: minioadmin
      AWS_SECRET_ACCESS_KEY: minioadmin
      AWS_ENDPOINTS: "http://minio.minio.svc.cluster.local:9000"
      
  ui:
    enabled: true
    host: longhorn.dev.local
    auth:
      users: "admin:$2y$10$2vZJMTuf/b8iBRlYLhRLGO76HbcqHT79LXSS7g.k11m3x9k7BSUla"  # admin:admin
```

## Troubleshooting

### Longhorn Not Starting

1. Check pod status:
```bash
kubectl get pods -n longhorn-system
kubectl describe pod <pod-name> -n longhorn-system
```

2. Check if iSCSI is installed on nodes:
```bash
kubectl get nodes -o custom-columns=NAME:.metadata.name | tail -n +2 | \
  xargs -I {} kubectl debug node/{} -it --image=busybox -- \
  sh -c "chroot /host sh -c 'which iscsiadm'"
```

3. Check Longhorn manager logs:
```bash
kubectl logs -n longhorn-system -l app=longhorn-manager
```

### Volume Creation Issues

1. Check available storage on nodes:
```bash
kubectl get nodes -o custom-columns=NAME:.metadata.name,DISK:.status.allocatable.ephemeral-storage
```

2. Check Longhorn nodes status:
```bash
kubectl get nodes.longhorn.io -n longhorn-system
```

3. Check for failed volumes:
```bash
kubectl get volumes.longhorn.io -n longhorn-system | grep -v Running
```

### Backup Not Working

1. Check backup target configuration:
```bash
kubectl get settings.longhorn.io backup-target -n longhorn-system -o yaml
```

2. Verify backup credentials secret:
```bash
kubectl get secret longhorn-backup-secret -n longhorn-system
```

3. Test S3 connectivity:
```bash
kubectl run -it --rm debug --image=amazon/aws-cli --restart=Never -- \
  s3 ls s3://longhorn-backup --endpoint-url=https://s3.example.com
```

4. Check backup jobs:
```bash
kubectl get backups.longhorn.io -n longhorn-system
```

### UI Access Issues

1. Check ingress status:
```bash
kubectl get ingress -n longhorn-system
```

2. Verify auth secret:
```bash
kubectl get secret longhorn-auth -n longhorn-system
```

3. Test basic auth:
```bash
curl -u admin:password https://longhorn.example.com/
```

### External Secrets Not Working

1. Check ExternalSecret status:
```bash
kubectl get externalsecret -n longhorn-system
kubectl describe externalsecret longhorn-backup-credentials -n longhorn-system
```

2. Verify secrets were created:
```bash
kubectl get secrets -n longhorn-system | grep longhorn
```

## Maintenance

### Upgrade Longhorn

```bash
# Backup all volumes before upgrade
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: longhorn-backup-all
  namespace: longhorn-system
spec:
  template:
    spec:
      containers:
      - name: backup
        image: longhornio/longhorn-manager:v1.5.1
        command: ["sh", "-c", "longhorn-manager backup create-all"]
      restartPolicy: Never
EOF

# Upgrade
helm upgrade longhorn ./charts/longhorn \
  --namespace longhorn-system \
  --values production-values.yaml
```

### Node Maintenance

Before draining a node:

```bash
# Detach all volumes from the node
kubectl patch node <node-name> -p '{"spec":{"taints":[{"effect":"NoSchedule","key":"node.longhorn.io/drain","value":"true"}]}}'

# Wait for volumes to be detached
kubectl get volumes.longhorn.io -n longhorn-system -o wide | grep <node-name>

# Drain the node
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
```

### Disaster Recovery

```bash
# List all backups
kubectl get backups.longhorn.io -n longhorn-system

# Restore from backup
kubectl apply -f - <<EOF
apiVersion: longhorn.io/v1beta2
kind: Volume
metadata:
  name: restored-volume
  namespace: longhorn-system
spec:
  fromBackup: "s3://longhorn-backup@eu-central/backups/backup-xyz"
  size: "10Gi"
EOF
```

## Performance Tuning

### CPU Allocation

```yaml
longhorn:
  defaultSettings:
    # Increase for better performance
    guaranteedEngineManagerCPU: 25
    guaranteedReplicaManagerCPU: 25
```

### Network Performance

```yaml
longhorn:
  defaultSettings:
    # For 10Gbps network
    storageNetwork: "storage-network"
```

### Replica Placement

```yaml
longhorn:
  defaultSettings:
    # Spread replicas across zones
    replicaAutoBalance: "best-effort"
    replicaZoneSoftAntiAffinity: true
```

## Security Considerations

1. **Backup Credentials**: Always use external secrets for S3 credentials
2. **UI Authentication**: Use strong passwords and consider OAuth2 proxy
3. **Network Policies**: Enable network policies to restrict traffic
4. **Encryption**: Enable encryption at rest for sensitive data
5. **RBAC**: Limit access to Longhorn CRDs and API

## Additional Resources

- [Longhorn Documentation](https://longhorn.io/docs/)
- [Longhorn Best Practices](https://longhorn.io/docs/latest/best-practices/)
- [Longhorn Backup and Restore](https://longhorn.io/docs/latest/snapshots-and-backups/backup-and-restore/)
- [Storage Class Parameters](https://longhorn.io/docs/latest/references/storage-class-parameters/)