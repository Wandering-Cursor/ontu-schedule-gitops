# Using Public Container Images from GHCR

## Overview

This repository is configured to pull container images from GitHub Container Registry (GHCR). Since your packages are public, **no authentication is required** for pulling images.

## Image Configuration

### Current Setup

The `ontu-schedule-bot-admin` application is configured to use:

```yaml
image:
  repository: ghcr.io/wandering-cursor/ontu-schedule-bot-admin
  pullPolicy: Always
  tag: ""  # Defaults to Chart.appVersion or environment-specific tag
```

### No Image Pull Secrets Needed

For **public** GHCR images:
- ✅ No `imagePullSecrets` required
- ✅ No authentication tokens needed
- ✅ Works out of the box in any Kubernetes cluster

### Environment-Specific Tags

Different environments use different image tags:

- **Dev**: `develop` tag
- **Staging**: `staging` tag  
- **Production**: `v1.0.0` (or specific version tags)

## Switching to Private Images

If you need to use **private** GHCR images in the future, follow these steps:

### 1. Create a GitHub Personal Access Token (PAT)

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token with `read:packages` scope
3. Save the token securely

### 2. Create Docker Registry Secret

```bash
# Create the secret in each namespace
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=<your-github-username> \
  --docker-password=<your-github-pat> \
  --docker-email=<your-email> \
  -n ontu-schedule-dev

# Repeat for other namespaces
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=<your-github-username> \
  --docker-password=<your-github-pat> \
  --docker-email=<your-email> \
  -n ontu-schedule-staging

kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=<your-github-username> \
  --docker-password=<your-github-pat> \
  --docker-email=<your-email> \
  -n ontu-schedule-prod
```

### 3. Encrypt the Secret with Sealed Secrets

For GitOps approach, encrypt the secret:

```bash
# Create a temporary secret manifest
cat > ghcr-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ghcr-secret
  namespace: ontu-schedule-dev
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: $(kubectl create secret docker-registry ghcr-secret \
    --docker-server=ghcr.io \
    --docker-username=<username> \
    --docker-password=<token> \
    --docker-email=<email> \
    --dry-run=client -o jsonpath='{.data.\.dockerconfigjson}')
EOF

# Encrypt it
./scripts/seal-secret.sh encrypt-file ghcr-secret.yaml

# Commit the sealed secret
git add ghcr-secret-sealed.yaml
git commit -m "Add encrypted GHCR credentials"

# Clean up temporary file
rm ghcr-secret.yaml
```

### 4. Update Helm Values

Add the image pull secret to your values files:

```yaml
# environments/dev/ontu-schedule-bot-admin-values.yaml
imagePullSecrets:
  - name: ghcr-secret
```

### 5. Create SealedSecret Template (Alternative)

Or create a template in your Helm chart:

```yaml
# apps/ontu-schedule-bot-admin/templates/ghcr-secret.yaml
{{- if .Values.ghcrSecret.enabled }}
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: ghcr-secret
  namespace: {{ .Release.Namespace }}
spec:
  encryptedData:
    .dockerconfigjson: {{ .Values.ghcrSecret.encryptedData }}
  template:
    type: kubernetes.io/dockerconfigjson
{{- end }}
```

Then in values:

```yaml
ghcrSecret:
  enabled: true
  encryptedData: "AgB..." # Encrypted .dockerconfigjson
```

## Best Practices

### Public Images
- ✅ Use public images for open-source projects
- ✅ No secrets management overhead
- ✅ Easier CI/CD integration
- ⚠️ Anyone can pull your images
- ⚠️ No access control

### Private Images
- ✅ Access control
- ✅ Keep proprietary code private
- ✅ Comply with licensing requirements
- ⚠️ Requires credential management
- ⚠️ More complex setup

## Verifying Image Access

### Test Public Image Pull

```bash
# Try pulling the image directly
docker pull ghcr.io/wandering-cursor/ontu-schedule-bot-admin:develop

# Check if image is public on GHCR
curl -s https://ghcr.io/v2/wandering-cursor/ontu-schedule-bot-admin/tags/list
```

### Monitor Pull Errors in Kubernetes

```bash
# Check pod events
kubectl describe pod -n ontu-schedule-dev <pod-name>

# Look for ImagePullBackOff errors
kubectl get pods -n ontu-schedule-dev
```

## GitHub Actions Integration

### Publishing Images to GHCR

Example workflow for building and pushing images:

```yaml
name: Build and Push to GHCR
on:
  push:
    branches: [main, develop]
    tags: ['v*']

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Log in to GHCR
        uses: docker/login-action@v2
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v4
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=ref,event=branch
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
      
      - name: Build and push
        uses: docker/build-push-action@v4
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

### Making Images Public

1. Go to your GitHub package page
2. Click "Package settings"
3. Scroll to "Danger Zone"
4. Click "Change visibility"
5. Select "Public"

## Rate Limiting

### Anonymous Pulls
GHCR allows anonymous pulls for public images, but with rate limits:
- ~100 pulls per hour per IP

### Authenticated Pulls
Using authentication increases limits significantly:
- Create PAT with `read:packages`
- Use in CI/CD pipelines
- Document in team guidelines

## Troubleshooting

### Image Not Found

```bash
# Verify image exists
docker pull ghcr.io/wandering-cursor/ontu-schedule-bot-admin:develop

# Check available tags
curl -s -H "Authorization: Bearer $(echo -n '<username>:<pat>' | base64)" \
  https://ghcr.io/v2/wandering-cursor/ontu-schedule-bot-admin/tags/list
```

### Permission Denied

If you see permission errors on public images:
- Image might not be published yet
- Image visibility might be private
- Network/firewall issues

### Rate Limiting

If you hit rate limits:
- Add authentication even for public images
- Use image pull secrets with GitHub PAT
- Implement image caching in your cluster

## References

- [GitHub Packages Documentation](https://docs.github.com/en/packages)
- [GHCR Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [Kubernetes Image Pull Secrets](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/)
