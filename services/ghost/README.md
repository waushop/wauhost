# Ghost Helm Chart

A production-ready Ghost blog platform deployment with enterprise security features and external secrets management.

## 🎯 Overview

Ghost is a powerful open source publishing platform built on Node.js. This Helm chart deploys Ghost with:

✅ **Security First**
- External secrets management integration
- Security contexts and non-root containers
- Network policies for traffic isolation
- TLS/SSL certificate automation

✅ **Production Ready**
- Health checks (liveness & readiness probes)
- Resource limits and requests
- Multi-environment configuration support
- Persistent storage with configurable access modes

✅ **Enterprise Features**
- MySQL database integration
- SMTP email configuration
- Multi-replica support
- Performance optimization settings

✅ **DevOps Friendly**
- External Secrets Operator integration
- Traefik ingress with cert-manager
- Comprehensive monitoring hooks
- Flexible node scheduling

## 📋 Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- MySQL database (use our MySQL chart)
- External Secrets Operator (for production)
- Traefik ingress controller
- cert-manager for automated TLS

## 🚀 Quick Start

### Production Deployment (Recommended)
```bash
helm install ghost ./charts/ghost \
  --namespace ghost \
  --create-namespace \
  --set host=myblog.com \
  --set database.host=mysql.mysql.svc.cluster.local
```

### Development Deployment
```bash
helm install ghost ./charts/ghost \
  --namespace ghost \
  --create-namespace \
  --set externalSecrets.enabled=false \
  --set database.password=devpassword \
  --set host=blog.dev.local
```

## ⚙️ Configuration

### 🏗️ Infrastructure Configuration
| Parameter | Description | Default |
|-----------|-------------|---------|
| `namespace` | Deployment namespace | `"vausiim"` |
| `releaseName` | Release name for resources | `"vausiim"` |
| `host` | Blog hostname | `"vausiim.ee"` |
| `replicaCount` | Number of Ghost replicas | `1` |

### 🐳 Application Configuration
| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Ghost image repository | `ghost` |
| `image.tag` | Ghost image tag | `"5"` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |

### 🗄️ Database Configuration
| Parameter | Description | Default |
|-----------|-------------|---------|
| `database.host` | MySQL host | `mysql.mysql.svc.cluster.local` |
| `database.user` | MySQL username | `"vausiim"` |
| `database.database` | MySQL database name | `"vausiim"` |
| `database.password` | MySQL password (dev only) | `""` |

### 🔐 Security Configuration
| Parameter | Description | Default |
|-----------|-------------|---------|
| `externalSecrets.enabled` | Enable external secrets | `true` |
| `externalSecrets.refreshInterval` | Secret refresh interval | `1h` |
| `securityContext.enabled` | Enable security context | `true` |
| `securityContext.runAsNonRoot` | Run as non-root user | `true` |
| `networkPolicy.enabled` | Enable network policies | `false` |

### 📧 Mail Configuration
| Parameter | Description | Default |
|-----------|-------------|---------|
| `mail.enabled` | Enable mail configuration | `true` |
| `mail.transport` | Mail transport | `SMTP` |
| `mail.options.host` | SMTP host | `"smtp.eu.mailgun.org"` |
| `mail.options.port` | SMTP port | `587` |
| `mail.from` | From email address | `"noreply@vausiim.ee"` |

### 💾 Storage Configuration
| Parameter | Description | Default |
|-----------|-------------|---------|
| `pvc.size` | Persistent volume size | `5Gi` |
| `pvc.storageClassName` | Storage class | `""` (cluster default) |
| `pvc.accessMode` | Access mode | `ReadWriteOnce` |

### 🌐 Ingress Configuration
| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable ingress | `true` |
| `ingress.className` | Ingress class | `"traefik"` |
| `ingress.tls.enabled` | Enable TLS | `true` |

### 🚀 Performance Configuration
| Parameter | Description | Default |
|-----------|-------------|---------|
| `resources.requests.memory` | Memory request | `"256Mi"` |
| `resources.requests.cpu` | CPU request | `"100m"` |
| `resources.limits.memory` | Memory limit | `"512Mi"` |
| `resources.limits.cpu` | CPU limit | `"500m"` |

## 📝 Production Examples

