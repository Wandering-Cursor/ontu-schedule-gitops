# ONTU Schedule Bot Helm Chart

Client bot service for the ONTU Schedule application. This service communicates with the admin backend via HTTP requests.

## Prerequisites

- Admin backend service running (see `apps/ontu-schedule-bot-admin`)
- Bot token from your bot platform (Telegram, Discord, etc.)

## Installation

```bash
helm install ontu-schedule-bot . \
  -f environments/production/ontu-schedule-bot.yaml
```

## Configuration

### Required Configuration

Update these in your environment values file:

- `image.repository`: Your Docker image repository
- `image.tag`: Specific version tag
- `adminBackend.host`: Admin backend service name (default: ontu-schedule-bot-admin)
- `bot.token`: Your bot token (use SealedSecret in production!)

### Admin Backend Connection

The bot connects to the admin backend using:

```
ADMIN_BACKEND_URL = http://ontu-schedule-bot-admin:8080/api/v1
```

You can customize this in `values.yaml`:

```yaml
adminBackend:
  host: "ontu-schedule-bot-admin"
  port: 8080
  protocol: "http"
  apiPath: "/api/v1"
```

### Bot Token

**IMPORTANT**: Never commit your bot token in plain text!

For production, create a SealedSecret:

1. Create a secret file:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ontu-schedule-bot-token
  namespace: default
type: Opaque
stringData:
  token: your-actual-bot-token
```

2. Seal it:
```bash
kubeseal -f secret.yaml -w bot-token-sealed.yaml
```

3. Apply the sealed secret and configure the chart:
```yaml
bot:
  useExternalSecret: true
  externalSecretName: "ontu-schedule-bot-token"
  tokenKey: "token"
```

### Environment Variables

Add custom environment variables:

```yaml
env:
  APP_ENV: "production"
  LOG_LEVEL: "info"
  POLLING_INTERVAL: "60"
```

## Health Checks

The application should expose:

- `/health/live`: Liveness probe
- `/health/ready`: Readiness probe

## Scaling

For high-traffic bots, enable autoscaling:

```yaml
autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 5
  targetCPUUtilizationPercentage: 80
```

Note: Ensure your bot can handle multiple instances (use proper session management).
