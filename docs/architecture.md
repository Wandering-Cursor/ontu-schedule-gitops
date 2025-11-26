# Architecture Overview

This document describes the architecture of the ONTU Schedule application stack.

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Internet                              │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      │ HTTPS
                      │
┌─────────────────────┴───────────────────────────────────────┐
│                   Ingress Controller                         │
│                  (nginx-ingress)                             │
└─────────────────────┬───────────────────────────────────────┘
                      │
         ┌────────────┴────────────┐
         │                         │
         │                         │
    ┌────▼─────┐            ┌─────▼──────┐
    │ Admin    │            │ Example    │
    │ Backend  │            │ NGINX      │
    │ Ingress  │            │ Ingress    │
    └────┬─────┘            └────────────┘
         │
         │
┌────────┴────────────────────────────────────────────────────┐
│               Kubernetes Cluster                             │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │            Application Layer                          │  │
│  │                                                       │  │
│  │  ┌────────────────────┐    ┌────────────────────┐   │  │
│  │  │ ONTU Schedule      │    │ ONTU Schedule      │   │  │
│  │  │ Bot Client         │───▶│ Bot Admin          │   │  │
│  │  │                    │HTTP│                    │   │  │
│  │  │ - Receives user    │    │ - API endpoints    │   │  │
│  │  │   requests         │    │ - Business logic   │   │  │
│  │  │ - Sends HTTP       │    │ - Schedule mgmt    │   │  │
│  │  │   to admin         │    │                    │   │  │
│  │  │ - 1 replica        │    │ - 2-10 replicas    │   │  │
│  │  └────────────────────┘    └──────┬─────┬───────┘   │  │
│  │                                    │     │           │  │
│  └────────────────────────────────────┼─────┼───────────┘  │
│                                       │     │              │
│  ┌────────────────────────────────────┼─────┼───────────┐  │
│  │            Data Layer              │     │           │  │
│  │                                    │     │           │  │
│  │  ┌─────────────────────┐  ┌────────▼─────▼────────┐ │  │
│  │  │ Dragonfly           │  │ PostgreSQL            │ │  │
│  │  │ (Redis-compatible)  │  │                       │ │  │
│  │  │                     │  │ - User data           │ │  │
│  │  │ - Caching           │  │ - Schedules           │ │  │
│  │  │ - Session storage   │  │ - Persistent storage  │ │  │
│  │  │ - Fast access       │  │ - ACID transactions   │ │  │
│  │  │ - 1 instance        │  │ - 1 instance          │ │  │
│  │  └─────────────────────┘  └───────────────────────┘ │  │
│  │          │  PVC                      │  PVC          │  │
│  │          ▼                           ▼               │  │
│  │  ┌──────────────┐          ┌──────────────┐         │  │
│  │  │ Persistent   │          │ Persistent   │         │  │
│  │  │ Volume       │          │ Volume       │         │  │
│  │  │ (5Gi)        │          │ (10Gi)       │         │  │
│  │  └──────────────┘          └──────────────┘         │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         Security & Infrastructure Layer              │  │
│  │                                                       │  │
│  │  ┌────────────────────┐    ┌────────────────────┐   │  │
│  │  │ Sealed Secrets     │    │ ConfigMaps &       │   │  │
│  │  │ Controller         │    │ Secrets            │   │  │
│  │  │                    │    │                    │   │  │
│  │  │ - Decrypts secrets │    │ - Configuration    │   │  │
│  │  │ - Manages keys     │    │ - Environment vars │   │  │
│  │  │ - kube-system ns   │    │ - Credentials      │   │  │
│  │  └────────────────────┘    └────────────────────┘   │  │
│  └──────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

## 📦 Components

### Applications

#### 1. ONTU Schedule Bot Client

**Purpose**: User-facing bot that handles user interactions.

**Technology Stack**:
- Language: Python/Node.js/Go (depending on implementation)
- Framework: Bot framework (aiogram, python-telegram-bot, etc.)
- Protocol: HTTP client

**Responsibilities**:
- Receive user messages/commands
- Parse user input
- Send HTTP requests to admin backend
- Format and send responses to users
- Handle user sessions

**Deployment**:
- **Replicas**: 1 (typically)
- **Resources**: 50m CPU, 64Mi memory
- **Communication**: HTTP to admin backend
- **Secrets**: Bot token (from bot platform)