### Multi-Environment Setup
```yaml
# production-values.yaml
namespace: production
host: myblog.com
replicaCount: 2

# Use production environment preset
environments:
  production:
    enabled: true

# Enhanced security
securityContext:
  enabled: true
networkPolicy:
  enabled: true

# Performance tuning
resources:
  requests:
    memory: "512Mi"
    cpu: "200m"
  limits:
    memory: "1Gi"
    cpu: "1000m"

# Larger storage
pvc:
  size: 20Gi
  storageClassName: fast-ssd

# Production database
database:
  host: mysql-primary.mysql.svc.cluster.local
  user: ghost_prod
  database: ghost_production

# External secrets
externalSecrets:
  remoteRefs:
    dbPassword: production/ghost/db-password
    mailPassword: production/ghost/mail-password
```

### High Availability Setup
```yaml
# ha-values.yaml
replicaCount: 3

# Pod anti-affinity for HA
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 1
      podAffinityTerm:
        topologyKey: kubernetes.io/hostname
        labelSelector:
          matchLabels:
            app.kubernetes.io/name: ghost

# Enhanced health checks
livenessProbe:
  initialDelaySeconds: 120
  periodSeconds: 30
readinessProbe:
  initialDelaySeconds: 60
  periodSeconds: 10

# Shared storage for multi-replica
pvc:
  accessMode: ReadWriteMany
  size: 50Gi
```

## 🔧 Troubleshooting

### 🚨 Ghost Pod Issues

**Pod not starting:**
```bash
kubectl get pods -n ghost
kubectl describe pod <pod-name> -n ghost
kubectl logs -n ghost deployment/ghost --previous
```

**Performance issues:**
```bash
kubectl top pods -n ghost
kubectl exec -n ghost deployment/ghost -- ps aux
```

### 🗄️ Database Connection

**Test database connectivity:**
```bash
kubectl run -it --rm debug --image=mysql:8 --restart=Never -- \
  mysql -h mysql.mysql.svc.cluster.local -u vausiim -p

# Check environment variables
kubectl exec -n ghost deployment/ghost -- env | grep database
```

### 🔐 External Secrets Issues

**Debug external secrets:**
```bash
kubectl get externalsecret -n ghost -o yaml
kubectl describe externalsecret ghost-secrets -n ghost
kubectl get secret ghost-secrets -n ghost -o yaml
```

### 📧 Mail Configuration

**Test mail settings:**
```bash
# Check mail environment
kubectl exec -n ghost deployment/ghost -- env | grep mail

# View Ghost admin mail settings
# Navigate to: https://yourblog.com/ghost/#/settings/email
```

### 💾 Storage Problems

**Check storage:**
```bash
kubectl get pvc -n ghost
kubectl describe pvc ghost-pvc -n ghost
kubectl exec -n ghost deployment/ghost -- df -h /var/lib/ghost/content
```

## 🔄 Backup & Recovery

### Create Backup
```bash
# Automated backup
kubectl create job ghost-backup-$(date +%Y%m%d) \
  --from=deployment/ghost -n ghost \
  -- tar czf /backup/ghost-$(date +%Y%m%d).tar.gz /var/lib/ghost/content

# Manual backup
kubectl exec -n ghost deployment/ghost -- \
  tar czf - /var/lib/ghost/content > ghost-backup-$(date +%Y%m%d).tar.gz
```

### Restore from Backup
```bash
# Copy backup to pod
kubectl cp ghost-backup.tar.gz ghost/<pod-name>:/tmp/backup.tar.gz

# Restore content
kubectl exec -n ghost deployment/ghost -- \
  tar xzf /tmp/backup.tar.gz -C / --strip-components=1
```

## 🔒 Security Best Practices

### Production Security Checklist
- ✅ Enable external secrets management
- ✅ Use network policies for traffic isolation
- ✅ Enable security contexts (non-root containers)
- ✅ Set resource limits to prevent DoS
- ✅ Enable TLS with valid certificates
- ✅ Regular image updates for security patches
- ✅ Backup encryption at rest
- ✅ Monitor security events

### Security Configuration Example
```yaml
securityContext:
  enabled: true
  runAsNonRoot: true
  runAsUser: 1000
  capabilities:
    drop: ["ALL"]

networkPolicy:
  enabled: true
  ingress:
    allowIngressController: true
  egress:
    allowMySQL: true
    allowMail: true

externalSecrets:
  enabled: true
  refreshInterval: 15m
```

## 📚 Additional Resources

- [Ghost Documentation](https://ghost.org/docs/)
- [Ghost Configuration Reference](https://ghost.org/docs/config/)
- [External Secrets Operator](https://external-secrets.io/)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)

---

**🎉 Ready for Production!** This Ghost chart provides enterprise-grade security, scalability, and operational excellence for your Ghost blog platform.
