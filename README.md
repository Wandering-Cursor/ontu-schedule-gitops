# OnTu Schedule GitOps Repository

This repository contains Helm charts and ArgoCD configuration for deploying the OnTu Schedule applications using GitOps principles.

## Repository Structure

```
.
├── argocd/
│   ├── bootstrap/              # Bootstrap App-of-Apps
│   │   └── root-app.yaml      # Root application managing all apps
│   ├── applications/          # Individual ArgoCD Application manifests
│   │   ├── sealed-secrets.yaml
│   │   ├── ontu-schedule-bot-admin-dev.yaml
│   │   ├── ontu-schedule-bot-admin-staging.yaml
│   │   └── ontu-schedule-bot-admin-prod.yaml
│   └── projects/              # ArgoCD AppProjects
│       ├── default-project.yaml
│       └── ontu-schedule-project.yaml
├── apps/
│   └── ontu-schedule-bot-admin/  # Helm chart for bot admin
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
├── environments/              # Environment-specific configurations
│   ├── dev/
│   ├── staging/
│   └── prod/
└── infrastructure/            # Infrastructure components
    └── sealed-secrets/        # Sealed Secrets controller
```

## Prerequisites

- Kubernetes cluster (v1.24+)
- kubectl configured to access your cluster
- Helm 3.x
- ArgoCD 2.x

## Quick Start

### 1. Install ArgoCD

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward to access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Access ArgoCD UI at https://localhost:8080 (username: `admin`, password: from command above)

### 2. Deploy AppProjects

```bash
kubectl apply -f argocd/projects/
```

### 3. Deploy the Bootstrap App (App-of-Apps)

```bash
kubectl apply -f argocd/bootstrap/root-app.yaml
```

This will automatically deploy:
- Sealed Secrets controller
- OnTu Schedule Bot Admin (dev, staging, prod environments)

### 4. Monitor Deployments

```bash
# Using CLI
argocd app list

# Or watch in the UI
# Navigate to https://localhost:8080
```

## Working with Secrets

This repository uses [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) for managing secrets in Git.

### Install kubeseal CLI

```bash
# macOS
brew install kubeseal

# Linux
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-0.24.0-linux-amd64.tar.gz
tar xfz kubeseal-0.24.0-linux-amd64.tar.gz
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
```

### Fetch the Public Certificate

After deploying Sealed Secrets controller:

```bash
kubeseal --fetch-cert \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=sealed-secrets \
  > pub-cert.pem
```

**⚠️ Important:** Store this certificate securely - you'll need it to encrypt secrets.

### Encrypting Secrets

#### Method 1: Encrypt individual values (recommended for Helm values)

```bash
# Encrypt a secret value
echo -n "my-database-password" | kubeseal --raw \
  --from-file=/dev/stdin \
  --name=ontu-schedule-bot-admin-secrets \
  --namespace=ontu-schedule-dev \
  --cert=pub-cert.pem

# Output: AgBj8... (encrypted value)
```

Add the encrypted value to your environment values file:

```yaml
# environments/dev/ontu-schedule-bot-admin-values.yaml
secrets:
  enabled: true
  data:
    DATABASE_PASSWORD: AgBj8...  # Encrypted value from above
```

#### Method 2: Encrypt entire Secret manifest

```bash
# Create a secret file
cat > secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
  namespace: ontu-schedule-dev
type: Opaque
stringData:
  username: admin
  password: supersecret
EOF

# Encrypt it
kubeseal --cert=pub-cert.pem < secret.yaml > sealed-secret.yaml

# Commit the sealed secret
git add sealed-secret.yaml
git commit -m "Add encrypted secret"
```

### Updating Secrets

1. Encrypt new value with kubeseal
2. Update the environment values file
3. Commit and push
4. ArgoCD will automatically sync the changes

## Adding a New Application

### Step 1: Create Helm Chart

```bash
# Create new app directory
mkdir -p apps/my-new-app
cd apps/my-new-app

# Create Chart.yaml
cat > Chart.yaml <<EOF
apiVersion: v2
name: my-new-app
description: A Helm chart for my-new-app
type: application
version: 0.1.0
appVersion: "1.0.0"
EOF

# Create values.yaml (use ontu-schedule-bot-admin as template)
cp ../ontu-schedule-bot-admin/values.yaml ./values.yaml

# Update values.yaml with your app's configuration
# - Change image.repository to your image
# - Adjust service ports, resources, etc.

# Copy templates (or create your own)
cp -r ../ontu-schedule-bot-admin/templates ./
```

### Step 2: Create Environment Values

