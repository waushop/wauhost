# Storage Monitoring Helm Chart

A comprehensive monitoring solution for storage systems in Kubernetes, including Longhorn, MinIO, and backup monitoring with Prometheus and Grafana.

## Overview

This Helm chart deploys a complete storage monitoring stack with:
- Pre-configured Prometheus rules for storage alerts
- Custom Grafana dashboards for Longhorn and MinIO
- Backup monitoring and alerting
- ServiceMonitor configurations for automatic metric discovery
- AlertManager integration for notifications
- External secrets management for credentials

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- Prometheus Operator (kube-prometheus-stack)
- Grafana (usually part of kube-prometheus-stack)
- Longhorn and/or MinIO deployed
- External Secrets Operator (if using external secrets)

## Installation

### Quick Start

```bash
# Deploy storage monitoring
helm install storage-monitoring ./charts/storage-monitoring \
  --namespace monitoring \
  --create-namespace

# Deploy with custom alerting endpoints
helm install storage-monitoring ./charts/storage-monitoring \
  --namespace monitoring \
  --set alerting.enabled=true \
  --set alerting.slack.webhook=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

### Production Deployment

```bash
# Create namespace
kubectl create namespace monitoring

# Deploy with custom values
helm install storage-monitoring ./charts/storage-monitoring \
  --namespace monitoring \
  --values production-values.yaml
```

## Configuration

### Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nameOverride` | Override chart name | `""` |
| `fullnameOverride` | Override full chart name | `""` |
| `namespace` | Target namespace for monitoring | `monitoring` |

### External Secrets Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `externalSecrets.enabled` | Enable external secrets integration | `true` |
| `externalSecrets.refreshInterval` | Secret refresh interval | `1h` |
| `externalSecrets.secretStore` | Secret store name | `cluster-secret-store` |
| `externalSecrets.secretStoreKind` | Secret store kind | `ClusterSecretStore` |
| `externalSecrets.remoteRefs.webhookUrl` | Webhook URL path in secret store | `wauhost/monitoring/webhook-url` |

### ServiceMonitor Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `serviceMonitor.enabled` | Enable ServiceMonitor creation | `true` |
| `serviceMonitor.namespace` | ServiceMonitor namespace | `monitoring` |
| `serviceMonitor.interval` | Scrape interval | `30s` |
| `serviceMonitor.scrapeTimeout` | Scrape timeout | `10s` |

### Prometheus Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `prometheus.enabled` | Enable Prometheus rules | `true` |
| `prometheus.ruleNamespace` | Namespace for PrometheusRule | `monitoring` |
| `prometheus.storageClass` | Storage class for Prometheus | `longhorn` |
| `prometheus.retention` | Data retention period | `30d` |
| `prometheus.storageSize` | Storage size for Prometheus | `50Gi` |

### Grafana Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `grafana.enabled` | Enable Grafana dashboards | `true` |
| `grafana.namespace` | Grafana namespace | `monitoring` |
| `grafana.dashboards.longhorn.enabled` | Enable Longhorn dashboard | `true` |
| `grafana.dashboards.minio.enabled` | Enable MinIO dashboard | `true` |
| `grafana.dashboards.backups.enabled` | Enable backup monitoring dashboard | `true` |

### Alerting Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `alerting.enabled` | Enable alerting rules | `true` |
| `alerting.labels` | Additional labels for alerts | `{}` |
| `alerting.webhookUrl` | Webhook URL for alerts (when not using external secrets) | `""` |

## Monitoring Components

### Longhorn Monitoring

Monitors:
- Volume health and status
- Node storage capacity
- Replica health
- Backup completion status
- Snapshot operations
- I/O performance metrics

Key alerts:
- `LonghornVolumeUnhealthy`: Volume is degraded or faulted
- `LonghornNodeStorageFull`: Node storage above 85%
- `LonghornBackupFailed`: Backup operation failed
- `LonghornReplicaCountLow`: Volume has fewer replicas than configured

### MinIO Monitoring

Monitors:
- Bucket usage and growth
- API request rates and errors
- Disk usage and health
- Network throughput
- Object count and size distribution
- Replication lag (if configured)

Key alerts:
- `MinIODiskOffline`: One or more disks are offline
- `MinIOStorageSpaceExhausted`: Storage space above 90%
- `MinIOHighErrorRate`: API error rate above threshold
- `MinIOBackupDelayed`: Backup job hasn't run in expected time

### Backup Monitoring

Monitors:
- Backup job completion
- Backup duration trends
- Storage usage for backups
- Failed backup attempts
- Recovery time objectives (RTO)

Key alerts:
- `BackupJobFailed`: Backup job failed to complete
- `BackupNotRunning`: No successful backup in 48 hours
- `BackupStorageFull`: Backup storage above 85%
- `BackupDurationExceeded`: Backup taking longer than expected

## Examples

### Production Configuration

```yaml
# production-values.yaml
externalSecrets:
  enabled: true
  remoteRefs:
    webhookUrl: production/monitoring/slack-webhook

serviceMonitor:
  enabled: true
  interval: 15s
  additionalLabels:
    prometheus: kube-prometheus

prometheus:
  retention: 90d
  storageSize: 100Gi
  additionalRules:
    - name: custom-storage-rules
      rules:
        - alert: StorageGrowthAnomaly
          expr: |
            predict_linear(longhorn_volume_usage_bytes[1h], 7*24*3600) 
            > longhorn_volume_capacity_bytes * 0.9
          for: 30m
          labels:
            severity: warning
          annotations:
            summary: "Volume {{ $labels.volume }} will be full in 7 days"

grafana:
  dashboards:
    custom:
      enabled: true
      configMap: custom-dashboards

alerting:
  enabled: true
  receivers:
    - name: slack
      webhook_url: "{{ .Values.alerting.webhookUrl }}"
    - name: pagerduty
      pagerduty_configs:
        - service_key: "{{ .Values.alerting.pagerdutyKey }}"
```

