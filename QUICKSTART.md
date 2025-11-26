# Quick Start Guide

Get started with the ONTU Schedule GitOps repository in minutes.

## 🎯 What You'll Deploy

- **Admin Backend**: API service with PostgreSQL and Dragonfly cache
- **Bot Client**: User-facing bot that communicates with admin backend
- **PostgreSQL**: Database for persistent data
- **Dragonfly**: Redis-compatible cache
- **Sealed Secrets**: Secure secret management
- **Example NGINX**: Demo app showing best practices

## ⚡ Quick Start (5 minutes)

### Prerequisites

```bash
# Required
kubectl version        # v1.24+
helm version          # v3.x
kubeseal --version    # latest

# Your cluster should be running
kubectl cluster-info
```

### Step 1: Install Sealed Secrets

```bash
cd ontu-schedule-gitops
helm install sealed-secrets infrastructure/sealed-secrets -n kube-system
kubeseal --fetch-cert > pub-cert.pem
```

### Step 2: Create Secrets

```bash
# PostgreSQL password
kubectl create secret generic postgresql \
  --from-literal=username=postgres \
  --from-literal=password=$(openssl rand -base64 32) \
  --from-literal=database=ontu_schedule \
  --dry-run=client -o yaml | kubeseal -o yaml | kubectl apply -f -

# Bot token (replace with your token)
kubectl create secret generic ontu-schedule-bot-token \
  --from-literal=token=YOUR_BOT_TOKEN \
  --dry-run=client -o yaml | kubeseal -o yaml | kubectl apply -f -
```

### Step 3: Deploy Infrastructure

```bash
# PostgreSQL
helm install postgresql infrastructure/postgresql \
  -f environments/production/postgresql.yaml

# Dragonfly
helm install dragonfly infrastructure/dragonfly \
  -f environments/production/dragonfly.yaml

# Wait for them to be ready
kubectl wait --for=condition=ready --timeout=120s pod/postgresql-0
kubectl wait --for=condition=ready --timeout=120s pod/dragonfly-0
```

### Step 4: Deploy Applications

```bash
# Update image repositories in values files first!
# Edit: environments/production/ontu-schedule-bot-admin.yaml
# Edit: environments/production/ontu-schedule-bot.yaml

# Admin backend
helm install ontu-schedule-bot-admin apps/ontu-schedule-bot-admin \
  -f environments/production/ontu-schedule-bot-admin.yaml

# Bot client
helm install ontu-schedule-bot apps/ontu-schedule-bot \
  -f environments/production/ontu-schedule-bot.yaml

# Example app (optional)
helm install example-nginx apps/example-nginx \
  -f environments/production/example-nginx.yaml
```

### Step 5: Verify

```bash
# Check everything is running
kubectl get pods

# Test admin backend
kubectl port-forward svc/ontu-schedule-bot-admin 8080:8080
curl http://localhost:8080/health/ready

# Test example nginx
kubectl port-forward svc/example-nginx 8081:80
# Visit http://localhost:8081
```

## 📖 What's Next?

### Configure Your Domain

Edit `environments/production/ontu-schedule-bot-admin.yaml`:

```yaml
ingress:
  hosts:
    - host: api.yourdomain.com  # Change this!
```

Then upgrade:

```bash
helm upgrade ontu-schedule-bot-admin apps/ontu-schedule-bot-admin \
  -f environments/production/ontu-schedule-bot-admin.yaml
```

### Update Your Images

Edit the values files to use your actual Docker images:

```yaml
image:
  repository: ghcr.io/your-org/ontu-schedule-bot-admin
  tag: "v1.0.0"  # Use specific versions, not 'latest'
```

### Enable Autoscaling

Already configured for admin backend! It will scale from 3 to 10 replicas based on CPU/memory.

### Set Up TLS

If you have cert-manager installed:

```yaml
ingress:
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  tls:
    - secretName: your-tls-secret
      hosts:
        - api.yourdomain.com
```

## 🔧 Common Tasks

### View Logs

```bash
# Admin backend logs
kubectl logs -l app.kubernetes.io/name=ontu-schedule-bot-admin -f

# Bot logs
kubectl logs -l app.kubernetes.io/name=ontu-schedule-bot -f

# PostgreSQL logs
kubectl logs postgresql-0
```

### Scale Applications

```bash
# Manual scaling
kubectl scale deployment ontu-schedule-bot-admin --replicas=5

# Or via Helm
helm upgrade ontu-schedule-bot-admin apps/ontu-schedule-bot-admin \
  --set replicaCount=5 \
  -f environments/production/ontu-schedule-bot-admin.yaml
```

### Update Application

```bash
# Update image tag in values file
# Then upgrade
helm upgrade ontu-schedule-bot-admin apps/ontu-schedule-bot-admin \
  -f environments/production/ontu-schedule-bot-admin.yaml

# Watch rollout
kubectl rollout status deployment/ontu-schedule-bot-admin
```

### Backup Database

