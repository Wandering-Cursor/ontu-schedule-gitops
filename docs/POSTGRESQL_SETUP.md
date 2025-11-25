# PostgreSQL Infrastructure Setup - Summary

## ✅ What Was Created

### Infrastructure Chart
```
infrastructure/postgresql/
├── Chart.yaml              # Wrapper chart with Bitnami PostgreSQL dependency
├── values.yaml             # Base configuration
├── .helmignore            
└── charts/                 # Downloaded dependency (gitignored)
    └── postgresql-13.2.24.tgz
```

### Environment-Specific Configurations
```
environments/
├── dev/postgresql-values.yaml      # Dev: 5Gi storage, 300m CPU
├── staging/postgresql-values.yaml  # Staging: 10Gi storage, 500m CPU
└── prod/postgresql-values.yaml     # Prod: 20Gi storage, 1000m CPU
```

### ArgoCD Applications
```
argocd/applications/
├── postgresql-dev.yaml      # Auto-sync, prune: false
├── postgresql-staging.yaml  # Auto-sync, prune: false
└── postgresql-prod.yaml     # Manual sync, prune: false
```

### Helper Script
```
scripts/setup-postgresql-secrets.sh  # Automated secret generation & encryption
```

## 🎯 Key Features

### Configuration Highlights

**Development:**
- Database: `ontu_schedule_dev`
- User: `ontu_dev_user`
- Storage: 5Gi
- Resources: 100m-300m CPU, 128Mi-256Mi RAM
- Metrics enabled

**Staging:**
- Database: `ontu_schedule_staging`
- User: `ontu_staging_user`
- Storage: 10Gi
- Resources: 250m-500m CPU, 256Mi-512Mi RAM
- Metrics enabled

**Production:**
- Database: `ontu_schedule_prod`
- User: `ontu_prod_user`
- Storage: 20Gi
- Resources: 500m-1000m CPU, 512Mi-1Gi RAM
- Metrics with ServiceMonitor
- Backup support (ready to enable)
- HA ready (can enable replication)

### Security Features

✅ **Sealed Secrets integration** - Credentials encrypted in Git
✅ **Separate credentials per environment**
✅ **No plaintext passwords**
✅ **Pod security contexts** - Non-root, dropped capabilities
✅ **Resource limits** - Prevent resource exhaustion

### Data Safety

✅ **`prune: false`** - ArgoCD won't auto-delete database
✅ **PersistentVolumes** - Data survives pod restarts
✅ **Ignore PVC differences** - Storage size changes don't trigger sync
✅ **Manual sync for production** - Requires explicit approval

## 🚀 How to Deploy

### Step 1: Generate and Encrypt Secrets

```bash
# Use the automated script
./scripts/setup-postgresql-secrets.sh
```

This will:
1. Generate strong passwords for all environments
2. Encrypt them with Sealed Secrets
3. Create `infrastructure/postgresql/sealedsecret-{dev,staging,prod}.yaml`
4. Display passwords (save them to password manager!)

### Step 2: Commit and Push

```bash
git add infrastructure/postgresql/
git add environments/*/postgresql-values.yaml
git add argocd/applications/postgresql-*.yaml
git commit -m "Add PostgreSQL infrastructure with Sealed Secrets"
git push
```

### Step 3: ArgoCD Auto-Deploys

The bootstrap app (App-of-Apps) automatically detects new applications in `argocd/applications/` and deploys them!

**Auto-deployed:**
- ✅ PostgreSQL Dev
- ✅ PostgreSQL Staging

**Requires manual sync:**
- ⏸️ PostgreSQL Prod (safety measure)

### Step 4: Verify Deployment

```bash
# Check ArgoCD applications
argocd app list | grep postgresql

# Check pods
kubectl get pods -n ontu-schedule-dev | grep postgresql
kubectl get pods -n ontu-schedule-staging | grep postgresql

# Check PVCs
kubectl get pvc -n ontu-schedule-dev
kubectl get pvc -n ontu-schedule-staging

# Check secrets (should exist after deployment)
kubectl get secret postgresql-secrets -n ontu-schedule-dev
kubectl get secret postgresql-secrets -n ontu-schedule-staging
```

### Step 5: Sync Production (Manual)

```bash
# Via CLI
argocd app sync postgresql-prod

# Or via UI
# 1. Navigate to postgresql-prod app
# 2. Click "SYNC"
# 3. Review changes
# 4. Click "SYNCHRONIZE"
```

## 🔌 Connecting Applications to PostgreSQL

### Method 1: Environment Variables from Secret

Update your application's `values.yaml`:

```yaml
env:
  - name: DATABASE_HOST
    value: "postgresql.ontu-schedule-dev.svc.cluster.local"
  - name: DATABASE_PORT
    value: "5432"
  - name: DATABASE_NAME
    value: "ontu_schedule_dev"
  - name: DATABASE_USER
    value: "ontu_dev_user"
  - name: DATABASE_PASSWORD
    valueFrom:
      secretKeyRef:
        name: postgresql-secrets
        key: password
```

### Method 2: PostgreSQL Connection String

```yaml
env:
  - name: DATABASE_URL
    value: "postgresql://ontu_dev_user:$(DATABASE_PASSWORD)@postgresql:5432/ontu_schedule_dev"
  - name: DATABASE_PASSWORD
    valueFrom:
      secretKeyRef:
        name: postgresql-secrets
        key: password
```

### Method 3: Using ConfigMap + Secret

**ConfigMap for non-sensitive data:**

```yaml
configMap:
  enabled: true
  data:
    DATABASE_HOST: "postgresql.ontu-schedule-dev.svc.cluster.local"
    DATABASE_PORT: "5432"
    DATABASE_NAME: "ontu_schedule_dev"
    DATABASE_USER: "ontu_dev_user"
```

