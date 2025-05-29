# External Secrets Configuration Chart

This chart provides configuration templates for the External Secrets Operator, enabling secure secret management across the wauhost infrastructure.

## Overview

This chart creates a `ClusterSecretStore` that can be used by all other charts in the wauhost ecosystem to retrieve secrets from external secret management systems.

## Prerequisites

- External Secrets Operator must be installed separately:
  ```bash
  helm repo add external-secrets https://charts.external-secrets.io
  helm install external-secrets external-secrets/external-secrets \
    -n external-secrets-system --create-namespace
  ```

## Supported Providers

- **AWS Secrets Manager**
- **HashiCorp Vault**
- **Azure Key Vault**
- **Google Secret Manager**

## Configuration

1. **Choose your provider** and configure in `values.yaml`:

   ```yaml
   secretStore:
     provider: "aws"  # or vault, azurekv, gcpsm
   ```

2. **Configure provider-specific settings**:

   For AWS Secrets Manager:
   ```yaml
   secretStore:
     provider: "aws"
     region: "us-east-1"
     auth:
       secretRef:
         accessKeyID:
           name: "aws-credentials"
           key: "access-key-id"
         secretAccessKey:
           name: "aws-credentials"
           key: "secret-access-key"
   ```

3. **Create the provider credentials secret**:
   ```bash
   kubectl create secret generic aws-credentials \
     --from-literal=access-key-id=AKIA... \
     --from-literal=secret-access-key=... \
     -n external-secrets-system
   ```

4. **Enable the ClusterSecretStore**:
   ```yaml
   clusterSecretStore:
     enabled: true
   ```

## Quick Start

1. Install External Secrets Operator
2. Create provider credentials secret
3. Configure this chart with your provider details
4. Deploy this chart
5. Other wauhost charts can now use `externalSecrets.enabled=true`

## Security Notes

- Never commit credentials to Git
- Use separate secret stores for different environments
- Implement regular credential rotation
- Monitor secret access logs
- Use least privilege access policies

## Example Deployment

```bash
# Configure values
cat > my-values.yaml << EOF
secretStore:
  provider: "aws"
  region: "us-east-1"
  auth:
    secretRef:
      accessKeyID:
        name: "aws-credentials"
        key: "access-key-id"
      secretAccessKey:
        name: "aws-credentials"
        key: "secret-access-key"

clusterSecretStore:
  enabled: true
EOF

# Deploy
helm install external-secrets-config ./charts/external-secrets \
  -f my-values.yaml \
  -n external-secrets-system
```