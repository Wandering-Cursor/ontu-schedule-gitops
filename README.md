# ONTU Schedule GitOps Repository

This repository contains Helm charts and configuration files for deploying the ONTU Schedule application stack using GitOps principles.

## 📁 Repository Structure

```
.
├── apps/                           # Application Helm charts
│   ├── ontu-schedule-bot-admin/   # Admin bot with PostgreSQL and Redis
│   ├── ontu-schedule-bot/         # Client bot
│   └── example-nginx/             # Example application with secrets
├── infrastructure/                 # Infrastructure components
│   ├── postgresql/                # PostgreSQL database
│   ├── dragonfly/                 # Dragonfly (Redis-compatible cache)
│   └── sealed-secrets/            # Sealed Secrets controller
├── environments/                   # Environment-specific configurations
│   └── production/                # Production environment values
└── docs/                          # Documentation
```

## 🚀 Quick Start

### Prerequisites

- Kubernetes cluster (v1.24+)
- Helm 3.x installed
- kubectl configured
- kubeseal CLI (for sealed secrets)

### Installation Order

1. **Install infrastructure components:**
   ```bash
   # Install Sealed Secrets controller first
   helm install sealed-secrets infrastructure/sealed-secrets -n kube-system
   
   # Install PostgreSQL
   helm install postgresql infrastructure/postgresql -n default
   
   # Install Dragonfly (Redis alternative)
   helm install dragonfly infrastructure/dragonfly -n default
   ```

2. **Install applications:**
   ```bash
   # Install admin bot (depends on PostgreSQL and Dragonfly)
   helm install ontu-schedule-bot-admin apps/ontu-schedule-bot-admin \
     -f environments/production/ontu-schedule-bot-admin.yaml
   
   # Install client bot
   helm install ontu-schedule-bot apps/ontu-schedule-bot \
     -f environments/production/ontu-schedule-bot.yaml
   ```

3. **Install example application:**
   ```bash
   helm install example-nginx apps/example-nginx \
     -f environments/production/example-nginx.yaml
   ```

## 🔐 Managing Secrets

This repository uses **Sealed Secrets** for secure secret management in Git.

### Creating Sealed Secrets

1. Create a regular Kubernetes secret:
   ```bash
   kubectl create secret generic my-secret \
     --from-literal=password=mysecretpassword \
     --dry-run=client -o yaml > secret.yaml
   ```

2. Seal the secret:
   ```bash
   kubeseal -f secret.yaml -w sealed-secret.yaml
   ```

3. Commit `sealed-secret.yaml` to Git (it's safe to commit!)

See [docs/sealed-secrets-guide.md](docs/sealed-secrets-guide.md) for detailed instructions.

## 📚 Documentation

- [Sealed Secrets Guide](docs/sealed-secrets-guide.md) - How to manage secrets
- [Deployment Guide](docs/deployment-guide.md) - Step-by-step deployment instructions
- [Architecture Overview](docs/architecture.md) - System architecture and dependencies

## 🔄 Updating Applications

To update an application:

```bash
helm upgrade ontu-schedule-bot-admin apps/ontu-schedule-bot-admin \
  -f environments/production/ontu-schedule-bot-admin.yaml
```

## 🧹 Cleanup

To remove all resources:

```bash
helm uninstall ontu-schedule-bot
helm uninstall ontu-schedule-bot-admin
helm uninstall example-nginx
helm uninstall dragonfly
helm uninstall postgresql
helm uninstall sealed-secrets -n kube-system
```

## 📝 License

This repository is public and available for use.
