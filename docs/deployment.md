# Deployment Guide

This guide provides step-by-step instructions for deploying the wauhost infrastructure.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Secret Configuration](#secret-configuration)
4. [Infrastructure Deployment](#infrastructure-deployment)
5. [Application Deployment](#application-deployment)
6. [Post-Deployment](#post-deployment)
7. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Tools

- **Kubernetes cluster** (v1.23+)
  - EKS, GKE, AKS, or self-managed
  - Minimum 3 nodes with 4 CPU, 8GB RAM each
  
- **kubectl** (v1.23+)
  ```bash
  # Install kubectl
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/
  ```

- **Helm** (v3.10+)
  ```bash
  # Install Helm
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  ```

- **External Secret Backend**
  - One of: Vault, AWS Secrets Manager, Azure Key Vault, Google Secret Manager

### Cluster Requirements

1. **Storage Classes**
   ```bash
   # Verify storage classes
   kubectl get storageclass
   ```

2. **Ingress Controller**
   ```bash
   # Install NGINX Ingress Controller
   helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
   helm install ingress-nginx ingress-nginx/ingress-nginx \
     --namespace ingress-nginx --create-namespace
   ```

3. **DNS Configuration**
   - Configure DNS records for your domains
   - Point to ingress controller load balancer

## Initial Setup

### 1. Clone Repository

```bash
git clone https://github.com/wauhost/infrastructure.git
cd infrastructure
```

### 2. Validate Charts

```bash
# Run validation script
./scripts/validate-charts.sh
```

### 3. Configure Values

Create a custom values file for your environment:

```yaml
# values-production.yaml
global:
  domain: example.com
  storageClass: fast-ssd
  
external-secrets:
  secretStore:
    provider: vault
    server: https://vault.example.com:8200
    
minio:
  api:
    host: s3.example.com
  console:
    host: minio.example.com
    
mysql:
  pvc:
    size: 50Gi
```

## Secret Configuration

### 1. Setup External Secrets Backend

#### HashiCorp Vault

```bash
# Enable KV v2 secret engine
vault secrets enable -path=wauhost kv-v2

# Create policy
cat > wauhost-policy.hcl << EOF
path "wauhost/*" {
  capabilities = ["read", "list"]
}
EOF

vault policy write wauhost-policy wauhost-policy.hcl

# Create authentication
vault auth enable kubernetes
vault write auth/kubernetes/config \
  kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443"
```

#### AWS Secrets Manager

```bash
# Create IAM policy
aws iam create-policy \
  --policy-name WauhostSecretsPolicy \
  --policy-document file://secrets-policy.json

# Create IAM role for service account
eksctl create iamserviceaccount \
  --name external-secrets-sa \
  --namespace external-secrets-system \
  --cluster my-cluster \
  --attach-policy-arn arn:aws:iam::123456789012:policy/WauhostSecretsPolicy
```

### 2. Create Secrets

```bash
# MinIO credentials
vault kv put wauhost/minio/root-user username=admin
vault kv put wauhost/minio/root-password password="$(openssl rand -base64 32)"

# MySQL credentials
vault kv put wauhost/mysql/root-password password="$(openssl rand -base64 32)"

# Backup credentials
vault kv put wauhost/minio/backup-access-key key="your-backup-key"
vault kv put wauhost/minio/backup-secret-key secret="your-backup-secret"
```

### 3. Deploy External Secrets Operator

```bash
# Add Helm repository
helm repo add external-secrets https://charts.external-secrets.io

# Install operator
helm install external-secrets \
  external-secrets/external-secrets \
  -n external-secrets-system \
  --create-namespace \
  --set installCRDs=true

# Deploy ClusterSecretStore
kubectl apply -f charts/external-secrets/templates/cluster-secret-store.yaml
```

## Infrastructure Deployment

### 1. Deploy Cert-Manager

```bash
helm install cert-manager ./charts/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --wait
```

### 2. Deploy Longhorn Storage

```bash
helm install longhorn ./charts/longhorn \
  --namespace longhorn-system \
  --create-namespace \
  -f values.yaml \
  --wait

# Verify storage classes
kubectl get storageclass | grep longhorn
```

### 3. Deploy MinIO

```bash
helm install minio ./charts/minio \
  --namespace minio-system \
  --create-namespace \
  -f values.yaml \
  --wait

# Verify deployment
kubectl get pods -n minio-system
kubectl get svc -n minio-system
```

### 4. Deploy MySQL

```bash
helm install mysql ./charts/mysql \
  --namespace mysql \
  --create-namespace \
  -f values.yaml \
  --wait

# Test connection
kubectl run -it --rm mysql-test \
  --image=mysql:8.0 \
  --restart=Never \
  -- mysql -h mysql.mysql.svc.cluster.local -u root -p
```

## Application Deployment

### 1. Deploy WordPress

```bash
helm install wordpress ./charts/wordpress \
  --namespace wordpress \
  --create-namespace \
  -f values.yaml \
  --wait

# Get WordPress URL
echo "WordPress URL: https://$(kubectl get ingress -n wordpress -o jsonpath='{.items[0].spec.rules[0].host}')"
```

### 2. Deploy Ghost

```bash
helm install ghost ./charts/ghost \
  --namespace ghost \
  --create-namespace \
  -f values.yaml \
  --wait

# Get Ghost URL
echo "Ghost URL: https://$(kubectl get ingress -n ghost -o jsonpath='{.items[0].spec.rules[0].host}')"
```

### 3. Deploy Monitoring

```bash
helm install storage-monitoring ./charts/storage-monitoring \
  --namespace monitoring \
  --create-namespace \
  -f values.yaml \
  --wait
```

## Post-Deployment

### 1. Verify Deployments

```bash
# Run health check
./scripts/check-health.sh

# Check all pods
kubectl get pods -A | grep -E '(external-secrets|cert-manager|longhorn|minio|mysql|wordpress|ghost|monitoring)'
```

### 2. Configure Backups

```bash
# Create backup CronJob for MySQL
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: mysql-backup
  namespace: mysql
spec:
  schedule: "0 3 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: mysql:8.0
            command:
            - /bin/bash
            - -c
            - |
              mysqldump -h mysql -u root -p\$MYSQL_ROOT_PASSWORD \
                --all-databases --single-transaction | \
                gzip > /backup/mysql-\$(date +%Y%m%d_%H%M%S).sql.gz
            env:
            - name: MYSQL_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysql-secret
                  key: mysql-root-password
          restartPolicy: OnFailure
EOF
```

### 3. Setup Monitoring Alerts

Configure alert receivers in AlertManager:

```yaml
# values-monitoring.yaml
alertmanager:
  config:
    receivers:
    - name: 'team-notifications'
      slack_configs:
      - api_url: 'YOUR_SLACK_WEBHOOK_URL'
        channel: '#alerts'
        title: 'Wauhost Alert'
```

### 4. Configure DNS

Update DNS records for your domains:

```bash
# Get ingress IP
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Configure these DNS records:"
echo "minio.example.com -> $INGRESS_IP"
echo "s3.example.com -> $INGRESS_IP"
echo "wordpress.example.com -> $INGRESS_IP"
echo "ghost.example.com -> $INGRESS_IP"
```

## Troubleshooting

### Common Issues

#### 1. Pods Not Starting

```bash
# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Check logs
kubectl logs <pod-name> -n <namespace>

# Check resource availability
kubectl top nodes
kubectl describe node <node-name>
```

#### 2. Storage Issues

```bash
# Check PVC status
kubectl get pvc -A

# Check Longhorn status
kubectl get volumes.longhorn.io -n longhorn-system
kubectl get nodes.longhorn.io -n longhorn-system
```

#### 3. Certificate Issues

```bash
# Check certificate status
kubectl get certificates -A
kubectl describe certificate <cert-name> -n <namespace>

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager
```

#### 4. External Secrets Not Syncing

```bash
# Check ExternalSecret status
kubectl get externalsecrets -A
kubectl describe externalsecret <name> -n <namespace>

# Check operator logs
kubectl logs -n external-secrets-system deployment/external-secrets
```

### Debug Commands

```bash
# Get all resources in a namespace
kubectl get all -n <namespace>

# Describe all events
kubectl get events -A --sort-by='.lastTimestamp'

# Check node resources
kubectl top nodes
kubectl top pods -A

# Test DNS resolution
kubectl run -it --rm dnsutils --image=gcr.io/kubernetes-e2e-test-images/dnsutils:1.3 -- nslookup kubernetes.default
```

### Recovery Procedures

#### 1. Restore from Backup

```bash
# List available backups
mc ls minio/mysql-backups/

# Restore MySQL
kubectl exec -it -n mysql deployment/mysql -- \
  mysql -u root -p < /path/to/backup.sql
```

#### 2. Force Secret Sync

```bash
# Annotate ExternalSecret to force sync
kubectl annotate externalsecret <name> -n <namespace> \
  force-sync=$(date +%s) --overwrite
```

#### 3. Restart Deployments

```bash
# Restart all deployments in a namespace
kubectl rollout restart deployment -n <namespace>
```

## Maintenance

### Regular Tasks

1. **Weekly**
   - Review monitoring alerts
   - Check backup status
   - Review resource usage

2. **Monthly**
   - Update container images
   - Review security patches
   - Test backup restoration
   - Review access logs

3. **Quarterly**
   - Security audit
   - Performance review
   - Capacity planning
   - Disaster recovery drill

### Upgrade Procedures

```bash
# Upgrade Helm charts
helm repo update
helm upgrade <release> <chart> -n <namespace> -f values-production.yaml

# Upgrade Kubernetes
# Follow cloud provider guidelines
```

## Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [External Secrets Documentation](https://external-secrets.io/)
- [Longhorn Documentation](https://longhorn.io/docs/)