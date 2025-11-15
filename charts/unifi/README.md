# UniFi Controller Helm Chart

This Helm chart deploys the UniFi Network Controller to Kubernetes. The UniFi Controller allows you to manage UniFi network devices (Access Points, Switches, Routers, etc.) from a central web interface.

## Features

- 🚀 Easy deployment to any Kubernetes cluster
- 🔒 Security-focused configuration (non-root execution, HTTPS support)
- 📊 Built-in monitoring and health checks
- 💾 Persistent storage for configuration and data
- 🌐 Ingress support for external access
- 🔄 Horizontal Pod Autoscaling support
- 🛡️ Network policy support
- 📋 Comprehensive configuration options

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- Persistent storage (ReadWriteOnce)
- (Optional) Ingress controller for external access
- (Optional) LoadBalancer support for UDP services

## Installation

### Add the repository (if not already added)

```bash
helm repo add wauhost https://charts.wauhost.com
helm repo update
```

### Install the chart

```bash
helm install unifi wauhost/unifi
```

### Install with custom values

```bash
helm install unifi wauhost/unifi -f values.yaml
```

## Configuration

The following table lists the configurable parameters of the UniFi chart and their default values.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | UniFi image repository | `jacobalberty/unifi` |
| `image.tag` | UniFi image tag | `v7.1.68` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `replicaCount` | Number of UniFi replicas | `1` |
| `resources.requests.memory` | Memory request | `1Gi` |
| `resources.requests.cpu` | CPU request | `500m` |
| `resources.limits.memory` | Memory limit | `2Gi` |
| `resources.limits.cpu` | CPU limit | `1000m` |
| `persistence.data.enabled` | Enable persistent storage | `true` |
| `persistence.data.size` | Persistent volume size | `20Gi` |
| `persistence.data.storageClass` | Storage class for PVC | `""` (default) |
| `service.main.type` | Service type | `ClusterIP` |
| `service.udp.enabled` | Enable UDP LoadBalancer service | `false` |
| `ingress.main.enabled` | Enable Ingress | `false` |
| `ingress.main.hosts` | Ingress hosts | `[]` |
| `env.TZ` | Timezone | `UTC` |
| `env.JVM_MAX_HEAP_SIZE` | Maximum JVM heap size | `1024M` |

### Persistence

The UniFi Controller requires persistent storage for configuration and data. By default, a 20Gi PVC is created:

```yaml
persistence:
  data:
    enabled: true
    size: 20Gi
    storageClass: fast-ssd  # Optional: specify your storage class
```

### Ingress Configuration

To expose the UniFi Controller externally via Ingress:

```yaml
ingress:
  main:
    enabled: true
    annotations:
      nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
    hosts:
      - host: unifi.example.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: unifi-tls
        hosts:
          - unifi.example.com
```

### UDP Services

For device discovery and communication, enable the UDP LoadBalancer service:

```yaml
service:
  udp:
    enabled: true
    type: LoadBalancer
    loadBalancerIP: 192.168.1.100  # Optional static IP
```

### Resource Management

Adjust resources based on your network size:

```yaml
# Small networks (1-10 devices)
resources:
  requests:
    memory: 512Mi
    cpu: 250m
  limits:
    memory: 1Gi
    cpu: 500m

# Medium networks (10-50 devices)
resources:
  requests:
    memory: 1Gi
    cpu: 500m
  limits:
    memory: 2Gi
    cpu: 1000m

# Large networks (50+ devices)
resources:
  requests:
    memory: 2Gi
    cpu: 1000m
  limits:
    memory: 4Gi
    cpu: 2000m
```

## Port Configuration

The UniFi Controller uses multiple ports for different functions:

| Port | Protocol | Purpose | Service |
|------|----------|---------|---------|
| 8443 | HTTPS | Web UI & API | main |
| 8080 | TCP | Device communication | main |
| 6789 | TCP | Speed test | main |
| 3478 | UDP | STUN/Discovery | udp |
| 5514 | UDP | Syslog | udp |
| 10001 | UDP | Device discovery | udp |
| 8880 | HTTP | Captive Portal (optional) | main |
| 8843 | HTTPS | Captive Portal (optional) | main |

## Security Considerations

1. **Non-root execution**: Container runs as non-root user (UID/GID 999)
2. **HTTPS only**: Always access via HTTPS for security
3. **Network policies**: Consider enabling network policies
4. **RBAC**: Service account permissions are minimal
5. **Regular updates**: Keep UniFi Controller updated

## Accessing UniFi Controller

After deployment:

1. **With Ingress enabled**: Access via `https://unifi.yourdomain.com`
2. **With LoadBalancer**: Access via `https://<external-ip>:8443`
3. **With ClusterIP**: Use port-forwarding:
   ```bash
   kubectl port-forward svc/unifi 8443:8443
   # Then access: https://localhost:8443
   ```

Default credentials:
- Username: `ubnt`
- Password: Set on first login

## Upgrading

To upgrade the deployment:

```bash
helm upgrade unifi wauhost/unifi -f values.yaml
```

For major version upgrades, consider backing up your data first.

## Backup and Restore

### Backup

The UniFi data is stored in the persistent volume. To create backups:

```bash
# Create a backup of the UniFi data
kubectl exec -it deployment/unifi -- tar -czf /tmp/unifi-backup.tar.gz -C /unifi .

# Copy the backup to your local machine
kubectl cp deployment/unifi:/tmp/unifi-backup.tar.gz ./unifi-backup.tar.gz
```

### Restore

```bash
# Copy backup to the pod
kubectl cp ./unifi-backup.tar.gz deployment/unifi:/tmp/unifi-backup.tar.gz

# Stop UniFi service
kubectl scale deployment unifi --replicas=0

# Restore data
kubectl exec -it deployment/unifi -- tar -xzf /tmp/unifi-backup.tar.gz -C /unifi

# Start UniFi service
kubectl scale deployment unifi --replicas=1
```

## Monitoring

The chart includes built-in health checks:

- **Liveness Probe**: Ensures the UniFi process is running
- **Readiness Probe**: Ensures the UniFi service is ready to accept connections
- **Startup Probe**: Handles initial startup delays

Monitor the deployment:

```bash
kubectl get pods -l app.kubernetes.io/name=unifi
kubectl logs deployment/unifi -f
```

## Troubleshooting

### Common Issues

1. **Controller won't start**: Check resource limits and persistence
2. **Devices can't connect**: Ensure UDP ports are accessible
3. **High memory usage**: Adjust JVM heap size in `env.JVM_MAX_HEAP_SIZE`

### Logs

View UniFi logs:

```bash
kubectl logs deployment/unifi -f
```

### Debug Mode

Enable debug logging by adding to `env`:

```yaml
env:
  UNIFI_STDOUT: "true"
  LOG_LEVEL: "DEBUG"
```

## Contributing

Feel free to submit issues and enhancement requests!

## License

This chart is licensed under the Apache 2.0 License.