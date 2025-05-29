# 🚀 Wauhost Kubernetes Infrastructure

Production-ready Kubernetes Helm charts for deploying storage, monitoring, and application infrastructure with enterprise-grade security and observability.

📖 **For detailed chart documentation, see [charts/README.md](charts/README.md)**

## 📁 Repository Structure

```
wauhost/
├── charts/                      # Helm charts collection
│   ├── external-secrets/        # External Secrets Operator for secure credential management
│   ├── longhorn/                # Distributed storage with Longhorn
│   ├── minio/                   # S3-compatible object storage
│   ├── mysql/                   # MySQL database with replication support
│   ├── ghost/                   # Ghost CMS deployment
│   ├── wordpress/               # WordPress deployment
│   ├── cert-manager/            # Automatic SSL certificate management
│   └── storage-monitoring/      # Prometheus & Grafana monitoring for storage
├── docs/                        # Documentation
│   ├── security.md              # Security best practices
│   ├── deployment.md            # Deployment guide
│   ├── vault-production.md      # Vault production deployment guide
│   ├── monitoring.md            # Monitoring setup
│   └── troubleshooting.md       # Common issues and solutions
├── examples/                    # Integration examples
│   ├── vault/                   # Vault deployment manifests
│   ├── nodejs/                  # Node.js MinIO integration
│   ├── python/                  # Python S3 client examples
│   └── backup-scripts/          # Backup automation scripts
└── scripts/                     # Operational scripts
    ├── validate-charts.sh       # Helm chart validation
    ├── deploy-all.sh            # Full stack deployment
    ├── deploy-longhorn.sh       # Longhorn deployment
    ├── deploy-vault.sh          # Vault production deployment
    ├── deploy-minio-            # MinIO production deployment
    ├── check-health.sh          # Health check script
    └── verify-backups.sh        # Backup verification
```

## 🔐 Security Features

- **External Secrets Management**: Integration with HashiCorp Vault, AWS Secrets Manager, Azure Key Vault
- **Zero Hardcoded Credentials**: All secrets managed externally
- **RBAC Policies**: Fine-grained access control for all components
- **Network Policies**: Strict network segmentation
- **Pod Security Standards**: Enforced security contexts
- **Regular Security Scanning**: Automated vulnerability scanning

## 🚀 Quick Start

### Prerequisites

- Kubernetes cluster (1.23+)
- Helm 3.10+
- kubectl configured
- External secret backend (Vault, AWS SM, etc.)

### 1️⃣ Install External Secrets Operator

```bash
# Add the External Secrets Helm repository
helm repo add external-secrets https://charts.external-secrets.io

# Install the External Secrets Operator
helm install external-secrets \
  external-secrets/external-secrets \
  -n external-secrets-system \
  --create-namespace \
  -f charts/external-secrets/values.yaml
```

### 2️⃣ Configure Secret Store

Create a secret store configuration for your backend:

```yaml
# For AWS Secrets Manager
kubectl create secret generic awssm-secret \
  --from-literal=access-key=<YOUR_ACCESS_KEY> \
  --from-literal=secret-access-key=<YOUR_SECRET_KEY> \
  -n external-secrets-system
```

### 3️⃣ Deploy Charts

For detailed deployment instructions and configuration options, see the [Charts Documentation](charts/README.md).

Quick deployment:
```bash
# Deploy storage infrastructure
helm install longhorn ./charts/longhorn --namespace longhorn --create-namespace
helm install minio ./charts/minio --namespace minio --create-namespace

# Deploy applications
helm install mysql ./charts/mysql --namespace mysql --create-namespace
helm install wordpress ./charts/wordpress --namespace wordpress --create-namespace
```

## 📊 Monitoring

For monitoring setup and dashboard access, see the [Charts Documentation](charts/README.md#monitoring--alerting).

## 🔧 Configuration

For detailed configuration options including:
- External Secrets setup
- Storage Classes
- Backup Configuration
- Security Settings

See the [Charts Documentation](charts/README.md#configuration).

## 📈 Production Readiness

- ✅ **High Availability**: Multi-replica deployments
- ✅ **Auto-scaling**: HPA configured for all services
- ✅ **Backup & Recovery**: Automated daily backups
- ✅ **Monitoring & Alerting**: Comprehensive observability
- ✅ **Security Hardening**: Pod security, RBAC, network policies
- ✅ **Resource Management**: Proper limits and requests
- ✅ **Health Checks**: Liveness and readiness probes

## 🤝 Contributing

Please read our [Contributing Guide](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

### Development Workflow

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Run validation (`./scripts/validate-charts.sh`)
4. Commit your changes (`git commit -m 'Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

## 📚 Documentation

- [Security Best Practices](docs/security.md)
- [Deployment Guide](docs/deployment.md)
- [Vault Production Guide](docs/vault.md)
- [Monitoring Setup](docs/monitoring.md)
- [Troubleshooting Guide](docs/troubleshooting.md)
- [Integration Examples](examples/)

## 🐛 Troubleshooting

Common issues and solutions are documented in our [Troubleshooting Guide](docs/troubleshooting.md).

For urgent issues:
1. Check pod logs: `kubectl logs -n <namespace> <pod-name>`
2. Verify secrets: `kubectl get externalsecrets -A`
3. Check events: `kubectl get events -n <namespace>`

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

**Note**: HashiCorp Vault is licensed under the Business Source License. See [examples/vault/LICENSE-VAULT.txt](examples/vault/LICENSE-VAULT.txt) for details.

## 🙏 Acknowledgments

- [Longhorn](https://longhorn.io/) for distributed storage
- [MinIO](https://min.io/) for object storage
- [External Secrets Operator](https://external-secrets.io/) for secret management
- [Prometheus](https://prometheus.io/) & [Grafana](https://grafana.com/) for monitoring

---

**Maintained by**: Waushop  
**Contact**: siim@wauhost.ee  
**Version**: 1.0.0