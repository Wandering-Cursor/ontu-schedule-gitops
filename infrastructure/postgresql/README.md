# PostgreSQL Helm Chart

PostgreSQL database deployment for ONTU Schedule applications.

## Installation

```bash
helm install postgresql . -f your-values.yaml
```

## Configuration

Key configuration options:

- `auth.username`: PostgreSQL admin username (default: postgres)
- `auth.password`: PostgreSQL admin password (CHANGE THIS!)
- `auth.database`: Default database name
- `persistence.enabled`: Enable persistent storage (default: true)
- `persistence.size`: Size of persistent volume (default: 10Gi)

## Using with Sealed Secrets

For production, create a sealed secret instead of using plain values:

1. Create a secret file:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgresql
  namespace: default
type: Opaque
stringData:
  username: postgres
  password: your-secure-password
  database: ontu_schedule
```

2. Seal it:
```bash
kubeseal -f secret.yaml -w postgresql-sealed.yaml
```

3. Apply the sealed secret before installing the chart.

## Accessing PostgreSQL

From within the cluster:
```bash
psql -h postgresql -U postgres -d ontu_schedule
```

Connection string format:
```
postgresql://postgres:password@postgresql:5432/ontu_schedule
```