```bash
# Create environment-specific values
mkdir -p ../../environments/{dev,staging,prod}

# Create dev values
cat > ../../environments/dev/my-new-app-values.yaml <<EOF
image:
  tag: "develop"

configMap:
  enabled: true
  data:
    ENVIRONMENT: "development"

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 50m
    memory: 64Mi
EOF

# Repeat for staging and prod
```

### Step 3: Create ArgoCD Application Manifest

```bash
cat > ../../argocd/applications/my-new-app-dev.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-new-app-dev
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: ontu-schedule
  
  source:
    repoURL: https://github.com/Wandering-Cursor/ontu-schedule-gitops.git
    targetRevision: HEAD
    path: apps/my-new-app
    helm:
      releaseName: my-new-app
      valueFiles:
        - ../../environments/dev/my-new-app-values.yaml
  
  destination:
    server: https://kubernetes.default.svc
    namespace: ontu-schedule-dev
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

# Create staging and prod application manifests
```

### Step 4: Commit and Push

```bash
git add apps/my-new-app
git add environments/*/my-new-app-values.yaml
git add argocd/applications/my-new-app-*.yaml
git commit -m "Add my-new-app application"
git push
```

ArgoCD will automatically detect and deploy your new application!

## Environment Management

### Development (dev)
- **Namespace:** `ontu-schedule-dev`
- **Sync Policy:** Automated (prune + self-heal)
- **Purpose:** Active development and testing

### Staging (staging)
- **Namespace:** `ontu-schedule-staging`
- **Sync Policy:** Automated (prune + self-heal)
- **Purpose:** Pre-production testing

### Production (prod)
- **Namespace:** `ontu-schedule-prod`
- **Sync Policy:** Manual sync required
- **Purpose:** Production workloads

## Common Operations

### Manually Sync an Application

```bash
argocd app sync ontu-schedule-bot-admin-dev
```

### View Application Status

```bash
argocd app get ontu-schedule-bot-admin-dev
```

### View Application Logs

```bash
argocd app logs ontu-schedule-bot-admin-dev
```

### Rollback an Application

```bash
argocd app rollback ontu-schedule-bot-admin-dev
```

### Delete an Application

```bash
argocd app delete ontu-schedule-bot-admin-dev
```

## Helm Chart Dependencies

To update Sealed Secrets or other chart dependencies:

```bash
cd infrastructure/sealed-secrets
helm dependency update
```

## Troubleshooting

### ArgoCD Application Out of Sync

```bash
# Check diff
argocd app diff ontu-schedule-bot-admin-dev

# Force sync
argocd app sync ontu-schedule-bot-admin-dev --force
```

### Sealed Secret Not Decrypting

```bash
# Check Sealed Secrets controller logs
kubectl logs -n sealed-secrets deployment/sealed-secrets-controller

# Verify the secret was created
kubectl get secret -n ontu-schedule-dev ontu-schedule-bot-admin-secrets
```

### Application Won't Deploy

```bash
# Check ArgoCD application events
kubectl describe application -n argocd ontu-schedule-bot-admin-dev

# Check pod logs
kubectl logs -n ontu-schedule-dev deployment/ontu-schedule-bot-admin
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Update Image Tag
on:
  push:
    tags:
      - 'v*'

jobs:
  update-gitops:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          repository: Wandering-Cursor/ontu-schedule-gitops
          token: ${{ secrets.GITOPS_TOKEN }}
      
      - name: Update image tag
        run: |
          TAG=${GITHUB_REF#refs/tags/}
          yq e ".image.tag = \"$TAG\"" -i environments/prod/ontu-schedule-bot-admin-values.yaml
      
      - name: Commit and push
        run: |
          git config user.name "GitHub Actions"
          git config user.email "actions@github.com"
          git add environments/prod/ontu-schedule-bot-admin-values.yaml
          git commit -m "Update image tag to $TAG"
          git push
```

## Best Practices

1. **Never commit unencrypted secrets** - Always use Sealed Secrets
2. **Use specific image tags** - Avoid `latest` tag in production
3. **Review changes before production** - Use manual sync for prod
4. **Keep environment parity** - Test in dev/staging before prod
5. **Use resource limits** - Prevent resource exhaustion
6. **Enable monitoring** - Add Prometheus/Grafana integration
7. **Implement pod disruption budgets** - For production workloads
8. **Use pull request reviews** - For GitOps repository changes

## References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Sealed Secrets Documentation](https://github.com/bitnami-labs/sealed-secrets)
- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review ArgoCD application logs
3. Consult the official documentation
4. Open an issue in this repository
