# UniFi Controller Deployment

This directory contains the configuration for deploying UniFi Controller to the Hetzner Kubernetes cluster.

## Overview

- **URL**: https://unifi.waushop.ee
- **Helm Chart**: `../charts/unifi`
- **Namespace**: `unifi`
- **Storage**: Hetzner Volumes (20Gi)
- **Ingress**: NGINX with Let's Encrypt SSL

## Features

- ✅ Automated SSL certificates via Let's Encrypt
- ✅ Persistent data storage
- ✅ UDP LoadBalancer for device discovery
- ✅ Health checks and monitoring
- ✅ Security hardening (non-root execution)
- ✅ GitOps deployment via GitHub Actions
- ✅ Automatic rollback on failure

## Deployment Process

### Automatic Deployment

The UniFi Controller is automatically deployed when:

1. **Code changes**: Push to `main` branch
2. **Manual trigger**: GitHub Actions workflow dispatch
3. **Pull requests**: Validation only (no deployment)

### Manual Deployment

```bash
# Install dependencies
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Deploy UniFi Controller
helm upgrade --install unifi ../charts/unifi \
  --namespace unifi \
  --create-namespace \
  --values values.yaml \
  --wait
```

## Configuration Details

### Access URLs

- **Web UI**: https://unifi.waushop.ee
- **API**: https://unifi.waushop.ee
- **Default Credentials**: Username `ubnt`, password set on first login

### Services

| Service | Type | Ports | Purpose |
|---------|------|-------|---------|
| `unifi` | ClusterIP | 8443,8080,6789 | Web UI, API, Speed Test |
| `unifi-udp` | LoadBalancer | 3478,5514,10001 | Device discovery |

### Storage

- **Size**: 20Gi
- **Type**: Hetzner Volumes (hcloud-volumes)
- **Mount**: `/unifi` (controller data)

### Environment

- **Timezone**: Europe/Tallinn
- **JVM Heap**: 1GB max, 512MB init
- **Security**: Non-root user (UID/GID 999)

## Monitoring and Troubleshooting

### Check Status

```bash
# Check pods
kubectl get pods -n unifi

# Check services
kubectl get services -n unifi

# Check ingress
kubectl get ingress -n unifi

# View logs
kubectl logs -n unifi -l app.kubernetes.io/name=unifi -f
```

### Common Issues

1. **Slow startup**: UniFi Controller takes 3-5 minutes to initialize
2. **Device discovery**: Ensure UDP LoadBalancer is running
3. **SSL issues**: Check cert-manager and DNS for unifi.waushop.ee

### Backup and Restore

```bash
# Backup data
kubectl exec -n unifi deployment/unifi -- tar -czf /tmp/backup.tar.gz -C /unifi .
kubectl cp -n unifi deployment/unifi:/tmp/backup.tar.gz ./unifi-backup.tar.gz

# Restore (stop service first)
kubectl scale deployment unifi -n unifi --replicas=0
kubectl cp ./unifi-backup.tar.gz -n unifi deployment/unifi:/tmp/backup.tar.gz
kubectl exec -n unifi deployment/unifi -- tar -xzf /tmp/backup.tar.gz -C /unifi
kubectl scale deployment unifi -n unifi --replicas=1
```

## Security

- **Non-root execution**: Container runs as UID 999
- **HTTPS only**: All traffic encrypted
- **Network policies**: Consider enabling for additional security
- **Secrets management**: Kubernetes secrets for sensitive data

## Maintenance

### Updates

Updates are automatically handled by GitHub Actions when:
- New UniFi version is specified in `values.yaml`
- Configuration changes are pushed to main branch

### Scaling

For larger networks, adjust resources in `values.yaml`:

```yaml
# For networks with 50+ devices
resources:
  requests:
    memory: 2Gi
    cpu: 1000m
  limits:
    memory: 4Gi
    cpu: 2000m
```

## Support

- **Documentation**: `../charts/unifi/README.md`
- **Issues**: Create GitHub issue in repository
- **Logs**: Check Kubernetes logs for troubleshooting
- **UniFi Community**: https://community.ui.com/