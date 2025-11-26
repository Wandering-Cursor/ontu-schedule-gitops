# Deployment Guide

Complete step-by-step guide for deploying the ONTU Schedule application stack.

## 📋 Prerequisites

Before you begin, ensure you have:

- **Kubernetes Cluster** (v1.24+)
  - Local: minikube, kind, k3s
  - Cloud: GKE, EKS, AKS, DigitalOcean Kubernetes
  - On-premise: kubeadm, Rancher

- **Tools Installed**:
  - `kubectl` (v1.24+)
  - `helm` (v3.x)
  - `kubeseal` (for sealed secrets)
  - `git`

- **Cluster Access**:
  - kubectl configured and connected to your cluster
  - Appropriate RBAC permissions

- **Optional**:
  - Ingress controller (nginx-ingress recommended)
  - cert-manager (for automatic TLS certificates)

## 🔍 Pre-Deployment Checklist

- [ ] Kubernetes cluster is running and accessible
- [ ] kubectl can communicate with cluster: `kubectl cluster-info`
- [ ] Helm 3 is installed: `helm version`
- [ ] Namespace created (if using non-default): `kubectl create namespace production`
- [ ] Ingress controller installed (if using ingress)
- [ ] cert-manager installed (if using TLS)
- [ ] DNS records configured (if using custom domains)

## 📦 Deployment Steps

### Step 1: Clone the Repository

```bash
git clone https://github.com/Wandering-Cursor/ontu-schedule-gitops.git
cd ontu-schedule-gitops
```

### Step 2: Install Infrastructure Components

#### 2.1 Install Sealed Secrets Controller

This must be installed first to decrypt other secrets.

```bash
# Install in kube-system namespace
helm install sealed-secrets infrastructure/sealed-secrets -n kube-system

# Wait for deployment
kubectl wait --for=condition=available --timeout=60s \
  deployment/sealed-secrets -n kube-system

# Verify installation
kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets

# Fetch the public certificate
kubeseal --fetch-cert > pub-cert.pem
```

#### 2.2 Create Secrets

Before deploying PostgreSQL and Dragonfly, create their secrets.

**PostgreSQL Secret:**

```bash
# Generate a strong password
PG_PASSWORD=$(openssl rand -base64 32)

# Create and seal the secret
kubectl create secret generic postgresql \
  --from-literal=username=postgres \
  --from-literal=password="${PG_PASSWORD}" \
  --from-literal=database=ontu_schedule \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > postgresql-sealed.yaml

# Apply sealed secret
kubectl apply -f postgresql-sealed.yaml

# Verify
kubectl get sealedsecret postgresql
kubectl get secret postgresql
```

**Dragonfly Secret (Optional - if using authentication):**

```bash
# Generate password
DRAGONFLY_PASSWORD=$(openssl rand -base64 32)

# Create and seal
kubectl create secret generic dragonfly \
  --from-literal=password="${DRAGONFLY_PASSWORD}" \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > dragonfly-sealed.yaml

# Apply
kubectl apply -f dragonfly-sealed.yaml
```

**Bot Token Secret:**

```bash
# Replace with your actual bot token
BOT_TOKEN="your-actual-bot-token-here"

# Create and seal
kubectl create secret generic ontu-schedule-bot-token \
  --from-literal=token="${BOT_TOKEN}" \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > bot-token-sealed.yaml

# Apply
kubectl apply -f bot-token-sealed.yaml
```

#### 2.3 Install PostgreSQL

```bash
# Install with production values
helm install postgresql infrastructure/postgresql \
  -f environments/production/postgresql.yaml

# Wait for StatefulSet to be ready
kubectl wait --for=condition=ready --timeout=120s pod/postgresql-0

# Verify
kubectl get pods -l app.kubernetes.io/name=postgresql
kubectl get pvc  # Check persistent volume claim
kubectl get svc postgresql
```

**Test Connection:**

```bash
# Get password from secret
PGPASSWORD=$(kubectl get secret postgresql -o jsonpath='{.data.password}' | base64 -d)

# Connect to PostgreSQL
kubectl run -it --rm psql-client --image=postgres:15-alpine --restart=Never -- \
  psql -h postgresql -U postgres -d ontu_schedule -c '\l'
```

#### 2.4 Install Dragonfly

