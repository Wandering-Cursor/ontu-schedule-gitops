# Sealed Secrets Guide

This guide explains how to use Sealed Secrets to securely manage sensitive data in your GitOps repository.

## 📖 Table of Contents

- [What are Sealed Secrets?](#what-are-sealed-secrets)
- [Why Use Sealed Secrets?](#why-use-sealed-secrets)
- [Installation](#installation)
- [Basic Usage](#basic-usage)
- [Advanced Usage](#advanced-usage)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## What are Sealed Secrets?

Sealed Secrets is a Kubernetes controller and tool for one-way encrypted Secrets. It allows you to:

- **Encrypt** Kubernetes Secrets into SealedSecret resources
- **Commit** encrypted secrets safely to Git
- **Decrypt** secrets automatically in your cluster

The encryption is asymmetric - you can encrypt with a public key, but only the controller in your cluster can decrypt with its private key.

## Why Use Sealed Secrets?

### The Problem

Standard Kubernetes Secrets are base64-encoded, **not encrypted**. Committing them to Git is a security risk:

```yaml
# ❌ NEVER commit this to Git!
apiVersion: v1
kind: Secret
metadata:
  name: database
stringData:
  password: "my-secret-password"  # Visible to anyone with repo access!
```

### The Solution

Sealed Secrets encrypt your secrets so they're safe to commit:

```yaml
# ✅ Safe to commit to Git
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: database
spec:
  encryptedData:
    password: AgBQ7... # Encrypted - only cluster can decrypt
```

## Installation

### 1. Install Sealed Secrets Controller

```bash
# Install the controller using Helm
helm install sealed-secrets infrastructure/sealed-secrets -n kube-system

# Verify installation
kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets
```

### 2. Install kubeseal CLI

The `kubeseal` CLI is used to encrypt secrets locally.

**On macOS:**
```bash
brew install kubeseal
```

**On Linux:**
```bash
# Download the latest release
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-0.24.0-linux-amd64.tar.gz

# Extract and install
tar -xvf kubeseal-0.24.0-linux-amd64.tar.gz
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
```

**Verify installation:**
```bash
kubeseal --version
```

### 3. Fetch the Public Key

```bash
# Get the public key from your cluster
kubeseal --fetch-cert > pub-cert.pem

# This file is safe to commit (it's the public key)
# But it's already in .gitignore for convenience
```

## Basic Usage

### Example 1: Database Password

**Step 1: Create a regular Secret (don't apply it!)**

```bash
kubectl create secret generic postgresql \
  --from-literal=username=postgres \
  --from-literal=password=my-secure-password \
  --from-literal=database=ontu_schedule \
  --dry-run=client -o yaml > secret.yaml
```

**Step 2: Seal the Secret**

```bash
kubeseal -f secret.yaml -w postgresql-sealed.yaml
```

**Step 3: Commit and Apply**

```bash
# The sealed secret is safe to commit
git add postgresql-sealed.yaml
git commit -m "Add PostgreSQL sealed secret"

# Apply to cluster
kubectl apply -f postgresql-sealed.yaml
```

**Step 4: Verify**

```bash
# Check that SealedSecret was created
kubectl get sealedsecrets

# Check that Secret was created by the controller
kubectl get secret postgresql

# View the decrypted secret (requires RBAC permissions)
kubectl get secret postgresql -o yaml
```

### Example 2: Bot Token

```bash
# Create secret
kubectl create secret generic ontu-schedule-bot-token \
  --from-literal=token=123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11 \
  --dry-run=client -o yaml > bot-token.yaml

# Seal it
kubeseal -f bot-token.yaml -w bot-token-sealed.yaml

# Apply
kubectl apply -f bot-token-sealed.yaml

# Cleanup temporary file
rm bot-token.yaml
```

### Example 3: Multiple Secrets from Files

```bash
# Create secret from multiple files
kubectl create secret generic app-config \
  --from-file=api-key.txt \
  --from-file=jwt-secret.txt \
  --from-literal=db-password=secret123 \
  --dry-run=client -o yaml > app-config.yaml

# Seal it
kubeseal -f app-config.yaml -w app-config-sealed.yaml

# Apply
kubectl apply -f app-config-sealed.yaml
```

## Advanced Usage

### Using a Specific Namespace

```bash
# Seal for a specific namespace
kubeseal -f secret.yaml -w sealed.yaml --namespace production

# Or include namespace in the original secret
kubectl create secret generic my-secret \
  --from-literal=key=value \
  --namespace production \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > sealed.yaml
```

### Using Offline Mode

If you can't access the cluster:

```bash
# Use the previously fetched certificate
kubeseal -f secret.yaml -w sealed.yaml --cert pub-cert.pem
```

### Re-encrypting After Certificate Rotation

```bash
# Decrypt sealed secret (requires cluster access)
kubeseal --recovery-unseal --recovery-private-key key.pem \
  -f sealed-secret.yaml -o yaml > secret.yaml

# Re-encrypt with new certificate
kubeseal -f secret.yaml -w new-sealed-secret.yaml
```

### Scope Options

Sealed Secrets support different scopes:

1. **strict** (default): Secret is sealed to specific name and namespace
2. **namespace-wide**: Can be renamed within the same namespace
3. **cluster-wide**: Can be used anywhere in the cluster

```bash
# Namespace-wide scope
kubeseal -f secret.yaml -w sealed.yaml --scope namespace-wide

# Cluster-wide scope
kubeseal -f secret.yaml -w sealed.yaml --scope cluster-wide
```

## Best Practices

### 1. Never Commit Unsealed Secrets

```bash
# Add to .gitignore
echo "secret.yaml" >> .gitignore
echo "*-secret.yaml" >> .gitignore
echo "!*-sealed.yaml" >> .gitignore
```

### 2. Store Public Certificate

```bash
# Fetch and store public cert in repo (optional)
kubeseal --fetch-cert > pub-cert.pem
git add pub-cert.pem
```

This allows sealing secrets without cluster access.

### 3. Use Descriptive Names

```yaml
# ✅ Good
kind: SealedSecret
metadata:
  name: postgresql-credentials
  
# ❌ Avoid
kind: SealedSecret
metadata:
  name: secret1
```

### 4. Organize by Environment

```
environments/
├── production/
│   ├── postgresql-sealed.yaml
│   ├── bot-token-sealed.yaml
│   └── dragonfly-sealed.yaml
└── staging/
    ├── postgresql-sealed.yaml
    └── bot-token-sealed.yaml
```

### 5. Backup Private Keys

The controller's private key is stored in a Secret:

```bash
# Backup the private key (KEEP THIS SECURE!)
kubectl get secret -n kube-system sealed-secrets-key -o yaml > sealed-secrets-key-backup.yaml

# Store in a secure location (not in Git!)
# Use a password manager, vault, or encrypted storage
```

### 6. Rotate Secrets Regularly

```bash
# Create new secret
kubectl create secret generic postgresql \
  --from-literal=password=new-password \
  --dry-run=client -o yaml > secret.yaml

# Seal with updated password
kubeseal -f secret.yaml -w postgresql-sealed.yaml

# Apply (will update existing secret)
kubectl apply -f postgresql-sealed.yaml

# Cleanup
rm secret.yaml
```

### 7. Test in Development First

Before deploying to production:

```bash
# Test in development namespace
kubectl create namespace dev
kubectl apply -f sealed-secret.yaml -n dev
kubectl get secret -n dev
```

## Integration with Helm Charts

### Method 1: Pre-create Sealed Secrets

Create sealed secrets before deploying Helm charts:

```bash
# Create and apply sealed secrets
kubectl apply -f postgresql-sealed.yaml
kubectl apply -f bot-token-sealed.yaml

# Deploy Helm chart (references existing secrets)
helm install app ./chart -f values.yaml
```

### Method 2: Include in Helm Templates

You can include SealedSecret resources in Helm charts:

```yaml
# templates/sealedsecret.yaml
{{- if .Values.sealedSecrets.enabled }}
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: {{ include "app.fullname" . }}
spec:
  encryptedData:
    password: {{ .Values.sealedSecrets.encryptedPassword }}
{{- end }}
```

## Troubleshooting

### Secret Not Being Created

**Problem**: SealedSecret exists but Secret is not created.

```bash
# Check SealedSecret status
kubectl get sealedsecret my-secret -o yaml

# Check controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=sealed-secrets

# Common issues:
# - Wrong namespace
# - Certificate mismatch
# - Controller not running
```

### Certificate Issues

**Problem**: "error: cannot fetch certificate"

```bash
# Verify controller is running
kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets

# Check service
kubectl get svc -n kube-system sealed-secrets

# Manual fetch with debug
kubeseal --fetch-cert --controller-name sealed-secrets \
  --controller-namespace kube-system -v 9
```

### Decryption Failures

**Problem**: "error: failed to unseal"

**Causes**:
- Sealed with different certificate
- Namespace mismatch (strict scope)
- Name mismatch (strict scope)

**Solution**:
```bash
# Re-seal with correct parameters
kubeseal -f secret.yaml -w sealed.yaml \
  --namespace correct-namespace \
  --name correct-name
```

### Updating Sealed Secrets

**Problem**: Need to update a sealed secret.

```bash
# Method 1: Create new version
kubectl create secret generic my-secret \
  --from-literal=key=new-value \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > my-secret-sealed.yaml

kubectl apply -f my-secret-sealed.yaml

# Method 2: Delete and recreate
kubectl delete sealedsecret my-secret
kubectl apply -f new-sealed-secret.yaml
```

## Examples

### Complete PostgreSQL Example

```bash
# 1. Create the secret
cat <<EOF > postgresql-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgresql
  namespace: default
type: Opaque
stringData:
  username: postgres
  password: $(openssl rand -base64 32)
  database: ontu_schedule
EOF

# 2. Seal it
kubeseal -f postgresql-secret.yaml -w postgresql-sealed.yaml

# 3. View sealed secret (safe to commit)
cat postgresql-sealed.yaml

# 4. Apply to cluster
kubectl apply -f postgresql-sealed.yaml

# 5. Verify
kubectl get secret postgresql
kubectl get sealedsecret postgresql

# 6. Cleanup temp file
rm postgresql-secret.yaml

# 7. Commit sealed secret
git add postgresql-sealed.yaml
git commit -m "Add PostgreSQL credentials"
```

### Complete Bot Token Example

```bash
# 1. Create secret with bot token
kubectl create secret generic ontu-schedule-bot-token \
  --from-literal=token="${BOT_TOKEN}" \
  --dry-run=client -o yaml > bot-token.yaml

# 2. Seal it
kubeseal -f bot-token.yaml -w bot-token-sealed.yaml

# 3. Apply
kubectl apply -f bot-token-sealed.yaml

# 4. Verify bot can access it
kubectl get secret ontu-schedule-bot-token -o jsonpath='{.data.token}' | base64 -d

# 5. Cleanup and commit
rm bot-token.yaml
git add bot-token-sealed.yaml
git commit -m "Add bot token"
```

## Additional Resources

- [Sealed Secrets GitHub](https://github.com/bitnami-labs/sealed-secrets)
- [Official Documentation](https://sealed-secrets.netlify.app/)
- [Kubeseal CLI Reference](https://github.com/bitnami-labs/sealed-secrets#usage)

## Summary

Sealed Secrets enable secure GitOps workflows by:
- ✅ Encrypting secrets for safe Git storage
- ✅ Automatic decryption in the cluster
- ✅ No need for external secret management services
- ✅ Simple to use and understand

Remember: **Never commit unsealed secrets to Git!**
