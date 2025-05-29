# Longhorn Security Configuration Guide

This guide explains how to configure HTTPS + IP whitelisting for the Longhorn UI to ensure secure access to your storage management interface.

## Security Architecture

The security implementation follows a defense-in-depth approach with multiple layers:

1. **Network Level**: IP whitelisting restricts access to authorized networks only
2. **Transport Level**: HTTPS/TLS encryption for all traffic
3. **Application Level**: Basic authentication with secure password storage
4. **Secret Management**: External secrets integration with Vault

## Configuration Steps

### 1. Update DNS Configuration

Replace the default `longhorn.local` with your actual domain:

```yaml
longhorn:
  ui:
    host: "longhorn.storage.example.com"  # Your actual domain
```

### 2. Configure IP Whitelist

Update the allowed IP ranges in your values file:

```yaml
longhorn:
  ui:
    security:
      ipWhitelist:
        enabled: true
        sourceRange: "198.51.100.0/24,203.0.113.10/32"  # Your allowed IPs
```

Common configurations:
- Single IP: `"203.0.113.10/32"`
- Office network: `"198.51.100.0/24"`
- Multiple ranges: `"198.51.100.0/24,203.0.113.0/24"`
- VPN + Office: `"10.8.0.0/16,198.51.100.0/24"`

### 3. Enable HTTPS

Ensure TLS is enabled and cert-manager is configured:

```yaml
longhorn:
  ui:
    tls:
      enabled: true
    clusterIssuer: "letsencrypt"  # Must exist in your cluster
```

### 4. Deploy with Security

```bash
# Using your main values.yaml
helm upgrade --install longhorn ./charts/longhorn \
  --namespace longhorn-system \
  --create-namespace \
  --values values.yaml
```

## Security Features

### HTTPS/TLS
- Automatic certificate provisioning via cert-manager
- Let's Encrypt production certificates
- Forced HTTPS redirect
- HSTS (HTTP Strict Transport Security) enabled

### IP Whitelisting
- Restricts access at ingress level
- Supports multiple IP ranges
- Works with both IPv4 and IPv6
- Handles X-Forwarded-For headers correctly

### Security Headers
- **HSTS**: Forces HTTPS for 2 years with preload
- **X-Frame-Options**: Prevents clickjacking attacks
- **X-Content-Type-Options**: Prevents MIME type sniffing
- **Referrer-Policy**: Controls referrer information
- **X-XSS-Protection**: Enables browser XSS filter

### Authentication
- Basic authentication with bcrypt-hashed passwords
- Credentials stored in Kubernetes secrets
- External secrets integration for production
- Auth handled by Traefik middleware

### Rate Limiting (Optional)
- Prevents brute force attacks
- Configurable rate limits per IP
- Burst allowance for legitimate traffic

## Traefik Middleware

The chart creates Traefik middleware resources for:
- Basic authentication
- Rate limiting (if enabled)
- HTTPS redirect (if needed)

## Verification

### Check Certificate

```bash
# Verify certificate is issued
kubectl get certificate -n longhorn-system
kubectl describe certificate longhorn-tls -n longhorn-system

# Check ingress
kubectl get ingress -n longhorn-system longhorn-ui -o yaml
```

### Test Access

```bash
# Test from allowed IP (should work)
curl -I https://longhorn.storage.example.com

# Test from non-whitelisted IP (should get 403)
curl -I https://longhorn.storage.example.com
```

### Verify Security Headers

```bash
# Check security headers
curl -I https://longhorn.storage.example.com | grep -i "strict-transport-security\|x-frame-options\|x-content-type"
```

## Troubleshooting

### 403 Forbidden Error
- Check if your IP is in the whitelist
- Verify sourceRange format is correct
- Check Traefik logs for IP information

### Certificate Issues
- Ensure DNS is properly configured
- Check cert-manager logs
- Verify ClusterIssuer exists and is ready

### Authentication Problems
- Verify auth secret exists
- Check middleware is created
- Ensure htpasswd format is correct

### IP Whitelist Not Working
- Check if behind a proxy/load balancer
- May need to configure `externalTrafficPolicy: Local`
- Verify X-Forwarded-For handling

## Best Practices

1. **Regular Updates**
   - Keep IP whitelist current
   - Rotate authentication credentials
   - Update certificates before expiry

2. **Monitoring**
   - Monitor failed authentication attempts
   - Track access from unusual IPs
   - Alert on certificate expiry

3. **Backup Access**
   - Document IP whitelist entries
   - Have emergency access procedures
   - Keep offline credential backup

4. **Network Segmentation**
   - Use dedicated management network if possible
   - Consider VPN for remote access
   - Implement network policies for pod-to-pod traffic

## Security Checklist

- [ ] Real domain configured (not .local)
- [ ] IP whitelist contains only authorized networks
- [ ] HTTPS/TLS enabled with valid certificate
- [ ] Strong passwords for basic auth
- [ ] External secrets configured for production
- [ ] Security headers enabled
- [ ] Rate limiting configured (optional)
- [ ] Network policies implemented (optional)
- [ ] Regular security audits scheduled
- [ ] Backup access procedures documented