```bash
# Install with production values
helm install dragonfly infrastructure/dragonfly \
  -f environments/production/dragonfly.yaml

# Wait for StatefulSet
kubectl wait --for=condition=ready --timeout=120s pod/dragonfly-0

# Verify
kubectl get pods -l app.kubernetes.io/name=dragonfly
kubectl get pvc
kubectl get svc dragonfly
```

**Test Connection:**

```bash
# If using password
DRAGONFLY_PASSWORD=$(kubectl get secret dragonfly -o jsonpath='{.data.password}' | base64 -d)

# Connect with redis-cli
kubectl run -it --rm redis-client --image=redis:alpine --restart=Never -- \
  redis-cli -h dragonfly -a "${DRAGONFLY_PASSWORD}" ping
```

### Step 3: Deploy Applications

#### 3.1 Update Configuration

Edit `environments/production/ontu-schedule-bot-admin.yaml`:

```yaml
# Update these values:
image:
  repository: ghcr.io/wandering-cursor/ontu-schedule-bot-admin
  tag: "v1.0.0"  # Your actual version

ingress:
  hosts:
    - host: admin-api.yourdomain.com  # Your domain
  tls:
    - secretName: ontu-schedule-admin-tls
      hosts:
        - admin-api.yourdomain.com
```

Edit `environments/production/ontu-schedule-bot.yaml`:

```yaml
image:
  repository: ghcr.io/wandering-cursor/ontu-schedule-bot
  tag: "v1.0.0"  # Your actual version
```

#### 3.2 Deploy Admin Backend

```bash
# Deploy
helm install ontu-schedule-bot-admin apps/ontu-schedule-bot-admin \
  -f environments/production/ontu-schedule-bot-admin.yaml

# Wait for deployment
kubectl wait --for=condition=available --timeout=120s \
  deployment/ontu-schedule-bot-admin

# Verify
kubectl get pods -l app.kubernetes.io/name=ontu-schedule-bot-admin
kubectl get svc ontu-schedule-bot-admin
kubectl get ingress ontu-schedule-bot-admin

# Check logs
kubectl logs -l app.kubernetes.io/name=ontu-schedule-bot-admin --tail=50
```

**Test Health Endpoint:**

```bash
# Port forward
kubectl port-forward svc/ontu-schedule-bot-admin 8080:8080

# In another terminal
curl http://localhost:8080/health/live
curl http://localhost:8080/health/ready
```

#### 3.3 Deploy Bot Client

```bash
# Deploy
helm install ontu-schedule-bot apps/ontu-schedule-bot \
  -f environments/production/ontu-schedule-bot.yaml

# Wait for deployment
kubectl wait --for=condition=available --timeout=120s \
  deployment/ontu-schedule-bot

# Verify
kubectl get pods -l app.kubernetes.io/name=ontu-schedule-bot
kubectl logs -l app.kubernetes.io/name=ontu-schedule-bot --tail=50
```

### Step 4: Deploy Example Application (Optional)

```bash
# Deploy example NGINX
helm install example-nginx apps/example-nginx \
  -f environments/production/example-nginx.yaml

# Verify
kubectl get pods -l app.kubernetes.io/name=example-nginx
kubectl get ingress example-nginx

# Test
kubectl port-forward svc/example-nginx 8080:80
# Visit http://localhost:8080
```

## 🔍 Verification

### Check All Resources

```bash
# All pods should be running
kubectl get pods

# Expected output:
# NAME                                      READY   STATUS    RESTARTS   AGE
# postgresql-0                              1/1     Running   0          5m
# dragonfly-0                               1/1     Running   0          4m
# ontu-schedule-bot-admin-xxx-xxx           1/1     Running   0          3m
# ontu-schedule-bot-admin-xxx-yyy           1/1     Running   0          3m
# ontu-schedule-bot-xxx-zzz                 1/1     Running   0          2m
# example-nginx-xxx-www                     1/1     Running   0          1m
```

### Check Services

```bash
kubectl get svc

# Verify ClusterIP services are accessible
```

### Check Ingress

```bash
kubectl get ingress

# Verify hosts and addresses are configured
```

### Check Persistent Volumes

```bash
kubectl get pvc

# PostgreSQL and Dragonfly should have bound PVCs
```

## 🔧 Configuration

### Scaling Applications

