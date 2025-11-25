#!/bin/bash

# New Application Creator
# This script helps create a new application following the repository structure

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Get application details
echo ""
echo "=== Create New Application ==="
echo ""

read -p "Application name (e.g., my-app): " APP_NAME
read -p "Image repository (e.g., ghcr.io/user/repo): " IMAGE_REPO
read -p "Default image tag (e.g., latest): " IMAGE_TAG
read -p "Service port (e.g., 8080): " SERVICE_PORT

if [ -z "$APP_NAME" ] || [ -z "$IMAGE_REPO" ]; then
    echo "Error: Application name and image repository are required"
    exit 1
fi

IMAGE_TAG=${IMAGE_TAG:-latest}
SERVICE_PORT=${SERVICE_PORT:-8080}

APP_DIR="apps/$APP_NAME"
TEMPLATE_DIR="apps/ontu-schedule-bot-admin"

# Create application directory
info "Creating application directory: $APP_DIR"
mkdir -p "$APP_DIR/templates"

# Copy and customize Chart.yaml
info "Creating Chart.yaml"
cat > "$APP_DIR/Chart.yaml" <<EOF
apiVersion: v2
name: $APP_NAME
description: A Helm chart for $APP_NAME
type: application
version: 0.1.0
appVersion: "$IMAGE_TAG"
EOF

# Copy and customize values.yaml
info "Creating values.yaml"
cat > "$APP_DIR/values.yaml" <<EOF
replicaCount: 1

image:
  repository: $IMAGE_REPO
  pullPolicy: Always
  tag: ""

imagePullSecrets: []
nameOverride: ""
fullnameOverride: ""

serviceAccount:
  create: true
  automount: true
  annotations: {}
  name: ""

podAnnotations: {}
podLabels: {}

podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: true

service:
  type: ClusterIP
  port: $SERVICE_PORT

env: []
envFrom: []

configMap:
  enabled: false
  data: {}

secrets:
  enabled: false
  data: {}

ingress:
  enabled: false
  className: ""
  annotations: {}
  hosts:
    - host: chart-example.local
      paths:
        - path: /
          pathType: ImplementationSpecific
  tls: []

httpRoute:
  enabled: false
  annotations: {}
  parentRefs:
  - name: gateway
    sectionName: http
  hostnames:
  - chart-example.local
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

livenessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: http
  initialDelaySeconds: 5
  periodSeconds: 5

autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80

volumes: []
volumeMounts: []

nodeSelector: {}
tolerations: []
affinity: {}
EOF

# Copy templates and update them
info "Copying and customizing templates"
cp "$TEMPLATE_DIR/.helmignore" "$APP_DIR/"

# Create _helpers.tpl
sed "s/ontu-schedule-bot-admin/$APP_NAME/g" "$TEMPLATE_DIR/templates/_helpers.tpl" > "$APP_DIR/templates/_helpers.tpl"

# Copy and update other templates
for template in deployment.yaml service.yaml serviceaccount.yaml configmap.yaml sealedsecret.yaml ingress.yaml hpa.yaml; do
    sed "s/ontu-schedule-bot-admin/$APP_NAME/g" "$TEMPLATE_DIR/templates/$template" > "$APP_DIR/templates/$template"
done

# Create environment values
info "Creating environment-specific values"

for env in dev staging prod; do
    ENV_DIR="environments/$env"
    mkdir -p "$ENV_DIR"
    
    case $env in
        dev)
            TAG="develop"
            REPLICAS=1
            CPU_LIMIT="200m"
            MEM_LIMIT="256Mi"
            CPU_REQ="50m"
            MEM_REQ="64Mi"
            ;;
        staging)
            TAG="staging"
            REPLICAS=2
            CPU_LIMIT="400m"
            MEM_LIMIT="512Mi"
            CPU_REQ="100m"
            MEM_REQ="128Mi"
            ;;
        prod)
            TAG="v1.0.0"
            REPLICAS=3
            CPU_LIMIT="1000m"
            MEM_LIMIT="1Gi"
            CPU_REQ="200m"
            MEM_REQ="256Mi"
            ;;
    esac
    
    cat > "$ENV_DIR/${APP_NAME}-values.yaml" <<EOF
# $env environment values for $APP_NAME

image:
  tag: "$TAG"

replicaCount: $REPLICAS

configMap:
  enabled: true
  data:
    ENVIRONMENT: "$env"

secrets:
  enabled: false
  data: {}

envFrom:
  - configMapRef:
      name: $APP_NAME

resources:
  limits:
    cpu: $CPU_LIMIT
    memory: $MEM_LIMIT
  requests:
    cpu: $CPU_REQ
    memory: $MEM_REQ
EOF
done

# Create ArgoCD Application manifests
info "Creating ArgoCD Application manifests"

for env in dev staging prod; do
    NAMESPACE="ontu-schedule-$env"
    
    if [ "$env" = "prod" ]; then
        AUTO_PRUNE="false"
        AUTO_HEAL="false"
    else
        AUTO_PRUNE="true"
        AUTO_HEAL="true"
    fi
    
    cat > "argocd/applications/${APP_NAME}-${env}.yaml" <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${APP_NAME}-${env}
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: ontu-schedule
  
  source:
    repoURL: https://github.com/Wandering-Cursor/ontu-schedule-gitops.git
    targetRevision: HEAD
    path: apps/$APP_NAME
    helm:
      releaseName: $APP_NAME
      valueFiles:
        - ../../environments/${env}/${APP_NAME}-values.yaml
  
  destination:
    server: https://kubernetes.default.svc
    namespace: $NAMESPACE
  
  syncPolicy:
    automated:
      prune: $AUTO_PRUNE
      selfHeal: $AUTO_HEAL
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas
EOF
done

echo ""
info "Application '$APP_NAME' created successfully!"
echo ""
echo "Next steps:"
echo "  1. Review and customize the files in $APP_DIR"
echo "  2. Update health check paths in values.yaml (livenessProbe/readinessProbe)"
echo "  3. Add any required environment variables in environment values files"
echo "  4. If you need secrets, use: ./scripts/seal-secret.sh interactive"
echo "  5. Commit and push:"
echo ""
echo "     git add $APP_DIR environments/ argocd/applications/${APP_NAME}-*.yaml"
echo "     git commit -m 'Add $APP_NAME application'"
echo "     git push"
echo ""
echo "  6. ArgoCD will automatically detect and deploy your application!"
echo ""