### Development Configuration

```yaml
# dev-values.yaml
externalSecrets:
  enabled: false

prometheus:
  retention: 7d
  storageSize: 10Gi

alerting:
  enabled: true
  webhookUrl: "http://alertmanager-webhook.monitoring.svc.cluster.local/webhook"

grafana:
  dashboards:
    test:
      enabled: true
```

## Troubleshooting

### Metrics Not Appearing

1. Check ServiceMonitor is created:
```bash
kubectl get servicemonitor -n monitoring
```

2. Verify Prometheus is discovering targets:
```bash
# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/prometheus-operated 9090

# Check targets at http://localhost:9090/targets
```

3. Check endpoints:
```bash
kubectl get endpoints -n longhorn-system longhorn-backend
kubectl get endpoints -n minio minio
```

### Dashboards Not Loading

1. Check Grafana ConfigMaps:
```bash
kubectl get configmap -n monitoring | grep dashboard
```

2. Verify dashboard provisioning:
```bash
kubectl logs -n monitoring deployment/grafana | grep -i dashboard
```

3. Check dashboard JSON syntax:
```bash
kubectl get configmap storage-monitoring-longhorn-dashboard -n monitoring -o json | \
  jq '.data."longhorn-dashboard.json"' | jq .
```

### Alerts Not Firing

1. Check PrometheusRule:
```bash
kubectl get prometheusrule -n monitoring
kubectl describe prometheusrule storage-monitoring-alerts -n monitoring
```

2. Verify alert state in Prometheus:
```bash
# Port-forward and check http://localhost:9090/alerts
```

3. Check AlertManager configuration:
```bash
kubectl logs -n monitoring alertmanager-main-0
```

### External Secrets Issues

1. Check ExternalSecret:
```bash
kubectl get externalsecret -n monitoring
kubectl describe externalsecret storage-monitoring-webhook -n monitoring
```

2. Verify secret creation:
```bash
kubectl get secret storage-monitoring-webhook -n monitoring
```

## Custom Dashboards

### Adding Custom Dashboard

1. Create dashboard JSON:
```json
{
  "dashboard": {
    "title": "Custom Storage Dashboard",
    "panels": [
      {
        "targets": [
          {
            "expr": "longhorn_volume_usage_bytes",
            "legendFormat": "{{ volume }}"
          }
        ]
      }
    ]
  }
}
```

2. Add to values:
```yaml
grafana:
  dashboards:
    custom:
      myDashboard: |
        {{ .Files.Get "dashboards/custom.json" | indent 8 }}
```

### Modifying Existing Dashboards

```bash
# Export existing dashboard
kubectl get configmap storage-monitoring-longhorn-dashboard -n monitoring \
  -o jsonpath='{.data.longhorn-dashboard\.json}' > longhorn-dashboard.json

# Edit dashboard
# Then update the chart with modified dashboard
```

## Alert Configuration

### Custom Alert Rules

```yaml
prometheus:
  additionalRules:
    - name: storage-capacity-planning
      interval: 30s
      rules:
        - alert: StorageCapacityPlanning
          expr: |
            (
              sum by (node) (longhorn_node_storage_capacity_bytes) -
              sum by (node) (longhorn_node_storage_usage_bytes)
            ) < 50 * 1024 * 1024 * 1024  # 50GB
          for: 10m
          labels:
            severity: warning
            component: storage
          annotations:
            summary: "Node {{ $labels.node }} has less than 50GB free"
            description: "Free space: {{ $value | humanize1024 }}"
```

### Alert Routing

```yaml
alerting:
  routes:
    - match:
        severity: critical
      receiver: pagerduty
    - match:
        severity: warning
      receiver: slack
    - match:
        component: backup
      receiver: backup-team
```

## Integration Examples

### Slack Integration

```yaml
alerting:
  receivers:
    - name: slack
      slack_configs:
        - api_url: "YOUR_WEBHOOK_URL"
          channel: "#storage-alerts"
          title: "Storage Alert"
          text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
```

### PagerDuty Integration

```yaml
alerting:
  receivers:
    - name: pagerduty
      pagerduty_configs:
        - service_key: "YOUR_SERVICE_KEY"
          severity: '{{ .CommonLabels.severity }}'
```

### Email Integration

```yaml
alerting:
  receivers:
    - name: email
      email_configs:
        - to: "storage-team@example.com"
          from: "alerts@example.com"
          smarthost: "smtp.example.com:587"
          auth_username: "alerts@example.com"
          auth_password: "password"
```

## Performance Tuning

### Metric Retention

```yaml
prometheus:
  # Adjust retention based on storage capacity
  retention: 30d
  # Downsample older metrics
  retentionSize: 40GB
```

### Query Optimization

```yaml
serviceMonitor:
  # Increase interval for high-cardinality metrics
  endpoints:
    - path: /metrics
      interval: 60s
      metricRelabelings:
        # Drop unnecessary metrics
        - sourceLabels: [__name__]
          regex: "go_.*"
          action: drop
```

## Security Considerations

1. **Webhook URLs**: Always use external secrets for webhook URLs
2. **RBAC**: Limit access to monitoring namespace
3. **Network Policies**: Restrict traffic to monitoring components
4. **TLS**: Enable TLS for metric endpoints
5. **Authentication**: Use strong authentication for Grafana

## Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Longhorn Metrics](https://longhorn.io/docs/latest/monitoring/)
- [MinIO Metrics](https://min.io/docs/minio/linux/operations/monitoring.html)
- [AlertManager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)