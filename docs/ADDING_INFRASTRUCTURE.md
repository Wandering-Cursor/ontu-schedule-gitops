# Adding Infrastructure Components

This guide explains how to add new infrastructure components (databases, message queues, caches, etc.) to your GitOps repository.

## Overview

Infrastructure components are shared resources used by multiple applications. Examples include:
- Databases (PostgreSQL, MySQL, MongoDB)
- Caching (Redis, Memcached)
- Message queues (RabbitMQ, Kafka)
- Monitoring (Prometheus, Grafana)
- Service meshes (Istio, Linkerd)

## Step-by-Step Guide: Adding PostgreSQL

Let's walk through adding PostgreSQL as an example. The same pattern applies to other infrastructure.

### Step 1: Create Infrastructure Helm Chart

Create a wrapper chart that uses an upstream Helm chart as a dependency.

```bash
mkdir -p infrastructure/postgresql
cd infrastructure/postgresql
```

**Create `Chart.yaml`:**

```yaml
apiVersion: v2
name: postgresql
description: A Helm chart for deploying PostgreSQL database
type: application
version: 0.1.0
appVersion: "16.1.0"

dependencies:
  - name: postgresql
    version: "13.2.24"  # Check https://artifacthub.io for latest
    repository: https://charts.bitnami.com/bitnami
```

**Create `values.yaml` (default/base values):**

```yaml
postgresql:
  global:
    postgresql:
      auth:
        username: myapp_user
        database: myapp_db
        existingSecret: ""  # Use Sealed Secrets
  
  primary:
    persistence:
      enabled: true
      size: 10Gi
    
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
      requests:
        cpu: 250m
        memory: 256Mi
  
  metrics:
    enabled: true
```

**Create `.helmignore`:**

```
.DS_Store
.git/
*.swp
```

### Step 2: Download Dependencies

```bash
helm dependency update
```

This downloads the PostgreSQL chart to `charts/` directory (which is gitignored).

### Step 3: Create Environment-Specific Values

Create value overrides for each environment:

**`environments/dev/postgresql-values.yaml`:**

```yaml
postgresql:
  global:
    postgresql:
      auth:
        username: myapp_dev_user
        database: myapp_dev
        existingSecret: "postgresql-secrets"
  
  primary:
    persistence:
      size: 5Gi
    resources:
      limits:
        cpu: 300m
        memory: 256Mi
```

**`environments/staging/postgresql-values.yaml`:**

```yaml
postgresql:
  global:
    postgresql:
      auth:
        username: myapp_staging_user
        database: myapp_staging
        existingSecret: "postgresql-secrets"
  
  primary:
    persistence:
      size: 10Gi
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
```

**`environments/prod/postgresql-values.yaml`:**

```yaml
postgresql:
  global:
    postgresql:
      auth:
        username: myapp_prod_user
        database: myapp_prod
        existingSecret: "postgresql-secrets"
  
  primary:
    persistence:
      size: 20Gi
    resources:
      limits:
        cpu: 1000m
        memory: 1Gi
  
  backup:
    enabled: true
```

### Step 4: Create Database Credentials with Sealed Secrets

**Generate passwords:**

```bash
# Generate strong passwords
POSTGRES_PASSWORD=$(openssl rand -base64 32)
USER_PASSWORD=$(openssl rand -base64 32)
```

**Create a temporary secret file:**

```bash
cat > postgres-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: postgresql-secrets
  namespace: ontu-schedule-dev
type: Opaque
stringData:
  postgres-password: "$POSTGRES_PASSWORD"
  password: "$USER_PASSWORD"
EOF
```

**Encrypt with Sealed Secrets:**

```bash
# Make sure you have the public certificate
./scripts/seal-secret.sh fetch-cert

# Encrypt the secret
kubeseal --cert=pub-cert.pem < postgres-secret.yaml > postgres-sealed-secret.yaml

# Clean up
rm postgres-secret.yaml
```

**Or use the helper script:**

```bash
# Encrypt postgres admin password
./scripts/seal-secret.sh encrypt-value \
  postgresql-secrets \
  ontu-schedule-dev \
  "$POSTGRES_PASSWORD"

# Encrypt user password
./scripts/seal-secret.sh encrypt-value \
  postgresql-secrets \
  ontu-schedule-dev \
  "$USER_PASSWORD"
```

**Create SealedSecret manifest:**

```yaml
# infrastructure/postgresql/templates/sealedsecret-dev.yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: postgresql-secrets
  namespace: ontu-schedule-dev
spec:
  encryptedData:
    postgres-password: AgA...  # Encrypted value
    password: AgB...           # Encrypted value
  template:
    metadata:
      name: postgresql-secrets
```