**Reference secret for password:**

```yaml
envFrom:
  - configMapRef:
      name: my-app-config
  - secretRef:
      name: postgresql-secrets
```

### DNS Names

PostgreSQL services are accessible via:

- **Dev:** `postgresql.ontu-schedule-dev.svc.cluster.local:5432`
- **Staging:** `postgresql.ontu-schedule-staging.svc.cluster.local:5432`
- **Prod:** `postgresql.ontu-schedule-prod.svc.cluster.local:5432`

Within the same namespace, you can use just `postgresql:5432`.

## 🧪 Testing Connection

### From Another Pod in Same Namespace

```bash
# Deploy a test pod
kubectl run -it --rm psql-client \
  --image=postgres:16 \
  --namespace=ontu-schedule-dev \
  --env="PGPASSWORD=<password-from-secret>" \
  -- psql -h postgresql -U ontu_dev_user -d ontu_schedule_dev
```

### Get Password from Secret

```bash
# Dev environment
kubectl get secret postgresql-secrets -n ontu-schedule-dev \
  -o jsonpath='{.data.password}' | base64 -d

# Staging environment
kubectl get secret postgresql-secrets -n ontu-schedule-staging \
  -o jsonpath='{.data.password}' | base64 -d
```

### Port Forward for Local Access

```bash
# Forward PostgreSQL port to localhost
kubectl port-forward -n ontu-schedule-dev svc/postgresql 5432:5432

# Connect with local psql client
psql -h localhost -U ontu_dev_user -d ontu_schedule_dev
```

## 📊 Monitoring

### Check PostgreSQL Metrics

Metrics exporter is enabled by default and runs on port 9187.

```bash
# Check metrics pod
kubectl get pods -n ontu-schedule-dev | grep metrics

# View metrics
kubectl port-forward -n ontu-schedule-dev svc/postgresql-metrics 9187:9187
curl http://localhost:9187/metrics
```

### Common Metrics

- `pg_up` - Database is up
- `pg_database_size_bytes` - Database size
- `pg_stat_activity_count` - Active connections
- `pg_stat_database_*` - Query statistics

## 🔧 Common Operations

### Backup Database

```bash
# Manual backup
kubectl exec -n ontu-schedule-dev postgresql-0 -- \
  pg_dump -U ontu_dev_user ontu_schedule_dev > backup.sql
```

### Restore Database

```bash
# Restore from backup
kubectl exec -i -n ontu-schedule-dev postgresql-0 -- \
  psql -U ontu_dev_user -d ontu_schedule_dev < backup.sql
```

### View Logs

```bash
# PostgreSQL logs
kubectl logs -n ontu-schedule-dev postgresql-0

# Follow logs
kubectl logs -n ontu-schedule-dev postgresql-0 -f
```

### Scale Storage (if needed)

```bash
# Edit PVC (if storage class supports expansion)
kubectl edit pvc data-postgresql-0 -n ontu-schedule-dev

# Update the storage size in values file and commit
```

## 🚨 Troubleshooting

### Pod Not Starting

```bash
# Check pod status
kubectl get pods -n ontu-schedule-dev

# Describe pod for events
kubectl describe pod postgresql-0 -n ontu-schedule-dev

# Check logs
kubectl logs postgresql-0 -n ontu-schedule-dev
```

### PVC Not Binding

```bash
# Check PVC status
kubectl get pvc -n ontu-schedule-dev

# Describe PVC
kubectl describe pvc data-postgresql-0 -n ontu-schedule-dev

# Check available storage classes
kubectl get storageclass
```

### Secret Not Found

```bash
# Check if SealedSecret exists
kubectl get sealedsecret -n ontu-schedule-dev

# Check if Secret was created
kubectl get secret postgresql-secrets -n ontu-schedule-dev

# Check Sealed Secrets controller logs
kubectl logs -n sealed-secrets deployment/sealed-secrets-controller
```

### Connection Refused

```bash
# Check if service exists
kubectl get svc postgresql -n ontu-schedule-dev

# Test DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never \
  -- nslookup postgresql.ontu-schedule-dev.svc.cluster.local

# Test port connectivity
kubectl run -it --rm debug --image=busybox --restart=Never \
  -- nc -zv postgresql.ontu-schedule-dev.svc.cluster.local 5432
```

## 📚 Additional Resources

- **Full Guide:** See [docs/ADDING_INFRASTRUCTURE.md](ADDING_INFRASTRUCTURE.md)
- **Bitnami PostgreSQL Chart:** https://github.com/bitnami/charts/tree/main/bitnami/postgresql
- **PostgreSQL Docs:** https://www.postgresql.org/docs/
- **Sealed Secrets:** See [README.md](../README.md#working-with-secrets)

## ⚡ Quick Reference

| Environment | Namespace | Database | User | Storage | Sync |
|-------------|-----------|----------|------|---------|------|
| Dev | `ontu-schedule-dev` | `ontu_schedule_dev` | `ontu_dev_user` | 5Gi | Auto |
| Staging | `ontu-schedule-staging` | `ontu_schedule_staging` | `ontu_staging_user` | 10Gi | Auto |
| Prod | `ontu-schedule-prod` | `ontu_schedule_prod` | `ontu_prod_user` | 20Gi | Manual |

**Connection URLs:**
```
Dev:     postgresql://ontu_dev_user:<password>@postgresql.ontu-schedule-dev:5432/ontu_schedule_dev
Staging: postgresql://ontu_staging_user:<password>@postgresql.ontu-schedule-staging:5432/ontu_schedule_staging
Prod:    postgresql://ontu_prod_user:<password>@postgresql.ontu-schedule-prod:5432/ontu_schedule_prod
```

---

**PostgreSQL is ready to use!** 🎉
