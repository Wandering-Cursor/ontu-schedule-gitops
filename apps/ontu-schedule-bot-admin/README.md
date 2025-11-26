# ONTU Schedule Bot Admin Helm Chart

Admin backend service for the ONTU Schedule application. This service connects to PostgreSQL and Dragonfly (Redis) for data storage and caching.

## Prerequisites

- PostgreSQL instance running (see `infrastructure/postgresql`)
- Dragonfly instance running (see `infrastructure/dragonfly`)
- Sealed Secrets controller installed (optional, for production secrets)

## Installation

```bash
helm install ontu-schedule-bot-admin . \
  -f environments/production/ontu-schedule-bot-admin.yaml
```

## Configuration

### Required Configuration

Update these in your environment values file:

- `image.repository`: Your Docker image repository
- `image.tag`: Specific version tag
- `ingress.hosts`: Your domain name
- `database.host`: PostgreSQL service name
- `cache.host`: Dragonfly service name

### Database Connection

The chart supports two modes for database credentials:

1. **External Secret** (recommended):
   - Set `database.useExternalSecret: true`
   - Set `database.externalSecretName` to your PostgreSQL secret
   - The chart will read the password from the external secret

2. **Inline Secret**:
   - Set `database.useExternalSecret: false`
   - Create a SealedSecret with the database password

### Environment Variables

Add custom environment variables in `values.yaml`:

```yaml
env:
  APP_ENV: "production"
  LOG_LEVEL: "info"
  API_TIMEOUT: "30"
```

## Health Checks

The application should expose these endpoints:

- `/health/live`: Liveness probe (is the app running?)
- `/health/ready`: Readiness probe (is the app ready to serve traffic?)

## Autoscaling

Enable horizontal pod autoscaling:

```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
```

## Connection Strings

The chart automatically constructs connection strings:

- `DATABASE_URL`: PostgreSQL connection string
- `CACHE_URL`: Redis/Dragonfly connection string

These are available as environment variables in your application.
