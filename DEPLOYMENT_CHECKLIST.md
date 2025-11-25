# Deployment Checklist

Use this checklist to deploy your ArgoCD GitOps setup step by step.

## Prerequisites ✅

- [ ] Kubernetes cluster is running and accessible
- [ ] `kubectl` is installed and configured
- [ ] `helm` is installed (v3.x)
- [ ] You have cluster-admin permissions
- [ ] Git repository is ready (this repo)

## Step 1: Commit and Push to Git 📝

```bash
# Add all files
git add .

# Commit
git commit -m "Initial ArgoCD GitOps setup with Sealed Secrets and ontu-schedule-bot-admin"

# Push to GitHub (if not already done)
git remote add origin git@github.com:Wandering-Cursor/ontu-schedule-gitops.git
git branch -M main
git push -u origin main
```

- [ ] All files committed to Git
- [ ] Pushed to GitHub

## Step 2: Install ArgoCD 🚀

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready (may take 2-3 minutes)
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
```

- [ ] ArgoCD namespace created
- [ ] ArgoCD installed
- [ ] All ArgoCD pods are running

Verify:
```bash
kubectl get pods -n argocd
```

## Step 3: Access ArgoCD UI 🖥️

### Option A: Port Forward (Development)

```bash
# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# In a new terminal, get the admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

- [ ] Port forwarding active
- [ ] Admin password retrieved
- [ ] Can access https://localhost:8080
- [ ] Logged in (username: `admin`, password from above)

### Option B: LoadBalancer (Production)

```bash
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
kubectl get svc argocd-server -n argocd
```

- [ ] LoadBalancer created
- [ ] External IP assigned
- [ ] Can access ArgoCD UI

## Step 4: Install ArgoCD CLI (Optional but Recommended) 🔧

```bash
# macOS
brew install argocd

# Linux
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/

# Login
argocd login localhost:8080
# Or with LoadBalancer:
# argocd login <EXTERNAL-IP>
```

- [ ] ArgoCD CLI installed
- [ ] Logged in via CLI

## Step 5: Deploy ArgoCD Projects 📋

```bash
kubectl apply -f argocd/projects/
```

- [ ] `default-project` created
- [ ] `ontu-schedule-project` created

Verify:
```bash
kubectl get appproject -n argocd
```

## Step 6: Deploy Bootstrap App (App-of-Apps) 🎯

```bash
kubectl apply -f argocd/bootstrap/root-app.yaml
```

- [ ] `root-app` Application created
- [ ] ArgoCD starts syncing child applications

Verify:
```bash
# Using CLI
argocd app list

# Or using kubectl
kubectl get applications -n argocd
```

## Step 7: Wait for Initial Sync ⏳

ArgoCD will now automatically deploy all applications. This may take 5-10 minutes.

Expected applications:
- `root-app` → Manages all child apps
- `sealed-secrets` → Infrastructure component
- `ontu-schedule-bot-admin-dev` → Dev environment
- `ontu-schedule-bot-admin-staging` → Staging environment
- `ontu-schedule-bot-admin-prod` → Prod environment (OutOfSync - manual sync)

Monitor in UI or:
```bash
watch kubectl get applications -n argocd
```

- [ ] `sealed-secrets` - Synced
- [ ] `ontu-schedule-bot-admin-dev` - Synced
- [ ] `ontu-schedule-bot-admin-staging` - Synced
- [ ] `ontu-schedule-bot-admin-prod` - OutOfSync (expected, manual sync required)

## Step 8: Verify Deployments 🔍

### Check Sealed Secrets Controller

```bash
kubectl get pods -n sealed-secrets
```

- [ ] `sealed-secrets-controller` pod is running

### Check Dev Environment

```bash
kubectl get pods -n ontu-schedule-dev
kubectl get svc -n ontu-schedule-dev
kubectl get configmap -n ontu-schedule-dev
```

- [ ] `ontu-schedule-bot-admin` pod is running
- [ ] Service created
- [ ] ConfigMap created

### Check Staging Environment

```bash
kubectl get pods -n ontu-schedule-staging
kubectl get hpa -n ontu-schedule-staging
```

- [ ] At least 2 pods running (HPA enabled)
- [ ] HPA created and active

### Check Production (Not Synced Yet)

```bash
kubectl get namespace ontu-schedule-prod
```

- [ ] Namespace exists but no pods yet (manual sync required)

## Step 9: Configure Secrets (If Needed) 🔐

### Fetch Sealed Secrets Certificate

```bash
./scripts/seal-secret.sh fetch-cert
```

- [ ] Certificate saved to `pub-cert.pem`

**⚠️ Important:** Keep this certificate safe! You'll need it to encrypt secrets.

### Encrypt a Test Secret (Optional)