**Configuration**:
```yaml
env:
  ADMIN_BACKEND_URL: http://ontu-schedule-bot-admin:8080/api/v1
  BOT_TOKEN: <from-sealed-secret>
  APP_ENV: production
  LOG_LEVEL: info
```

#### 2. ONTU Schedule Bot Admin (Backend)

**Purpose**: Backend API service with business logic.

**Technology Stack**:
- Language: Python/Node.js/Go
- Framework: FastAPI/Express/Gin
- Database ORM: SQLAlchemy/TypeORM/GORM

**Responsibilities**:
- REST API endpoints
- Business logic
- Database operations (PostgreSQL)
- Caching (Dragonfly)
- Schedule management
- User management
- Authentication/Authorization

**Deployment**:
- **Replicas**: 2-10 (autoscaling enabled)
- **Resources**: 200m CPU, 256Mi memory (request)
- **Ingress**: Enabled with TLS
- **Health checks**: `/health/live`, `/health/ready`

**Dependencies**:
- PostgreSQL (database)
- Dragonfly (cache)

**Configuration**:
```yaml
env:
  DATABASE_URL: postgresql://postgres:***@postgresql:5432/ontu_schedule
  CACHE_URL: redis://dragonfly:6379
  APP_ENV: production
  LOG_LEVEL: info
```

### Infrastructure

#### 3. PostgreSQL

**Purpose**: Primary relational database.

**Technology**:
- **Image**: postgres:15.4-alpine
- **Type**: StatefulSet
- **Storage**: Persistent volume (20Gi in production)

**Responsibilities**:
- Store user data
- Store schedule information
- Maintain data integrity
- ACID transactions

**Configuration**:
- Max connections: 200
- Shared buffers: 256MB
- Port: 5432

**Backup Strategy**:
- Regular pg_dump
- Volume snapshots
- Point-in-time recovery enabled

#### 4. Dragonfly

**Purpose**: Redis-compatible cache and session store.

**Technology**:
- **Image**: dragonflydb/dragonfly:v1.12.1
- **Type**: StatefulSet
- **Storage**: Persistent volume (10Gi in production)

**Advantages**:
- 25x faster than Redis
- More memory efficient
- Drop-in Redis replacement
- Single-instance simplicity

**Responsibilities**:
- Application caching
- Session storage
- Rate limiting data
- Temporary data storage

**Configuration**:
- Max memory: 1500MB
- Persistence: Snapshots enabled
- Port: 6379 (Redis protocol)

#### 5. Sealed Secrets Controller

**Purpose**: Secure secret management for GitOps.

**Technology**:
- **Image**: bitnami-labs/sealed-secrets-controller
- **Namespace**: kube-system
- **Type**: Deployment

**Responsibilities**:
- Decrypt SealedSecret resources
- Create regular Kubernetes Secrets
- Manage encryption keys
- Provide public key for sealing

**How It Works**:
1. Developer seals secrets with public key
2. SealedSecrets committed to Git (encrypted)
3. Controller decrypts in cluster with private key
4. Regular Secrets created for applications

## 🔄 Data Flow

### User Request Flow

```
1. User sends message to bot
   ↓
2. Bot Client receives message
   ↓
3. Bot Client sends HTTP POST to Admin Backend
   GET/POST http://ontu-schedule-bot-admin:8080/api/v1/schedule
   ↓
4. Admin Backend processes request
   ↓
5. Admin Backend queries PostgreSQL
   SELECT * FROM schedules WHERE user_id = ?
   ↓
6. Admin Backend checks/updates Dragonfly cache
   GET cache:schedule:user:123
   ↓
7. Admin Backend returns response
   ↓
8. Bot Client formats and sends to user
```

### Database Query Flow

```
1. Application receives request
   ↓
2. Check Dragonfly cache
   ├─ Cache HIT: Return cached data ✓
   └─ Cache MISS: Continue ↓
      ↓
3. Query PostgreSQL
   ↓
4. Store result in Dragonfly cache
   ↓
5. Return result to application
```

## 🔐 Security Architecture

### Secret Management

