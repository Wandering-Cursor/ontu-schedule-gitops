# Architecture Overview

## GitOps Repository Structure

This repository follows the **App-of-Apps pattern** with ArgoCD for GitOps-based deployment.

```
┌─────────────────────────────────────────────────────────────┐
│                    Git Repository                           │
│  github.com/Wandering-Cursor/ontu-schedule-gitops          │
└────────────────┬────────────────────────────────────────────┘
                 │
                 │ Watches
                 ▼
┌─────────────────────────────────────────────────────────────┐
│              ArgoCD (in cluster)                            │
│                                                             │
│  ┌──────────────────────────────────────────────────┐      │
│  │  Bootstrap App (root-app)                        │      │
│  │  Manages all child applications                  │      │
│  └───┬──────────────────────────────────────────────┘      │
│      │                                                      │
│      ├──► Sealed Secrets (infrastructure)                  │
│      ├──► OnTu Schedule Bot Admin - Dev                    │
│      ├──► OnTu Schedule Bot Admin - Staging                │
│      └──► OnTu Schedule Bot Admin - Prod                   │
└─────────────────────────────────────────────────────────────┘
                 │
                 │ Deploys to
                 ▼
┌─────────────────────────────────────────────────────────────┐
│              Kubernetes Cluster                             │
│                                                             │
│  ┌────────────────────────────────────────────┐            │
│  │ sealed-secrets namespace                   │            │
│  │  └─ sealed-secrets-controller              │            │
│  └────────────────────────────────────────────┘            │
│                                                             │
│  ┌────────────────────────────────────────────┐            │
│  │ ontu-schedule-dev namespace                │            │
│  │  ├─ ontu-schedule-bot-admin (deploy)       │            │
│  │  ├─ Service (ClusterIP)                    │            │
│  │  ├─ ConfigMap (app config)                 │            │
│  │  └─ SealedSecret → Secret                  │            │
│  └────────────────────────────────────────────┘            │
│                                                             │
│  ┌────────────────────────────────────────────┐            │
│  │ ontu-schedule-staging namespace            │            │
│  │  ├─ ontu-schedule-bot-admin (deploy)       │            │
│  │  ├─ HorizontalPodAutoscaler (2-5)          │            │
│  │  └─ ... (similar to dev)                   │            │
│  └────────────────────────────────────────────┘            │
│                                                             │
│  ┌────────────────────────────────────────────┐            │
│  │ ontu-schedule-prod namespace               │            │
│  │  ├─ ontu-schedule-bot-admin (deploy)       │            │
│  │  ├─ HorizontalPodAutoscaler (3-10)         │            │
│  │  ├─ Pod Anti-Affinity rules                │            │
│  │  └─ ... (similar to staging)               │            │
│  └────────────────────────────────────────────┘            │
└─────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

### ArgoCD Bootstrap (App-of-Apps)

**Location:** `argocd/bootstrap/root-app.yaml`

**Purpose:** Single entry point that manages all child applications

**Features:**
- Watches `argocd/applications/` directory
- Automatically deploys all Application manifests found
- Enables self-healing and auto-sync
- Provides centralized management

### ArgoCD Projects

**Location:** `argocd/projects/`

**Projects:**
1. **default** - For general applications
2. **ontu-schedule** - For ontu-schedule applications with specific RBAC

**Purpose:**
- Logical grouping of applications
- RBAC and access control
- Source repository whitelisting
- Destination namespace restrictions

### Infrastructure Components

#### Sealed Secrets Controller

**Location:** `infrastructure/sealed-secrets/`

**Responsibilities:**
- Decrypt SealedSecret resources into Secret resources
- Secure key management (private key stored in cluster)
- Enable secrets in Git workflow

**Deployment:**
- Namespace: `sealed-secrets`
- Deployed via Helm chart (Bitnami upstream)
- Auto-sync enabled

### Application Components

#### OnTu Schedule Bot Admin

**Location:** `apps/ontu-schedule-bot-admin/`

**Architecture:**

```
┌─────────────────────────────────────────────┐
│           Helm Chart Structure              │
├─────────────────────────────────────────────┤
│ Chart.yaml           - Chart metadata       │
│ values.yaml          - Default values       │
│                                             │
│ templates/                                  │
│  ├─ deployment.yaml  - App deployment       │
│  ├─ service.yaml     - ClusterIP service    │
│  ├─ serviceaccount.yaml - RBAC              │
│  ├─ configmap.yaml   - Non-sensitive config │
│  ├─ sealedsecret.yaml - Encrypted secrets   │
│  ├─ ingress.yaml     - HTTP ingress         │
│  └─ hpa.yaml         - Autoscaling          │
└─────────────────────────────────────────────┘
```

## Deployment Flow

### Initial Setup

```
1. Admin applies bootstrap app
   └─► kubectl apply -f argocd/bootstrap/root-app.yaml

2. ArgoCD detects root-app
   └─► Reads argocd/applications/ directory

3. ArgoCD creates child Applications
   ├─► Sealed Secrets (infrastructure)
   ├─► Bot Admin - Dev
   ├─► Bot Admin - Staging
   └─► Bot Admin - Prod

4. Each Application syncs from Git
   └─► Helm charts deployed to respective namespaces

5. Sealed Secrets controller decrypts SealedSecrets
   └─► Regular Secrets available to pods
```

### Update Flow

```
1. Developer makes changes
   ├─► Update Helm chart
   ├─► Update environment values
   └─► Commit and push to Git

2. ArgoCD detects changes (auto-sync)
   └─► Compares Git state vs Cluster state

3. ArgoCD syncs changes
   ├─► Dev/Staging: Automatic
   └─► Prod: Manual approval required

4. Kubernetes rolls out changes
   └─► RollingUpdate strategy (zero downtime)
