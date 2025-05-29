# Security Best Practices

This document outlines security best practices for deploying and maintaining the wauhost infrastructure.

**Note**: For a common security configuration template, see [common-security-template.yaml](common-security-template.yaml)

## Table of Contents

1. [Secret Management](#secret-management)
2. [Network Security](#network-security)
3. [Pod Security](#pod-security)
4. [RBAC Configuration](#rbac-configuration)
5. [Security Scanning](#security-scanning)
6. [Compliance](#compliance)
7. [Incident Response](#incident-response)

## Secret Management

### External Secrets Operator

All secrets are managed through External Secrets Operator, integrating with:
- HashiCorp Vault
- AWS Secrets Manager
- Azure Key Vault
- Google Secret Manager

#### Best Practices

1. **Never commit secrets to Git**
   ```yaml
   # ❌ Bad
   password: "mysecretpassword"
   
   # ✅ Good
   password: ""  # Managed by External Secrets
   ```

2. **Use least privilege access**
   ```yaml
   # External Secret with specific permissions
   apiVersion: external-secrets.io/v1beta1
   kind: ExternalSecret
   metadata:
     name: app-secrets
   spec:
     secretStoreRef:
       name: vault-backend
       kind: ClusterSecretStore
     target:
       name: app-secrets
       creationPolicy: Owner
     data:
     - secretKey: password
       remoteRef:
         key: secret/data/app
         property: password
   ```

3. **Enable secret rotation**
   - Configure automatic rotation in your secret backend
   - Set refreshInterval in ExternalSecret resources
   - Monitor rotation events

### Secret Rotation Procedures

1. **Database Credentials**
   ```bash
   # Update secret in backend
   vault kv put secret/mysql/root password="$(openssl rand -base64 32)"
   
   # Force sync
   kubectl annotate externalsecret mysql-auth force-sync=$(date +%s) --overwrite
   
   # Restart pods to pick up new credentials
   kubectl rollout restart deployment/mysql -n mysql
   ```

2. **API Keys**
   - Generate new keys in provider console
   - Update in secret backend
   - Use rolling update strategy

## Network Security

### Network Policies

All namespaces should have restrictive network policies:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

### Specific Policies

1. **Database Access**
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: mysql-access
     namespace: mysql
   spec:
     podSelector:
       matchLabels:
         app: mysql
     policyTypes:
     - Ingress
     ingress:
     - from:
       - namespaceSelector:
           matchLabels:
             name: wordpress
       - namespaceSelector:
           matchLabels:
             name: ghost
       ports:
       - protocol: TCP
         port: 3306
   ```

2. **Ingress Controller**
   - Restrict to specific source IPs if possible
   - Use rate limiting
   - Enable ModSecurity WAF rules

### TLS Configuration

1. **Enforce TLS 1.2+**
   ```yaml
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: nginx-config
   data:
     ssl-protocols: "TLSv1.2 TLSv1.3"
     ssl-ciphers: "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256"
   ```

2. **Certificate Management**
   - Use cert-manager with Let's Encrypt
   - Monitor certificate expiry
   - Implement HSTS headers

## Pod Security

### Security Contexts

All pods must run with restrictive security contexts:

```yaml
apiVersion: v1
kind: Pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
```

### Pod Security Standards

Enforce Pod Security Standards at namespace level:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

## RBAC Configuration

### Service Accounts

1. **Create specific service accounts**
   ```yaml
   apiVersion: v1
   kind: ServiceAccount
   metadata:
     name: app-sa
     namespace: production
   ```

2. **Bind minimal permissions**
   ```yaml
   apiVersion: rbac.authorization.k8s.io/v1
   kind: Role
   metadata:
     name: app-role
     namespace: production
   rules:
   - apiGroups: [""]
     resources: ["configmaps"]
     verbs: ["get", "list"]
   ```

### Best Practices

1. **Avoid cluster-admin**
   - Use namespace-scoped roles
   - Grant specific permissions only

2. **Regular audits**
   ```bash
   # List all cluster role bindings
   kubectl get clusterrolebindings -o json | \
     jq -r '.items[] | select(.roleRef.name=="cluster-admin") | .metadata.name'
   ```

## Security Scanning

### Container Image Scanning

1. **Pre-deployment scanning**
   ```yaml
   # In CI/CD pipeline
   - name: Scan image
     run: |
       trivy image --severity HIGH,CRITICAL \
         --exit-code 1 \
         myapp:latest
   ```

2. **Runtime scanning**
   - Deploy Falco for runtime security monitoring
   - Use admission controllers like OPA Gatekeeper

### Vulnerability Management

1. **Regular updates**
   ```bash
   # Check for outdated images
   kubectl get pods -A -o json | \
     jq -r '.items[].spec.containers[].image' | \
     sort | uniq
   ```

2. **Automated patching**
   - Use tools like Renovate or Dependabot
   - Implement automated testing for updates

## Compliance

### Logging and Auditing

1. **Enable audit logging**
   ```yaml
   apiVersion: audit.k8s.io/v1
   kind: Policy
   rules:
   - level: RequestResponse
     omitStages:
     - RequestReceived
     resources:
     - group: ""
       resources: ["secrets", "configmaps"]
     namespaces: ["production", "mysql", "minio-system"]
   ```

2. **Centralized logging**
   - Ship logs to SIEM
   - Retain logs per compliance requirements
   - Implement log monitoring and alerting

### Data Protection

1. **Encryption at rest**
   - Enable etcd encryption
   - Use encrypted storage classes
   - Encrypt backups

2. **Encryption in transit**
   - Enforce mTLS between services
   - Use service mesh if needed

## Incident Response

### Preparation

1. **Incident response plan**
   - Document procedures
   - Define roles and responsibilities
   - Regular drills

2. **Break glass procedures**
   ```bash
   # Emergency access script
   #!/bin/bash
   kubectl create serviceaccount emergency-admin -n kube-system
   kubectl create clusterrolebinding emergency-admin \
     --clusterrole=cluster-admin \
     --serviceaccount=kube-system:emergency-admin
   ```

### Detection and Response

1. **Monitoring alerts**
   - Failed authentication attempts
   - Privilege escalation
   - Suspicious pod exec/attach

2. **Containment procedures**
   ```bash
   # Isolate compromised pod
   kubectl label pod suspicious-pod quarantine=true
   kubectl apply -f quarantine-network-policy.yaml
   ```

### Recovery

1. **Backup verification**
   - Test restore procedures regularly
   - Document recovery time objectives

2. **Post-incident review**
   - Document lessons learned
   - Update security procedures
   - Implement additional controls

## Security Checklist

### Pre-deployment

- [ ] All secrets in external secret management
- [ ] Network policies configured
- [ ] Pod security contexts set
- [ ] RBAC properly configured
- [ ] Images scanned for vulnerabilities
- [ ] TLS certificates valid

### Operational

- [ ] Regular security updates applied
- [ ] Audit logs monitored
- [ ] Backup restoration tested
- [ ] Access reviews conducted
- [ ] Incident response drills performed

### Compliance

- [ ] Data encryption enabled
- [ ] Logs retained per policy
- [ ] Access controls documented
- [ ] Security training completed
- [ ] Compliance audits passed

## Additional Resources

- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [OWASP Kubernetes Security](https://owasp.org/www-project-kubernetes-top-ten/)