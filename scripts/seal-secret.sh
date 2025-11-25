#!/bin/bash

# Sealed Secrets Helper Script
# This script helps encrypt secrets for use with Sealed Secrets

set -e

CERT_FILE="pub-cert.pem"
CONTROLLER_NAME="sealed-secrets-controller"
CONTROLLER_NAMESPACE="sealed-secrets"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubeseal is installed
check_kubeseal() {
    if ! command -v kubeseal &> /dev/null; then
        error "kubeseal is not installed"
        echo ""
        echo "Install kubeseal:"
        echo "  macOS:  brew install kubeseal"
        echo "  Linux:  wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-0.24.0-linux-amd64.tar.gz"
        echo "          tar xfz kubeseal-0.24.0-linux-amd64.tar.gz"
        echo "          sudo install -m 755 kubeseal /usr/local/bin/kubeseal"
        exit 1
    fi
}

# Fetch the public certificate
fetch_cert() {
    info "Fetching Sealed Secrets public certificate..."
    
    if kubeseal --fetch-cert \
        --controller-name="$CONTROLLER_NAME" \
        --controller-namespace="$CONTROLLER_NAMESPACE" \
        > "$CERT_FILE" 2>/dev/null; then
        info "Certificate saved to $CERT_FILE"
    else
        error "Failed to fetch certificate. Is Sealed Secrets controller running?"
        echo ""
        echo "Make sure:"
        echo "  1. ArgoCD has deployed the sealed-secrets application"
        echo "  2. The controller is running: kubectl get pods -n sealed-secrets"
        echo "  3. kubectl is configured to access your cluster"
        exit 1
    fi
}

# Encrypt a secret value
encrypt_value() {
    local secret_name=$1
    local namespace=$2
    local value=$3
    
    if [ -z "$secret_name" ] || [ -z "$namespace" ] || [ -z "$value" ]; then
        error "Missing parameters"
        echo "Usage: $0 encrypt-value <secret-name> <namespace> <value>"
        exit 1
    fi
    
    if [ ! -f "$CERT_FILE" ]; then
        warn "Certificate not found. Fetching..."
        fetch_cert
    fi
    
    info "Encrypting value for secret '$secret_name' in namespace '$namespace'..."
    
    encrypted=$(echo -n "$value" | kubeseal --raw \
        --from-file=/dev/stdin \
        --name="$secret_name" \
        --namespace="$namespace" \
        --cert="$CERT_FILE")
    
    echo ""
    info "Encrypted value (copy this to your values file):"
    echo "$encrypted"
}

# Encrypt a file containing secret data
encrypt_file() {
    local input_file=$1
    local output_file=$2
    
    if [ -z "$input_file" ]; then
        error "Missing input file"
        echo "Usage: $0 encrypt-file <input-file> [output-file]"
        exit 1
    fi
    
    if [ ! -f "$input_file" ]; then
        error "File not found: $input_file"
        exit 1
    fi
    
    if [ -z "$output_file" ]; then
        output_file="${input_file%.yaml}-sealed.yaml"
    fi
    
    if [ ! -f "$CERT_FILE" ]; then
        warn "Certificate not found. Fetching..."
        fetch_cert
    fi
    
    info "Encrypting secret from $input_file..."
    
    kubeseal --cert="$CERT_FILE" < "$input_file" > "$output_file"
    
    info "Sealed secret saved to $output_file"
}

# Interactive mode for encrypting values
interactive() {
    echo ""
    info "Interactive Secret Encryption"
    echo ""
    
    read -p "Secret name (e.g., my-app-secrets): " secret_name
    read -p "Namespace (e.g., ontu-schedule-dev): " namespace
    read -p "Secret key (e.g., DATABASE_PASSWORD): " key
    read -sp "Secret value: " value
    echo ""
    
    if [ ! -f "$CERT_FILE" ]; then
        warn "Certificate not found. Fetching..."
        fetch_cert
    fi
    
    info "Encrypting..."
    
    encrypted=$(echo -n "$value" | kubeseal --raw \
        --from-file=/dev/stdin \
        --name="$secret_name" \
        --namespace="$namespace" \
        --cert="$CERT_FILE")
    
    echo ""
    info "Add this to your values file under secrets.data:"
    echo ""
    echo "secrets:"
    echo "  enabled: true"
    echo "  data:"
    echo "    $key: $encrypted"
    echo ""
}

# Show help
show_help() {
    echo "Sealed Secrets Helper Script"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  fetch-cert                          Fetch the Sealed Secrets public certificate"
    echo "  encrypt-value <name> <ns> <value>   Encrypt a single value"
    echo "  encrypt-file <input> [output]       Encrypt a Secret manifest file"
    echo "  interactive                         Interactive encryption mode"
    echo "  help                                Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 fetch-cert"
    echo "  $0 encrypt-value my-app-secrets ontu-schedule-dev 'my-password'"
    echo "  $0 encrypt-file secret.yaml sealed-secret.yaml"
    echo "  $0 interactive"
    echo ""
}

# Main
check_kubeseal

case "${1:-}" in
    fetch-cert)
        fetch_cert
        ;;
    encrypt-value)
        encrypt_value "$2" "$3" "$4"
        ;;
    encrypt-file)
        encrypt_file "$2" "$3"
        ;;
    interactive)
        interactive
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        error "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