Repeat for staging and prod namespaces.

### Step 5: Create ArgoCD Application Manifests

**`argocd/applications/postgresql-dev.yaml`:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: postgresql-dev
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: ontu-schedule
  
  source:
    repoURL: https://github.com/YOUR-ORG/YOUR-REPO.git
    targetRevision: HEAD
    path: infrastructure/postgresql
    helm:
      releaseName: postgresql
      valueFiles:
        - ../../environments/dev/postgresql-values.yaml
  
  destination:
    server: https://kubernetes.default.svc
    namespace: ontu-schedule-dev
  
  syncPolicy:
    automated:
      prune: false  # IMPORTANT: Don't auto-delete database!
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
  
  # Ignore differences in StatefulSet and PVC
  ignoreDifferences:
    - group: apps
      kind: StatefulSet
      jsonPointers:
        - /spec/replicas
    - group: ""
      kind: PersistentVolumeClaim
      jsonPointers:
        - /spec/resources/requests/storage
```

Create similar files for staging and prod (with manual sync for prod).

### Step 6: Commit and Deploy

```bash
# Add files
git add infrastructure/postgresql/
git add environments/*/postgresql-values.yaml
git add argocd/applications/postgresql-*.yaml

# Commit
git commit -m "Add PostgreSQL infrastructure"

# Push
git push
```

ArgoCD will automatically detect and deploy (via App-of-Apps pattern).

### Step 7: Verify Deployment

```bash
# Check applications
argocd app list | grep postgresql

# Check pods
kubectl get pods -n ontu-schedule-dev | grep postgresql

# Check PVC
kubectl get pvc -n ontu-schedule-dev

# Test database connection
kubectl exec -it -n ontu-schedule-dev postgresql-0 -- psql -U myapp_dev_user -d myapp_dev
```

## General Pattern for Any Infrastructure

### 1. Find the Upstream Helm Chart

Search on [Artifact Hub](https://artifacthub.io/):
- Bitnami charts (recommended): `https://charts.bitnami.com/bitnami`
- Official charts: Chart-specific repositories
- Community charts: Various

### 2. Create Wrapper Chart Structure

```
infrastructure/<component>/
├── Chart.yaml          # Dependencies
├── values.yaml         # Base values
├── .helmignore
└── templates/          # Optional: additional resources
    └── sealedsecrets.yaml
```

### 3. Key Considerations

#### For Databases (PostgreSQL, MySQL, MongoDB)

**Important:**
- ✅ Set `syncPolicy.automated.prune: false` (never auto-delete data!)
- ✅ Use PersistentVolumes
- ✅ Configure backups for production
- ✅ Use Sealed Secrets for credentials
- ✅ Ignore PVC storage differences
- ✅ Manual sync for production

#### For Caches (Redis, Memcached)

- Can use `prune: true` (data is cache, not persistent)
- May not need persistence
- Smaller resource allocations
- Consider cluster mode for production

#### For Message Queues (RabbitMQ, Kafka)

- Similar to databases (persistent data)
- `prune: false` recommended
- Consider replication for production
- Monitor disk usage

#### For Monitoring (Prometheus, Grafana)

- May need cluster-scoped resources
- Update AppProject to allow these
- Consider retention policies
- Integrate with applications

## Example: Adding Redis

### Chart.yaml
```yaml
apiVersion: v2
name: redis
version: 0.1.0
dependencies:
  - name: redis
    version: "18.4.0"
    repository: https://charts.bitnami.com/bitnami
```

### values.yaml
```yaml
redis:
  architecture: standalone  # or 'replication'
  auth:
    enabled: true
    existingSecret: "redis-secrets"
  
  master:
    persistence:
      enabled: false  # Cache data
    resources:
      limits:
        cpu: 200m
        memory: 256Mi
```

### ArgoCD Application
```yaml
syncPolicy:
  automated:
    prune: true  # OK for cache
    selfHeal: true
```

## Example: Adding RabbitMQ

### Chart.yaml
```yaml
apiVersion: v2
name: rabbitmq
version: 0.1.0
dependencies:
  - name: rabbitmq
    version: "12.9.0"
    repository: https://charts.bitnami.com/bitnami
```

### values.yaml
```yaml
rabbitmq:
  auth:
    username: admin
    existingPasswordSecret: "rabbitmq-secrets"
  
  persistence:
    enabled: true
    size: 8Gi
  
  replicaCount: 3  # For HA in production
```

### ArgoCD Application
```yaml
syncPolicy:
  automated:
    prune: false  # Persistent data!
```

## Connecting Applications to Infrastructure

### Update Application Values

**`apps/my-app/values.yaml`:**

```yaml
env:
  - name: DATABASE_HOST
    value: "postgresql.ontu-schedule-dev.svc.cluster.local"
  - name: DATABASE_PORT
    value: "5432"
  - name: DATABASE_NAME
    value: "myapp_dev"
  - name: DATABASE_USER
    valueFrom:
      secretKeyRef:
        name: postgresql-secrets
        key: username
  - name: DATABASE_PASSWORD
    valueFrom:
      secretKeyRef:
        name: postgresql-secrets
        key: password
```

### Or Use ConfigMap

```yaml
configMap:
  enabled: true
  data:
    DATABASE_HOST: "postgresql.ontu-schedule-dev.svc.cluster.local"
    DATABASE_PORT: "5432"
    DATABASE_NAME: "myapp_dev"
```

### DNS Names in Kubernetes

Service DNS format: `<service>.<namespace>.svc.cluster.local`

Examples:
- PostgreSQL: `postgresql.ontu-schedule-dev.svc.cluster.local:5432`
- Redis: `redis-master.ontu-schedule-dev.svc.cluster.local:6379`
- RabbitMQ: `rabbitmq.ontu-schedule-dev.svc.cluster.local:5672`

## Best Practices

### Security
1. ✅ Always use Sealed Secrets for credentials
2. ✅ Never commit plain passwords
3. ✅ Use strong generated passwords
4. ✅ Rotate credentials regularly
5. ✅ Use separate credentials per environment

### Data Safety
1. ✅ Set `prune: false` for stateful services
2. ✅ Test backups and restores
3. ✅ Use PersistentVolumes
4. ✅ Configure storage classes appropriately
5. ✅ Manual sync for production databases

### Resource Management
1. ✅ Set appropriate resource limits
2. ✅ Monitor resource usage
3. ✅ Use separate namespaces per environment
4. ✅ Consider node affinity/anti-affinity

### Monitoring
1. ✅ Enable metrics exporters
2. ✅ Set up alerts for disk usage
3. ✅ Monitor connection pools
4. ✅ Track query performance

## Troubleshooting

### Chart Dependency Issues

```bash
# Update dependencies
cd infrastructure/<component>
helm dependency update

# Check downloaded charts
ls charts/
```

### PVC Not Binding

```bash
# Check PVC status
kubectl get pvc -n <namespace>

# Describe PVC for events
kubectl describe pvc <pvc-name> -n <namespace>

# Check storage classes
kubectl get storageclass
```

### Secret Not Found

```bash
# Check if SealedSecret exists
kubectl get sealedsecret -n <namespace>

# Check if Secret was created
kubectl get secret -n <namespace>

# Check Sealed Secrets controller logs
kubectl logs -n sealed-secrets deployment/sealed-secrets-controller
```

### Application Can't Connect

```bash
# Test DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup postgresql.ontu-schedule-dev.svc.cluster.local

# Check service
kubectl get svc -n ontu-schedule-dev

# Test connection from app pod
kubectl exec -it -n ontu-schedule-dev <app-pod> -- nc -zv postgresql 5432
```

## Quick Reference: Common Infrastructure

| Component | Chart Repo | Typical Use | Prune? |
|-----------|-----------|-------------|--------|
| PostgreSQL | Bitnami | Primary database | ❌ No |
| MySQL | Bitnami | Primary database | ❌ No |
| MongoDB | Bitnami | Document database | ❌ No |
| Redis | Bitnami | Cache, sessions | ✅ Yes* |
| RabbitMQ | Bitnami | Message queue | ❌ No |
| Kafka | Bitnami | Event streaming | ❌ No |
| Elasticsearch | Elastic | Search, logs | ❌ No |
| Prometheus | Prometheus | Metrics | ⚠️ Maybe |
| Grafana | Grafana | Dashboards | ✅ Yes |

*Redis with persistence should use `prune: false`

## Summary

Adding infrastructure follows this pattern:

1. **Create wrapper chart** in `infrastructure/<name>/`
2. **Define base values** in `values.yaml`
3. **Create environment overrides** in `environments/{dev,staging,prod}/`
4. **Generate and encrypt secrets** with Sealed Secrets
5. **Create ArgoCD Applications** in `argocd/applications/`
6. **Update dependencies** with `helm dependency update`
7. **Commit and push** - ArgoCD handles the rest!

Remember:
- 🔐 Always encrypt secrets
- 💾 Never auto-prune databases
- 🎯 Manual sync for production
- 📊 Monitor everything
- 🧪 Test in dev first

Happy deploying! 🚀
