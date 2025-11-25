#!/bin/bash

# PostgreSQL Secrets Setup
# This script helps create and encrypt PostgreSQL credentials for all environments

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check for required tools
if ! command -v kubeseal &> /dev/null; then
    error "kubeseal is not installed"
    echo "Install it first: ./scripts/seal-secret.sh (it will guide you)"
    exit 1
fi

if ! command -v openssl &> /dev/null; then
    error "openssl is not installed"
    exit 1
fi

# Fetch certificate if not present
CERT_FILE="pub-cert.pem"
if [ ! -f "$CERT_FILE" ]; then
    warn "Certificate not found. Fetching..."
    ./scripts/seal-secret.sh fetch-cert
fi

info "Setting up PostgreSQL secrets for all environments"
echo ""

# Generate passwords
info "Generating strong passwords..."
POSTGRES_PASSWORD_DEV=$(openssl rand -base64 32)
USER_PASSWORD_DEV=$(openssl rand -base64 32)

POSTGRES_PASSWORD_STAGING=$(openssl rand -base64 32)
USER_PASSWORD_STAGING=$(openssl rand -base64 32)

POSTGRES_PASSWORD_PROD=$(openssl rand -base64 32)
USER_PASSWORD_PROD=$(openssl rand -base64 32)

echo ""
info "Encrypting passwords for each environment..."

# Function to encrypt and create SealedSecret
create_sealed_secret() {
    local env=$1
    local namespace=$2
    local postgres_pwd=$3
    local user_pwd=$4
    
    info "Processing $env environment..."
    
    # Create temporary secret
    cat > /tmp/postgres-secret-${env}.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: postgresql-secrets
  namespace: $namespace
type: Opaque
stringData:
  postgres-password: "$postgres_pwd"
  password: "$user_pwd"
EOF
    
    # Encrypt it
    kubeseal --cert="$CERT_FILE" \
        < /tmp/postgres-secret-${env}.yaml \
        > infrastructure/postgresql/sealedsecret-${env}.yaml
    
    # Clean up
    rm /tmp/postgres-secret-${env}.yaml
    
    info "Created infrastructure/postgresql/sealedsecret-${env}.yaml"
}

# Create sealed secrets for each environment
create_sealed_secret "dev" "ontu-schedule-dev" "$POSTGRES_PASSWORD_DEV" "$USER_PASSWORD_DEV"
create_sealed_secret "staging" "ontu-schedule-staging" "$POSTGRES_PASSWORD_STAGING" "$USER_PASSWORD_STAGING"
create_sealed_secret "prod" "ontu-schedule-prod" "$POSTGRES_PASSWORD_PROD" "$USER_PASSWORD_PROD"

echo ""
info "✅ All PostgreSQL secrets created and encrypted!"
echo ""
echo "Next steps:"
echo "  1. Review the sealed secret files in infrastructure/postgresql/"
echo "  2. Commit them to Git:"
echo "     git add infrastructure/postgresql/sealedsecret-*.yaml"
echo "     git commit -m 'Add PostgreSQL encrypted secrets'"
echo "     git push"
echo ""
echo "  3. ArgoCD will automatically deploy them with PostgreSQL"
echo ""
warn "IMPORTANT: Save these passwords securely! You won't see them again."
echo ""
echo "=== DEV Environment ==="
echo "Postgres Admin Password: $POSTGRES_PASSWORD_DEV"
echo "User Password: $USER_PASSWORD_DEV"
echo ""
echo "=== STAGING Environment ==="
echo "Postgres Admin Password: $POSTGRES_PASSWORD_STAGING"
echo "User Password: $USER_PASSWORD_STAGING"
echo ""
echo "=== PROD Environment ==="
echo "Postgres Admin Password: $POSTGRES_PASSWORD_PROD"
echo "User Password: $USER_PASSWORD_PROD"
echo ""
warn "Copy these to your password manager NOW!"
