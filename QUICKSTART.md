# Quick Start Guide

This guide will help you get your ArgoCD setup running quickly.

## Prerequisites Checklist

- [ ] Kubernetes cluster access
- [ ] `kubectl` configured
- [ ] ArgoCD CLI installed (optional, but recommended)

## Step-by-Step Setup

### 1. Install ArgoCD (5 minutes)

```bash
# Create ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd
```

### 2. Access ArgoCD UI

#### Option A: Port Forward (Development)

```bash
# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo
```

Access: https://localhost:8080
- Username: `admin`
- Password: (from command above)

#### Option B: LoadBalancer (Production)

```bash
# Change service type
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Get external IP
kubectl get svc argocd-server -n argocd
```

### 3. Install ArgoCD CLI (Optional)

```bash
# macOS
brew install argocd

# Linux
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/

# Login
argocd login localhost:8080
```

### 4. Deploy Projects and Bootstrap App

```bash
# Clone this repository
git clone https://github.com/Wandering-Cursor/ontu-schedule-gitops.git
cd ontu-schedule-gitops

# Apply AppProjects
kubectl apply -f argocd/projects/

# Deploy bootstrap app (App-of-Apps)
kubectl apply -f argocd/bootstrap/root-app.yaml
```

### 5. Verify Deployment

```bash
# Check applications
argocd app list

# Or using kubectl
kubectl get applications -n argocd

# Check deployed pods
kubectl get pods -n sealed-secrets
kubectl get pods -n ontu-schedule-dev
kubectl get pods -n ontu-schedule-staging
```

## What Gets Deployed?

After applying the bootstrap app, the following will be automatically deployed:

1. **Sealed Secrets Controller** (namespace: `sealed-secrets`)
   - Manages encrypted secrets in Git

2. **OnTu Schedule Bot Admin - Dev** (namespace: `ontu-schedule-dev`)
   - Development environment
   - Auto-sync enabled
   - Image tag: `develop`

3. **OnTu Schedule Bot Admin - Staging** (namespace: `ontu-schedule-staging`)
   - Staging environment
   - Auto-sync enabled
   - Image tag: `staging`
   - HPA enabled (2-5 replicas)

4. **OnTu Schedule Bot Admin - Prod** (namespace: `ontu-schedule-prod`)
   - Production environment
   - Manual sync (requires approval)
   - Image tag: `v1.0.0`
   - HPA enabled (3-10 replicas)

## Next Steps

### Configure Secrets

If your application needs secrets:

```bash
# Fetch Sealed Secrets certificate
./scripts/seal-secret.sh fetch-cert

# Encrypt a secret (interactive)
./scripts/seal-secret.sh interactive

# Or encrypt a specific value
./scripts/seal-secret.sh encrypt-value \
  my-app-secrets \
  ontu-schedule-dev \
  "my-secret-value"
```

Add the encrypted value to your environment values file and commit.

### Add a New Application

```bash
# Use the helper script
./scripts/create-app.sh

# Or manually follow the guide in README.md
```

### Customize Existing Application

1. Edit environment values in `environments/{dev,staging,prod}/`
2. Commit and push
3. ArgoCD will automatically sync (except prod, which requires manual sync)

## Troubleshooting

### Applications Not Syncing

```bash
# Check application status
argocd app get <app-name>

# View sync errors
argocd app sync <app-name> --dry-run

# Force sync
argocd app sync <app-name> --force
```

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n <namespace>

# View pod logs
kubectl logs -n <namespace> <pod-name>

# Describe pod for events
kubectl describe pod -n <namespace> <pod-name>
```

### Image Pull Errors

Since you're using public GHCR images, you shouldn't need credentials. If you see pull errors:

```bash
# Verify image exists and is public
docker pull ghcr.io/wandering-cursor/ontu-schedule-bot-admin:develop

# Check if rate limiting is the issue
kubectl describe pod -n <namespace> <pod-name>
```

If you need to use private images, add `imagePullSecrets` to your values file.

## Common Commands

```bash
# List all applications
argocd app list

# Sync an application
argocd app sync <app-name>

# View application details
argocd app get <app-name>

# View application logs
argocd app logs <app-name>

# Delete an application
argocd app delete <app-name>

# Refresh application (re-query Git)
argocd app refresh <app-name>

# Rollback to previous version
argocd app rollback <app-name>
```

## Production Checklist

Before going to production:

- [ ] Update image tags in `environments/prod/` to specific versions
- [ ] Configure proper ingress with TLS certificates
- [ ] Set up monitoring and alerting
- [ ] Configure backup and disaster recovery
- [ ] Review and adjust resource limits
- [ ] Set up pod disruption budgets
- [ ] Configure network policies
- [ ] Review security contexts
- [ ] Test failover scenarios
- [ ] Document runbooks

## Getting Help

- Check the main [README.md](README.md) for detailed information
- Review [ArgoCD documentation](https://argo-cd.readthedocs.io/)
- Check [Sealed Secrets documentation](https://github.com/bitnami-labs/sealed-secrets)