```
Developer Workstation          Git Repository           Kubernetes Cluster
┌─────────────────┐           ┌──────────────┐         ┌────────────────┐
│ 1. Create       │           │              │         │                │
│    Secret       │           │              │         │                │
│    (plain)      │           │              │         │                │
└────────┬────────┘           │              │         │                │
         │                    │              │         │                │
         │ 2. Seal with       │              │         │                │
         │    kubeseal        │              │         │                │
         ▼                    │              │         │                │
┌─────────────────┐           │              │         │                │
│ SealedSecret    │───3. Git──▶              │         │                │
│ (encrypted)     │   Push    │ Sealed       │         │                │
└─────────────────┘           │ Secret       │         │                │
                              │ (encrypted)  │──4. GitOps─▶             │
                              └──────────────┘  Sync   │  Sealed        │
                                                        │  Secrets       │
                                                        │  Controller    │
                                                        │     │          │
                                                        │     │ 5. Decrypt
                                                        │     ▼          │
                                                        │  Secret        │
                                                        │  (plain)       │
                                                        │     │          │
                                                        │     │ 6. Mount │
                                                        │     ▼          │
                                                        │  Application   │
                                                        │  Pod           │
                                                        └────────────────┘
```

### Network Security

- **Ingress**: TLS termination, cert-manager integration
- **Internal**: ClusterIP services for internal communication
- **Database**: Not exposed externally, ClusterIP only
- **Cache**: Not exposed externally, ClusterIP only

### Pod Security

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
  capabilities:
    drop:
      - ALL
```

## 📊 Scaling Strategy

### Horizontal Pod Autoscaling (HPA)

**Admin Backend**:
```yaml
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
```

**Scaling Decisions**:
- Scale up: CPU > 70% or Memory > 80%
- Scale down: Below thresholds for 5 minutes
- Max surge: 25%
- Max unavailable: 25%

### Vertical Scaling

**Database**: Increase resources by upgrading node or adjusting resource limits

**Cache**: Increase maxMemory configuration

## 🔄 High Availability

### Application Layer

- Multiple replicas (2-10 for admin backend)
- Pod Disruption Budget (min 2 available)
- Health checks (liveness + readiness)
- Rolling updates (zero downtime)

### Data Layer

**PostgreSQL**:
- Single instance (can be upgraded to HA setup)
- Persistent volumes
- Regular backups
- WAL archiving (optional)

**Dragonfly**:
- Single instance (sufficient for most use cases)
- Snapshot persistence
- Fast recovery from snapshots

## 📈 Monitoring Points

### Application Metrics

- Request rate
- Response time
- Error rate
- Active connections
- Queue depth

### Infrastructure Metrics

- CPU usage
- Memory usage
- Disk I/O
- Network I/O
- Pod restarts

### Database Metrics

- Query performance
- Connection pool
- Cache hit ratio
- Replication lag (if HA)
- Table sizes

## 🔧 Configuration Management

### Environment Variables

Stored in ConfigMaps (non-sensitive):
- APP_ENV
- LOG_LEVEL
- LOG_FORMAT
- Feature flags

### Secrets

Stored in Secrets (sealed):
- Database credentials
- Cache passwords
- API keys
- Bot tokens
- TLS certificates

### Helm Values

Organized by environment:
- `environments/production/*.yaml`
- `environments/staging/*.yaml` (future)

## 📦 Deployment Architecture

### GitOps Workflow

```
1. Developer commits code
   ↓
2. CI builds Docker image
   ↓
3. Image pushed to registry (ghcr.io)
   ↓
4. Update Helm values with new tag
   ↓
5. Commit to GitOps repo
   ↓
6. ArgoCD/Flux syncs changes (or manual helm upgrade)
   ↓
7. Kubernetes applies changes
   ↓
8. Rolling update of pods
```

## 🎯 Design Decisions

### Why Dragonfly over Redis?

- Better performance (25x faster)
- Lower memory usage
- Simpler deployment (no clustering needed)
- Full Redis compatibility
- Modern codebase

### Why StatefulSets for DB/Cache?

- Stable network identity
- Ordered deployment and scaling
- Persistent storage guarantees
- Predictable pod names

### Why Sealed Secrets?

- Native Kubernetes integration
- No external dependencies
- Simple to use
- GitOps compatible
- Public key infrastructure

### Why Separate Admin Backend and Bot Client?

- Separation of concerns
- Independent scaling
- Different resource requirements
- Can swap bot platform without changing business logic
- API can be used by multiple clients

## 🚀 Future Enhancements

- **High Availability PostgreSQL**: Multi-instance with replication
- **Multi-region Deployment**: Geographic distribution
- **Service Mesh**: Istio/Linkerd for advanced traffic management
- **Observability**: Prometheus, Grafana, Jaeger
- **Log Aggregation**: ELK stack or Loki
- **CI/CD Integration**: Automated deployments with ArgoCD
- **Development Environment**: Separate namespace with different values
- **Staging Environment**: Pre-production testing
