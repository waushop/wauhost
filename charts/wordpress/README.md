# WordPress Helm Chart

A production-ready WordPress deployment with enterprise security features.

## Features

- **Security Hardened**: Runs as non-root user (www-data), no privilege escalation
- **External Secrets**: Integrates with external secret management
- **Health Checks**: Comprehensive liveness, readiness, and startup probes
- **RBAC**: Least privilege access controls
- **Persistent Storage**: Configurable data persistence
- **Resource Management**: Proper CPU and memory limits

## Quick Start

```bash
# Deploy with external secrets
helm install wordpress ./charts/wordpress \
  --namespace wordpress \
  --create-namespace \
  --set wordpress.ingress.host=mywordpress.com

# Deploy with local secrets (development only)
helm install wordpress ./charts/wordpress \
  --namespace wordpress \
  --create-namespace \
  --set externalSecrets.enabled=false \
  --set wordpress.env.WORDPRESS_DB_PASSWORD=mysecretpassword
```

## Configuration

Key configuration options:

```yaml
externalSecrets:
  enabled: true  # Use external secret management

wordpress:
  replicaCount: 1
  image:
    repository: wordpress
    tag: latest
  
  env:
    WORDPRESS_DB_HOST: "mysql.mysql.svc.cluster.local"
    WORDPRESS_DB_USER: "wordpress"
    WORDPRESS_DB_NAME: "wordpress"
    # WORDPRESS_DB_PASSWORD managed by external secrets
  
  ingress:
    enabled: true
    host: wordpress.example.com
  
  persistence:
    enabled: true
    size: 10Gi
```

## Security Features

1. **Non-root execution**: Runs as user ID 33 (www-data)
2. **No privilege escalation**: Container security context prevents escalation
3. **Secret management**: Database password stored in Kubernetes secrets
4. **WordPress hardening**: Disables file editing and modifications
5. **Resource limits**: Prevents resource exhaustion
6. **Health checks**: Ensures service availability

## Dependencies

- MySQL database (deployed separately)
- Persistent storage (if persistence enabled)
- External Secrets Operator (if external secrets enabled)

## Troubleshooting

Check pod logs:
```bash
kubectl logs -n wordpress deployment/wordpress
```

Verify database connectivity:
```bash
kubectl exec -it -n wordpress deployment/wordpress -- wp db check
```

## Security Notes

- Always use external secrets in production
- Enable TLS/SSL for your domain
- Keep WordPress and plugins updated
- Monitor for security vulnerabilities