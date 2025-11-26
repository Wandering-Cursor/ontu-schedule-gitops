# Production Environment - README

This directory contains production environment configurations for all applications and infrastructure components.

## 📁 Files

- `postgresql.yaml` - PostgreSQL database configuration
- `dragonfly.yaml` - Dragonfly cache configuration
- `ontu-schedule-bot-admin.yaml` - Admin backend service configuration
- `ontu-schedule-bot.yaml` - Bot client service configuration
- `example-nginx.yaml` - Example NGINX application configuration

## 🚀 Deployment Order

Deploy in this order to satisfy dependencies:

### 1. Infrastructure Components

```bash
# Install Sealed Secrets controller first (if not already installed)
helm install sealed-secrets ../../infrastructure/sealed-secrets -n kube-system

# Install PostgreSQL
helm install postgresql ../../infrastructure/postgresql -f postgresql.yaml

# Install Dragonfly
helm install dragonfly ../../infrastructure/dragonfly -f dragonfly.yaml
```

### 2. Create Sealed Secrets

Before deploying applications, create sealed secrets for sensitive data:

```bash
# Example: Create sealed secret for bot token
kubectl create secret generic ontu-schedule-bot-token \
  --from-literal=token=YOUR_BOT_TOKEN \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > bot-token-sealed.yaml

kubectl apply -f bot-token-sealed.yaml
```

### 3. Deploy Applications

```bash
# Deploy admin backend
helm install ontu-schedule-bot-admin ../../apps/ontu-schedule-bot-admin \
  -f ontu-schedule-bot-admin.yaml

# Deploy bot client
helm install ontu-schedule-bot ../../apps/ontu-schedule-bot \
  -f ontu-schedule-bot.yaml

# Deploy example application (optional)
helm install example-nginx ../../apps/example-nginx \
  -f example-nginx.yaml
```

## ⚙️ Configuration Guidelines

### Before Deploying

1. **Update Domain Names**: Replace all `example.com` domains with your actual domains
2. **Set Image Tags**: Replace `latest` and version tags with specific versions
3. **Create Sealed Secrets**: Replace all placeholder passwords with sealed secrets
4. **Configure Ingress**: Ensure your ingress controller and cert-manager are installed
5. **Set Resource Limits**: Adjust resource requests/limits based on your cluster capacity

### Required Changes

Search and replace these placeholders:

- `REPLACE_WITH_SEALED_SECRET` - Replace with actual sealed secret references
- `example.com` - Replace with your domain
- `v1.0.0` - Replace with actual version tags
- Storage class names - Adjust for your cluster

## 🔐 Secrets Management

### PostgreSQL Password

```bash
# Create PostgreSQL password secret
kubectl create secret generic postgresql \
  --from-literal=username=postgres \
  --from-literal=password=YOUR_SECURE_PASSWORD \
  --from-literal=database=ontu_schedule \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > postgresql-sealed.yaml

kubectl apply -f postgresql-sealed.yaml
```

### Dragonfly Password

```bash
# Create Dragonfly password secret
kubectl create secret generic dragonfly \
  --from-literal=password=YOUR_SECURE_PASSWORD \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > dragonfly-sealed.yaml

kubectl apply -f dragonfly-sealed.yaml
```

### Bot Token

```bash
# Create bot token secret
kubectl create secret generic ontu-schedule-bot-token \
  --from-literal=token=YOUR_BOT_TOKEN \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > bot-token-sealed.yaml

kubectl apply -f bot-token-sealed.yaml
```

## 📊 Monitoring

After deployment, verify everything is running:

```bash
# Check all pods
kubectl get pods

# Check services
kubectl get svc

# Check ingress
kubectl get ingress

# Check sealed secrets
kubectl get sealedsecrets

# View logs
kubectl logs -f deployment/ontu-schedule-bot-admin
kubectl logs -f deployment/ontu-schedule-bot
```

## 🔄 Updates

To update an application:

```bash
# Update admin backend
helm upgrade ontu-schedule-bot-admin ../../apps/ontu-schedule-bot-admin \
  -f ontu-schedule-bot-admin.yaml

# Update bot
helm upgrade ontu-schedule-bot ../../apps/ontu-schedule-bot \
  -f ontu-schedule-bot.yaml
```

## 🧹 Cleanup

To remove everything:

```bash
# Uninstall applications
helm uninstall ontu-schedule-bot
helm uninstall ontu-schedule-bot-admin
helm uninstall example-nginx

# Uninstall infrastructure
helm uninstall dragonfly
helm uninstall postgresql

# Uninstall sealed secrets (optional)
helm uninstall sealed-secrets -n kube-system
```

## 📝 Notes

- All values files use production-grade configurations
- Autoscaling is enabled for the admin backend
- Pod disruption budgets ensure high availability
- Resource limits are set conservatively (adjust as needed)
- Health checks are configured for all services
- Ingress uses Let's Encrypt for TLS (requires cert-manager)