```bash
# PostgreSQL backup
kubectl exec postgresql-0 -- pg_dump -U postgres ontu_schedule > backup.sql

# Restore
cat backup.sql | kubectl exec -i postgresql-0 -- psql -U postgres ontu_schedule
```

### Update Secrets

```bash
# Create new sealed secret
kubectl create secret generic postgresql \
  --from-literal=password=new-password \
  --dry-run=client -o yaml | kubeseal -o yaml | kubectl apply -f -

# Restart affected pods
kubectl rollout restart statefulset/postgresql
kubectl rollout restart deployment/ontu-schedule-bot-admin
```

## 🐛 Troubleshooting

### Pods Not Starting?

```bash
# Check events
kubectl get events --sort-by='.lastTimestamp'

# Describe pod
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name>
```

### Can't Connect to Database?

```bash
# Test from within cluster
kubectl run -it --rm psql-test --image=postgres:15-alpine --restart=Never -- \
  psql -h postgresql -U postgres -d ontu_schedule

# Check PostgreSQL is running
kubectl get pods -l app.kubernetes.io/name=postgresql
```

### Ingress Not Working?

```bash
# Check ingress controller is running
kubectl get pods -n ingress-nginx

# Check ingress resource
kubectl describe ingress ontu-schedule-bot-admin

# Test service directly
kubectl port-forward svc/ontu-schedule-bot-admin 8080:8080
```

### Sealed Secret Not Decrypting?

```bash
# Check controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=sealed-secrets

# Verify SealedSecret exists
kubectl get sealedsecret

# Verify Secret was created
kubectl get secret
```

## 📚 Learn More

- [Full Deployment Guide](docs/deployment-guide.md) - Detailed deployment instructions
- [Sealed Secrets Guide](docs/sealed-secrets-guide.md) - Everything about secrets
- [Architecture Overview](docs/architecture.md) - System design and components
- [Chart READMEs](apps/) - Specific chart documentation

## 🎓 Example: From Zero to Running

Complete example workflow:

```bash
# 1. Clone repo
git clone https://github.com/Wandering-Cursor/ontu-schedule-gitops.git
cd ontu-schedule-gitops

# 2. Install sealed secrets
helm install sealed-secrets infrastructure/sealed-secrets -n kube-system
kubectl wait --for=condition=available --timeout=60s deployment/sealed-secrets -n kube-system

# 3. Create secrets
kubectl create secret generic postgresql \
  --from-literal=username=postgres \
  --from-literal=password=supersecret123 \
  --from-literal=database=ontu_schedule \
  --dry-run=client -o yaml | kubeseal -o yaml | kubectl apply -f -

kubectl create secret generic ontu-schedule-bot-token \
  --from-literal=token=123456:ABC-DEF1234 \
  --dry-run=client -o yaml | kubeseal -o yaml | kubectl apply -f -

# 4. Deploy infrastructure
helm install postgresql infrastructure/postgresql \
  -f environments/production/postgresql.yaml
helm install dragonfly infrastructure/dragonfly \
  -f environments/production/dragonfly.yaml

# 5. Wait for infrastructure
kubectl wait --for=condition=ready --timeout=120s pod/postgresql-0
kubectl wait --for=condition=ready --timeout=120s pod/dragonfly-0

# 6. Deploy applications
# (After updating image repositories in values files)
helm install ontu-schedule-bot-admin apps/ontu-schedule-bot-admin \
  -f environments/production/ontu-schedule-bot-admin.yaml
helm install ontu-schedule-bot apps/ontu-schedule-bot \
  -f environments/production/ontu-schedule-bot.yaml

# 7. Verify everything
kubectl get pods
kubectl get svc
kubectl get ingress

# 8. Test
kubectl port-forward svc/ontu-schedule-bot-admin 8080:8080
# In another terminal:
curl http://localhost:8080/health/ready
```

## ✅ Production Checklist

Before going to production:

- [ ] Update all image repositories to your actual images
- [ ] Use specific version tags, not `latest`
- [ ] Create strong passwords for all secrets
- [ ] Configure your actual domain names
- [ ] Set up TLS certificates (cert-manager + Let's Encrypt)
- [ ] Configure ingress controller properly
- [ ] Set appropriate resource limits based on your needs
- [ ] Enable monitoring (Prometheus/Grafana)
- [ ] Set up log aggregation
- [ ] Configure backup strategy
- [ ] Test disaster recovery
- [ ] Review security contexts
- [ ] Enable pod security policies
- [ ] Set up alerts
- [ ] Document your custom configurations

## 🆘 Need Help?

1. Check the [Troubleshooting](#-troubleshooting) section
2. Review [docs/deployment-guide.md](docs/deployment-guide.md)
3. Check application logs
4. Review Kubernetes events
5. Ensure all prerequisites are met

## 🎉 Success!

You now have a production-ready GitOps repository with:
- ✅ Infrastructure as Code (Helm charts)
- ✅ Secure secret management (Sealed Secrets)
- ✅ Autoscaling and high availability
- ✅ Health checks and monitoring readiness
- ✅ Comprehensive documentation
- ✅ Production-grade configurations
- ✅ Best practices implemented

Happy deploying! 🚀
