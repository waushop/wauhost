# Production Vault Deployment Guide

This guide covers deploying HashiCorp Vault and External Secrets Operator in production mode for the wauhost infrastructure.

## Prerequisites

1. **cert-manager** installed with `letsencrypt-prod` ClusterIssuer
2. **Longhorn** or another storage class for persistent volumes
3. **htpasswd** command for generating basic auth passwords
4. **jq** for JSON processing

## Key Differences from Development Mode

| Feature | Development | Production |
|---------|-------------|------------|
| Vault Mode | Dev (in-memory) | Production (persistent) |
| TLS | Disabled | Enabled with cert-manager |
| Authentication | Root token | Kubernetes ServiceAccount |
| Initialization | Automatic | Manual with unseal keys |
| Storage | Ephemeral | Persistent Volume |
| Security | Minimal | Hardened |

## Step-by-Step Deployment

### 1. Prepare Secrets

First, generate secure passwords for your applications:

```bash
# Generate passwords
echo "MySQL root: $(openssl rand -hex 16)"
echo "MySQL user: $(openssl rand -hex 16)"
echo "WordPress DB: $(openssl rand -hex 16)"
echo "Ghost DB: $(openssl rand -hex 16)"
echo "MinIO root: $(openssl rand -hex 16)"
echo "MinIO backup key: $(openssl rand -hex 8)"
echo "MinIO backup secret: $(openssl rand -hex 16)"

# Generate htpasswd for Longhorn
htpasswd -nb admin your-secure-password
```

### 2. Update Production Values

Edit `charts/external-secrets/values.yaml`:

1. Replace all `CHANGE_ME_` placeholders with your generated passwords
2. Update email addresses and webhook URLs
3. Configure your S3/backup credentials
4. Adjust resource limits based on your cluster

### 3. Deploy

Run the production deployment script:

```bash
./scripts/deploy-vault-production.sh
```

This script will:
- Clean up any existing deployments
- Install External Secrets Operator
- Deploy Vault in production mode
- Initialize Vault and create Kubernetes auth

### 4. Retrieve Unseal Keys

After deployment, get the unseal keys and root token:

```bash
# Get initialization data
kubectl get secret vault-init -n vault -o json | \
  jq -r '.data."init.json"' | base64 -d | jq

# Save the output securely!
```

**⚠️ CRITICAL: Store these keys securely! You need them to unseal Vault after restarts.**

### 5. Unseal Vault

Vault starts in a sealed state. Unseal it with 3 of the 5 keys:

```bash
# Unseal with first key
kubectl exec -n vault vault-0 -- vault operator unseal <key-1>

# Unseal with second key
kubectl exec -n vault vault-0 -- vault operator unseal <key-2>

# Unseal with third key
kubectl exec -n vault vault-0 -- vault operator unseal <key-3>
```

### 6. Verify Deployment

```bash
# Check Vault status
kubectl exec -n vault vault-0 -- vault status

# Check ClusterSecretStore
kubectl get clustersecretstore
kubectl describe clustersecretstore cluster-secret-store

# Test external secret
kubectl apply -f vault/test-external-secret.yaml
kubectl get externalsecret -n test
```

## Production Security Hardening

### 1. Enable Auto-Unseal

For production, configure auto-unseal using cloud KMS:

**AWS KMS Example:**
```yaml
vault:
  unseal:
    awskms:
      enabled: true
      region: "us-east-1"
      kmsKeyId: "your-kms-key-id"
```

**Azure Key Vault Example:**
```yaml
vault:
  unseal:
    azurekeyvault:
      enabled: true
      keyName: "vault-unseal"
      vaultName: "your-keyvault"
```

### 2. Configure Audit Logging

Enable audit logs for compliance:

```bash
kubectl exec -n vault vault-0 -- vault audit enable file file_path=/vault/audit/audit.log
```

### 3. Implement Backup Strategy

Create a CronJob for regular backups:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: vault-backup
  namespace: vault
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: hashicorp/vault:1.15.4
            command:
            - /bin/sh
            - -c
            - |
              vault operator raft snapshot save /backup/vault-$(date +%Y%m%d-%H%M%S).snap
            volumeMounts:
            - name: backup
              mountPath: /backup
          volumes:
          - name: backup
            persistentVolumeClaim:
              claimName: vault-backup
```

### 4. Monitor Vault

Add Prometheus monitoring:

```bash
# Enable metrics
kubectl exec -n vault vault-0 -- \
  vault write sys/config/telemetry prometheus_retention_time="30s"

# Create ServiceMonitor
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: vault
  namespace: vault
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: vault
  endpoints:
  - port: vault
    path: /v1/sys/metrics
    interval: 30s
EOF
```

## Operational Procedures

### Manual Unseal After Restart

If Vault restarts, you must unseal it:

```bash
# Check seal status
kubectl exec -n vault vault-0 -- vault status

# If sealed, unseal with 3 keys
kubectl exec -n vault vault-0 -- vault operator unseal <key-1>
kubectl exec -n vault vault-0 -- vault operator unseal <key-2>
kubectl exec -n vault vault-0 -- vault operator unseal <key-3>
```

### Adding New Secrets

```bash
# Port-forward to Vault
kubectl port-forward -n vault svc/vault 8200:8200

# Login with root token
export VAULT_ADDR='https://localhost:8200'
export VAULT_TOKEN='<your-root-token>'

# Add new secret
vault kv put secret/wauhost/newapp/password password="secure-password"
```

### Rotating Secrets

```bash
# Update existing secret
vault kv put secret/wauhost/mysql/root-password password="new-secure-password"

# Force ExternalSecret refresh
kubectl annotate externalsecret mysql-credentials -n mysql \
  force-sync=$(date +%s) --overwrite
```

### Disaster Recovery

1. **Backup Vault data regularly**
   ```bash
   kubectl exec -n vault vault-0 -- \
     vault operator raft snapshot save /tmp/vault-backup.snap
   kubectl cp vault/vault-0:/tmp/vault-backup.snap ./vault-backup.snap
   ```

2. **Store unseal keys in multiple secure locations**
   - Use a password manager
   - Store in encrypted cloud storage
   - Use hardware security modules (HSM)

3. **Test recovery procedures**
   - Practice unsealing
   - Test backup restoration
   - Verify secret access

## Troubleshooting

### Vault is Sealed

```bash
# Check status
kubectl exec -n vault vault-0 -- vault status

# Check logs
kubectl logs -n vault vault-0

# Unseal with keys
kubectl exec -n vault vault-0 -- vault operator unseal <key>
```

### External Secrets Not Syncing

```bash
# Check ClusterSecretStore
kubectl describe clustersecretstore cluster-secret-store

# Check External Secrets Operator logs
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets

# Verify Kubernetes auth
kubectl exec -n vault vault-0 -- vault read auth/kubernetes/config
```

### TLS Certificate Issues

```bash
# Check certificate
kubectl get certificate -n vault
kubectl describe certificate vault-tls -n vault

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager
```

## Migration from Development

To migrate from dev to production:

1. Export all secrets from dev Vault
2. Deploy production Vault
3. Import secrets to production Vault
4. Update application deployments
5. Verify all ExternalSecrets are syncing

## Security Checklist

- [ ] Unseal keys stored securely
- [ ] Root token rotated after initial setup
- [ ] Auto-unseal configured
- [ ] Audit logging enabled
- [ ] Backup strategy implemented
- [ ] Monitoring configured
- [ ] Network policies applied
- [ ] TLS enabled
- [ ] Resource limits set
- [ ] Pod security policies enforced