```

## Environment Differences

| Aspect | Dev | Staging | Production |
|--------|-----|---------|------------|
| **Namespace** | `ontu-schedule-dev` | `ontu-schedule-staging` | `ontu-schedule-prod` |
| **Image Tag** | `develop` | `staging` | `v1.0.0` |
| **Replicas** | 1 | 2 | 3 |
| **Auto-Sync** | ✅ Yes | ✅ Yes | ❌ Manual |
| **Auto-Prune** | ✅ Yes | ✅ Yes | ❌ No |
| **Self-Heal** | ✅ Yes | ✅ Yes | ❌ No |
| **HPA** | ❌ Disabled | ✅ 2-5 pods | ✅ 3-10 pods |
| **Resources (CPU)** | 50m-200m | 100m-400m | 200m-1000m |
| **Resources (Mem)** | 64Mi-256Mi | 128Mi-512Mi | 256Mi-1Gi |
| **Log Level** | debug | info | warn |
| **Pod Anti-Affinity** | ❌ No | ❌ No | ✅ Yes |

## Secrets Management Flow

```
┌──────────────────────────────────────────────────────────┐
│  Developer Workstation                                   │
│                                                          │
│  1. Create plain secret value                           │
│     echo -n "password" | \                               │
│                                                          │
│  2. Encrypt with kubeseal (using public cert)           │
│     kubeseal --raw --cert=pub-cert.pem                   │
│                                                          │
│  3. Encrypted value: AgB8j3k2...                        │
└────────────┬─────────────────────────────────────────────┘
             │
             │ Commit encrypted value
             ▼
┌──────────────────────────────────────────────────────────┐
│  Git Repository (values file)                           │
│                                                          │
│  secrets:                                                │
│    enabled: true                                         │
│    data:                                                 │
│      PASSWORD: AgB8j3k2...  # Safe in Git!              │
└────────────┬─────────────────────────────────────────────┘
             │
             │ ArgoCD syncs
             ▼
┌──────────────────────────────────────────────────────────┐
│  Kubernetes Cluster                                      │
│                                                          │
│  ┌────────────────────────────────────────────┐         │
│  │ SealedSecret created with encrypted data   │         │
│  └───────────┬────────────────────────────────┘         │
│              │                                           │
│              │ Sealed Secrets Controller                 │
│              │ (has private key)                         │
│              ▼                                           │
│  ┌────────────────────────────────────────────┐         │
│  │ Regular Secret with decrypted data         │         │
│  │   PASSWORD: "password"                     │         │
│  └───────────┬────────────────────────────────┘         │
│              │                                           │
│              │ Mounted as env var or volume              │
│              ▼                                           │
│  ┌────────────────────────────────────────────┐         │
│  │ Application Pod                            │         │
│  │   - Can read PASSWORD as plaintext         │         │
│  │   - No knowledge of encryption             │         │
│  └────────────────────────────────────────────┘         │
└──────────────────────────────────────────────────────────┘
```

## Key Security Features

1. **Secrets Never in Plaintext in Git**
   - All secrets encrypted with Sealed Secrets
   - Only encrypted values committed

2. **Immutable Infrastructure**
   - All changes go through Git
   - No manual kubectl edits in production

3. **RBAC via ArgoCD Projects**
   - AppProjects control who can deploy what where
   - Namespace and resource restrictions

4. **Production Safeguards**
   - Manual sync required for production
   - No auto-prune to prevent accidental deletions
   - Pod disruption budgets (recommended for future)

5. **Security Contexts**
   - Run as non-root user (UID 1000)
   - Read-only root filesystem
   - Drop all capabilities
   - No privilege escalation

## Scalability Considerations

### Horizontal Pod Autoscaling

- **Staging:** 2-5 replicas based on CPU (70%) and Memory (80%)
- **Production:** 3-10 replicas based on CPU (70%) and Memory (80%)

### Resource Management

- All environments have resource requests and limits
- Prevents resource starvation
- Enables proper scheduling

### Future Enhancements

1. **Vertical Pod Autoscaling** - Right-size resources automatically
2. **Cluster Autoscaling** - Add nodes when needed
3. **Pod Disruption Budgets** - Ensure availability during updates
4. **Network Policies** - Restrict pod-to-pod communication
5. **Service Mesh** - Advanced traffic management (Istio/Linkerd)

## Disaster Recovery

### Backup Strategy

**Git as Source of Truth:**
- All configuration in Git
- Easy to recreate entire cluster
- Version history for rollback

**Sealed Secrets:**
- Backup the controller's private key
- Store securely (encrypted, off-cluster)
- Required to decrypt existing SealedSecrets

### Recovery Process

```bash
# 1. Setup new cluster
kubectl create namespace argocd
kubectl apply -n argocd -f <argocd-install-yaml>

# 2. Restore Sealed Secrets private key (if needed)
kubectl apply -f sealed-secrets-key-backup.yaml

# 3. Deploy bootstrap app
kubectl apply -f argocd/bootstrap/root-app.yaml

# 4. Everything else auto-deploys from Git
```

## Monitoring & Observability

### Recommended Additions

1. **Prometheus + Grafana**
   - Metrics collection and visualization
   - Alerts on pod failures, high resource usage

2. **Loki or ELK**
   - Centralized logging
   - Log aggregation across environments

3. **Jaeger or Tempo**
   - Distributed tracing
   - Request flow visualization

4. **ArgoCD Notifications**
   - Slack/email alerts on sync failures
   - Deployment notifications

### Health Checks

Each application has:
- **Liveness Probe:** Restart pod if unhealthy
- **Readiness Probe:** Remove from service if not ready
- Configurable delays and intervals

## References

- [App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Kubernetes Production Checklist](https://learnk8s.io/production-best-practices)
