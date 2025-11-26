# Example NGINX Application Helm Chart

This is an example application that demonstrates best practices for using:
- **ConfigMaps** for non-sensitive configuration
- **Secrets** for sensitive data
- **SealedSecrets** for secure secret management in Git
- **Environment variables** in Kubernetes deployments
- **Custom NGINX configuration**

## 🎯 Purpose

This example shows you how to properly structure a Helm chart with secrets and configuration management, which you can use as a template for your own applications.

## 📦 What's Included

- NGINX deployment with custom configuration
- ConfigMaps for:
  - Application configuration (env vars)
  - NGINX server configuration
  - Custom HTML content
- Secrets for sensitive data (API keys, passwords, tokens)
- Service and Ingress for exposure
- Health check endpoints
- Proper security contexts

## 🚀 Quick Start

### Basic Installation

```bash
helm install example-nginx . -f your-values.yaml
```

### With Custom Values

```bash
helm install example-nginx . \
  --set ingress.hosts[0].host=example.yourdomain.com \
  --set secrets.API_KEY=your-actual-api-key
```

## 🔐 Using SealedSecrets (Production)

**IMPORTANT**: Never commit real secrets to Git! Use SealedSecrets instead.

### Step 1: Create a regular secret file

Create `secret.yaml`:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: example-nginx-secret
  namespace: default
type: Opaque
stringData:
  API_KEY: "your-real-api-key"
  DB_PASSWORD: "your-real-password"
  JWT_SECRET: "your-real-jwt-secret"
  EXTERNAL_SERVICE_TOKEN: "your-real-token"
```

### Step 2: Seal the secret

```bash
kubeseal -f secret.yaml -w example-nginx-sealed-secret.yaml
```

### Step 3: Apply the sealed secret

```bash
kubectl apply -f example-nginx-sealed-secret.yaml
```

### Step 4: Update the chart to use the sealed secret

Remove or comment out the `templates/secret.yaml` file, and the sealed secret controller will automatically create the actual secret from your sealed secret.

## 📝 Configuration Examples

### Adding Environment Variables

In `values.yaml`:
```yaml
config:
  APP_NAME: "My Application"
  CUSTOM_SETTING: "value"
  FEATURE_FLAG: "true"
```

These become environment variables in the pod:
```bash
kubectl exec -it <pod-name> -- env | grep APP_NAME
```

### Adding Secrets

In `values.yaml` (for development only!):
```yaml
secrets:
  NEW_SECRET: "value"
```

For production, create a SealedSecret instead.

### Custom NGINX Configuration

Modify the `nginxConfig` in `values.yaml`:
```yaml
nginxConfig: |
  server {
      listen 80;
      location /custom {
          return 200 "Custom endpoint\n";
      }
  }
```

## 🔍 Accessing the Application

### Port Forward (Local Testing)

```bash
kubectl port-forward svc/example-nginx 8080:80
```

Then visit: http://localhost:8080

### Via Ingress

Configure your ingress host:
```yaml
ingress:
  enabled: true
  hosts:
    - host: example.yourdomain.com
```

Then visit: http://example.yourdomain.com

## 🏥 Health Checks

The application exposes a health endpoint at `/health`:

```bash
curl http://localhost:8080/health
# Output: healthy
```

## 🛠️ Customization

### Change HTML Content

Modify `htmlContent` in `values.yaml` to customize the web page.

### Change Resource Limits

```yaml
resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 100m
    memory: 128Mi
```

## 📚 Learning Resources

This example demonstrates:

1. **ConfigMaps**: For non-sensitive data
   - See `templates/configmap.yaml`
   - See `templates/configmap-nginx.yaml`
   - See `templates/configmap-html.yaml`

2. **Secrets**: For sensitive data
   - See `templates/secret.yaml`
   - Should be replaced with SealedSecrets in production

3. **Environment Variables**: Multiple ways to inject them
   - `envFrom` for bulk loading from ConfigMap
   - `env` for individual variables from ConfigMap or Secret
   - See `templates/deployment.yaml`

4. **Volume Mounts**: Mounting ConfigMaps as files
   - NGINX configuration as a file
   - HTML content as files

5. **Health Checks**: Liveness and readiness probes
   - HTTP-based health checks at `/health`

## 🧹 Cleanup

```bash
helm uninstall example-nginx
```

## ⚠️ Security Notes

1. **Never commit real secrets to Git**
2. **Always use SealedSecrets in production**
3. **Rotate secrets regularly**
4. **Use RBAC to limit secret access**
5. **Enable TLS/HTTPS in production**

## 📖 Next Steps

- Review the sealed-secrets documentation: `docs/sealed-secrets-guide.md`
- Customize this template for your own applications
- Set up proper ingress with TLS
- Configure monitoring and logging
