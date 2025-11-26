# Dragonfly Helm Chart

Dragonfly is a modern, Redis-compatible in-memory datastore that's faster and more memory-efficient than Redis.

## Features

- **Redis Compatible**: Drop-in replacement for Redis
- **High Performance**: 25x faster than Redis on some workloads
- **Memory Efficient**: Uses less memory than Redis
- **Simple**: Single-binary deployment, no cluster configuration needed

## Installation

```bash
helm install dragonfly . -f your-values.yaml
```

## Configuration

Key configuration options:

- `auth.password`: Password for accessing Dragonfly (leave empty for no auth)
- `persistence.enabled`: Enable persistent storage (default: true)
- `persistence.size`: Size of persistent volume (default: 5Gi)
- `config.maxMemory`: Maximum memory in MB (0 = auto)
- `config.snapshot`: Enable snapshot persistence

## Using with Sealed Secrets

For production with authentication, create a sealed secret:

1. Create a secret file:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: dragonfly
  namespace: default
type: Opaque
stringData:
  password: your-secure-password
```

2. Seal it:
```bash
kubeseal -f secret.yaml -w dragonfly-sealed.yaml
```

3. Apply the sealed secret before installing the chart.

## Accessing Dragonfly

From within the cluster using redis-cli:
```bash
redis-cli -h dragonfly -p 6379
```

Connection URL format:
```
redis://dragonfly:6379
# or with password
redis://:password@dragonfly:6379
```

## Using with Python (redis-py)

```python
import redis

r = redis.Redis(host='dragonfly', port=6379, password='your-password')
r.set('key', 'value')
print(r.get('key'))
```
