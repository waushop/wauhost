# Sealed Secrets

Encrypted secrets stored in git. The Sealed Secrets controller decrypts them into regular Kubernetes Secrets.

## Creating a sealed secret

1. Write a regular secret:

```bash
kubectl create secret generic mysql-secret \
  --namespace mysql \
  --from-literal=mysql-root-password=YOUR_PASSWORD \
  --dry-run=client -o yaml > /tmp/secret.yaml
```

2. Encrypt it with kubeseal:

```bash
kubeseal --controller-name sealed-secrets --controller-namespace sealed-secrets \
  --format yaml < /tmp/secret.yaml > secrets/mysql.yaml
rm /tmp/secret.yaml
```

3. Commit and apply:

```bash
git add secrets/mysql.yaml
git commit -m "add mysql sealed secret"
kubectl apply -f secrets/mysql.yaml
```

## Applying all secrets

```bash
kubectl apply -f secrets/
```

## Rotating a secret

Same process as creating — kubeseal will produce a new encrypted value. Commit and apply.

## Files

| File | Namespace | Secret Name | Keys |
|------|-----------|-------------|------|
| mysql.yaml | mysql | mysql-secret | mysql-root-password |
| agrofort.yaml | agrofort | web-secrets | DB_PASSWORD, JWT_SECRET, RESEND_API_KEY, + 11 more |
| kraman.yaml | kraman | web-secrets | DB_PASSWORD, DB_USER, JWT_SECRET, SMTP creds, + 8 more |
| onebetwonder.yaml | onebetwonder | web-secrets | DB_PASSWORD, JWT_SECRET, SYNC_SECRET, WC2026_API_KEY |
| vausiim.yaml | vausiim | vausiim-ghost-secrets | database__connection__password, mail__options__auth__pass |