```bash
./scripts/seal-secret.sh interactive
```

Follow the prompts to encrypt a test secret.

- [ ] Successfully encrypted a test secret
- [ ] Added encrypted value to environment values file (if needed)

## Step 10: Test Production Sync 🎬

Production requires manual sync for safety.

### Using ArgoCD UI:
1. Navigate to `ontu-schedule-bot-admin-prod` application
2. Click "SYNC" button
3. Review changes
4. Click "SYNCHRONIZE"

### Using ArgoCD CLI:
```bash
argocd app sync ontu-schedule-bot-admin-prod
```

- [ ] Production application synced
- [ ] Pods running in `ontu-schedule-prod` namespace

Verify:
```bash
kubectl get pods -n ontu-schedule-prod
```

## Step 11: Health Checks ✅

Run these commands to verify everything is healthy:

```bash
# Check all applications
argocd app list

# Check all namespaces
kubectl get pods --all-namespaces | grep ontu-schedule

# Check application health
kubectl get pods -n ontu-schedule-dev
kubectl get pods -n ontu-schedule-staging
kubectl get pods -n ontu-schedule-prod

# Check logs (if pods are running)
kubectl logs -n ontu-schedule-dev deployment/ontu-schedule-bot-admin --tail=50
```

- [ ] All applications show "Healthy" status
- [ ] All pods are running
- [ ] No crash loops or errors in logs

## Step 12: Update Repository Settings 🔧

### Configure GitHub Repository

1. Go to your GitHub repository settings
2. Configure branch protection for `main`:
   - Require pull request reviews
   - Require status checks before merging
   - Require branches to be up to date

- [ ] Branch protection configured

### Add GitHub Secrets (for future CI/CD)

If you plan to add GitHub Actions:
- `GHCR_TOKEN` - For pushing images to GHCR
- `ARGOCD_AUTH_TOKEN` - For ArgoCD API access (optional)

- [ ] Secrets configured (if needed)

## Step 13: Documentation and Onboarding 📚

### Team Onboarding

Share these resources with your team:
- [ ] `README.md` - Main documentation
- [ ] `QUICKSTART.md` - Quick start guide
- [ ] `docs/ARCHITECTURE.md` - Architecture overview
- [ ] `docs/GHCR_IMAGES.md` - Container images guide

### Change Password

```bash
# Update ArgoCD admin password
argocd account update-password
```

- [ ] Admin password changed from default
- [ ] New password stored securely

### Create Additional Users (Optional)

```bash
# Edit argocd-cm ConfigMap to add users
kubectl edit configmap argocd-cm -n argocd
```

- [ ] Additional users created (if needed)
- [ ] RBAC configured per project

## Next Steps 🚀

### Immediate Actions

- [ ] Test a deployment by updating an image tag in environment values
- [ ] Practice the secrets workflow with a test secret
- [ ] Familiarize team with ArgoCD UI

### Short-term Enhancements

- [ ] Configure ingress for applications with TLS
- [ ] Set up monitoring (Prometheus + Grafana)
- [ ] Add centralized logging (Loki or ELK)
- [ ] Create pod disruption budgets for production

### Long-term Improvements

- [ ] Implement CI/CD pipeline for image builds
- [ ] Add automated testing in pipelines
- [ ] Set up disaster recovery procedures
- [ ] Configure alerts and notifications
- [ ] Add more applications using `./scripts/create-app.sh`

## Troubleshooting 🔧

### Application Won't Sync

```bash
# Check application details
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

# Describe pod for events
kubectl describe pod -n <namespace> <pod-name>

# Check logs
kubectl logs -n <namespace> <pod-name>
```

### Image Pull Errors

Since GHCR images are public, this shouldn't happen. If it does:

```bash
# Test pulling image directly
docker pull ghcr.io/wandering-cursor/ontu-schedule-bot-admin:develop

# Check pod events
kubectl describe pod -n <namespace> <pod-name>
```

## Success Criteria ✨

Your deployment is successful when:

- ✅ All ArgoCD applications show "Healthy" and "Synced" status
- ✅ Pods are running in all environments (dev, staging, prod)
- ✅ Sealed Secrets controller is running
- ✅ ConfigMaps are created with correct values
- ✅ You can update an application by changing Git and seeing it deploy
- ✅ Production requires manual sync (security measure working)
- ✅ Team members can access and understand the documentation

## Support Resources 📞

- **Documentation**: Check `README.md` and `docs/`
- **ArgoCD Docs**: https://argo-cd.readthedocs.io/
- **Sealed Secrets**: https://github.com/bitnami-labs/sealed-secrets
- **Helm Docs**: https://helm.sh/docs/

---

**Congratulations!** 🎉 Your GitOps setup is complete and ready for production use!