```bash
# Scale admin backend
kubectl scale deployment ontu-schedule-bot-admin --replicas=5

# Or use Helm upgrade
helm upgrade ontu-schedule-bot-admin apps/ontu-schedule-bot-admin \
  -f environments/production/ontu-schedule-bot-admin.yaml \
  --set replicaCount=5
```

### Updating Application

```bash
# Update image tag in values file
# environments/production/ontu-schedule-bot-admin.yaml
# image.tag: "v1.1.0"

# Upgrade with Helm
helm upgrade ontu-schedule-bot-admin apps/ontu-schedule-bot-admin \
  -f environments/production/ontu-schedule-bot-admin.yaml

# Monitor rollout
kubectl rollout status deployment/ontu-schedule-bot-admin
```

### Updating Secrets

```bash
# Create new sealed secret with updated values
kubectl create secret generic postgresql \
  --from-literal=password=new-password \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > postgresql-sealed-new.yaml

# Apply (will update existing)
kubectl apply -f postgresql-sealed-new.yaml

# Restart pods to use new secret
kubectl rollout restart statefulset/postgresql
```

## 🐛 Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods

# Describe pod for events
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name>

# Common issues:
# - Image pull errors: Check repository and credentials
# - CrashLoopBackOff: Check logs for application errors
# - Pending: Check resource availability and PVC binding
```

### Database Connection Issues

```bash
# Check PostgreSQL logs
kubectl logs postgresql-0

# Test connection from admin pod
kubectl exec -it <admin-pod-name> -- sh
# Inside pod:
nc -zv postgresql 5432
```

### Ingress Not Working

```bash
# Check ingress controller
kubectl get pods -n ingress-nginx  # or your ingress namespace

# Check ingress resource
kubectl describe ingress ontu-schedule-bot-admin

# Check service endpoints
kubectl get endpoints ontu-schedule-bot-admin

# Test service directly
kubectl port-forward svc/ontu-schedule-bot-admin 8080:8080
```

### Sealed Secrets Issues

```bash
# Check controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=sealed-secrets

# Check SealedSecret status
kubectl get sealedsecret <name> -o yaml

# Verify Secret was created
kubectl get secret <name>
```

## 📊 Monitoring

### View Logs

```bash
# All admin backend logs
kubectl logs -l app.kubernetes.io/name=ontu-schedule-bot-admin -f

# Specific pod
kubectl logs <pod-name> -f

# Previous logs (if crashed)
kubectl logs <pod-name> --previous
```

### Resource Usage

```bash
# Top pods
kubectl top pods

# Top nodes
kubectl top nodes

# Describe node
kubectl describe node <node-name>
```

### Events

```bash
# Recent events
kubectl get events --sort-by='.lastTimestamp'

# Events for specific pod
kubectl get events --field-selector involvedObject.name=<pod-name>
```

## 🔄 Updates and Maintenance

### Regular Updates

1. Update Helm charts with new versions
2. Test in development/staging first
3. Create sealed secrets for new secrets
4. Update production values files
5. Deploy using Helm upgrade
6. Monitor rollout

### Backup Strategy

```bash
# Backup PostgreSQL
kubectl exec postgresql-0 -- pg_dump -U postgres ontu_schedule > backup.sql

# Backup sealed secrets private key
kubectl get secret -n kube-system sealed-secrets-key -o yaml > sealed-secrets-key.yaml
# Store securely, NOT in Git!

# Backup Helm values
git commit -am "Backup current configuration"
```

## 🧹 Cleanup

### Remove Everything

```bash
# Uninstall applications
helm uninstall ontu-schedule-bot
helm uninstall ontu-schedule-bot-admin
helm uninstall example-nginx

# Uninstall infrastructure
helm uninstall dragonfly
helm uninstall postgresql

# Remove sealed secrets (optional)
helm uninstall sealed-secrets -n kube-system

# Remove namespace (if created)
kubectl delete namespace production

# Remove PVCs (warning: deletes data!)
kubectl delete pvc --all
```

## 📚 Next Steps

- Set up monitoring with Prometheus/Grafana
- Configure log aggregation (ELK, Loki)
- Set up CI/CD pipelines
- Implement backup automation
- Configure alerts
- Review and optimize resource limits
- Set up development/staging environments

## 🆘 Getting Help

- Review chart READMEs in respective directories
- Check [Sealed Secrets Guide](sealed-secrets-guide.md)
- Review [Architecture Documentation](architecture.md)
- Check application logs
- Review Kubernetes events
