# Makefile for ONTU Schedule GitOps Repository
# Provides convenient shortcuts for common operations

.PHONY: help install-infrastructure install-apps install-all uninstall-all verify status logs backup clean seal-secret

# Default target
.DEFAULT_GOAL := help

# Variables
NAMESPACE ?= default
KUBESEAL_CERT ?= pub-cert.pem

##@ General

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Setup

install-sealed-secrets: ## Install Sealed Secrets controller
	@echo "📦 Installing Sealed Secrets controller..."
	helm install sealed-secrets infrastructure/sealed-secrets -n kube-system
	@echo "⏳ Waiting for deployment..."
	kubectl wait --for=condition=available --timeout=60s deployment/sealed-secrets -n kube-system
	@echo "✅ Sealed Secrets controller installed"
	@echo "📝 Fetching public certificate..."
	kubeseal --fetch-cert > $(KUBESEAL_CERT)
	@echo "✅ Certificate saved to $(KUBESEAL_CERT)"

fetch-cert: ## Fetch Sealed Secrets public certificate
	@echo "📝 Fetching public certificate..."
	kubeseal --fetch-cert > $(KUBESEAL_CERT)
	@echo "✅ Certificate saved to $(KUBESEAL_CERT)"

##@ Infrastructure

install-postgresql: ## Install PostgreSQL
	@echo "📦 Installing PostgreSQL..."
	helm install postgresql infrastructure/postgresql \
		-f environments/production/postgresql.yaml \
		-n $(NAMESPACE)
	@echo "⏳ Waiting for PostgreSQL to be ready..."
	kubectl wait --for=condition=ready --timeout=120s pod/postgresql-0 -n $(NAMESPACE)
	@echo "✅ PostgreSQL installed and ready"

install-dragonfly: ## Install Dragonfly cache
	@echo "📦 Installing Dragonfly..."
	helm install dragonfly infrastructure/dragonfly \
		-f environments/production/dragonfly.yaml \
		-n $(NAMESPACE)
	@echo "⏳ Waiting for Dragonfly to be ready..."
	kubectl wait --for=condition=ready --timeout=120s pod/dragonfly-0 -n $(NAMESPACE)
	@echo "✅ Dragonfly installed and ready"

install-infrastructure: install-sealed-secrets install-postgresql install-dragonfly ## Install all infrastructure components
	@echo "✅ All infrastructure components installed"

##@ Applications

install-admin: ## Install ONTU Schedule Bot Admin
	@echo "📦 Installing ONTU Schedule Bot Admin..."
	helm install ontu-schedule-bot-admin apps/ontu-schedule-bot-admin \
		-f environments/production/ontu-schedule-bot-admin.yaml \
		-n $(NAMESPACE)
	@echo "⏳ Waiting for deployment..."
	kubectl wait --for=condition=available --timeout=120s \
		deployment/ontu-schedule-bot-admin -n $(NAMESPACE)
	@echo "✅ Admin backend installed and ready"

install-bot: ## Install ONTU Schedule Bot
	@echo "📦 Installing ONTU Schedule Bot..."
	helm install ontu-schedule-bot apps/ontu-schedule-bot \
		-f environments/production/ontu-schedule-bot.yaml \
		-n $(NAMESPACE)
	@echo "⏳ Waiting for deployment..."
	kubectl wait --for=condition=available --timeout=120s \
		deployment/ontu-schedule-bot -n $(NAMESPACE)
	@echo "✅ Bot client installed and ready"

install-example: ## Install example NGINX application
	@echo "📦 Installing example NGINX..."
	helm install example-nginx apps/example-nginx \
		-f environments/production/example-nginx.yaml \
		-n $(NAMESPACE)
	@echo "✅ Example NGINX installed"

install-apps: install-admin install-bot ## Install all applications
	@echo "✅ All applications installed"

install-all: install-infrastructure install-apps ## Install everything (infrastructure + apps)
	@echo "🎉 Full stack installed successfully!"

##@ Updates

upgrade-admin: ## Upgrade admin backend
	@echo "🔄 Upgrading ONTU Schedule Bot Admin..."
	helm upgrade ontu-schedule-bot-admin apps/ontu-schedule-bot-admin \
		-f environments/production/ontu-schedule-bot-admin.yaml \
		-n $(NAMESPACE)
	@echo "✅ Admin backend upgraded"

upgrade-bot: ## Upgrade bot client
	@echo "🔄 Upgrading ONTU Schedule Bot..."
	helm upgrade ontu-schedule-bot apps/ontu-schedule-bot \
		-f environments/production/ontu-schedule-bot.yaml \
		-n $(NAMESPACE)
	@echo "✅ Bot client upgraded"

upgrade-postgresql: ## Upgrade PostgreSQL
	@echo "🔄 Upgrading PostgreSQL..."
	helm upgrade postgresql infrastructure/postgresql \
		-f environments/production/postgresql.yaml \
		-n $(NAMESPACE)
	@echo "✅ PostgreSQL upgraded"

upgrade-dragonfly: ## Upgrade Dragonfly
	@echo "🔄 Upgrading Dragonfly..."
	helm upgrade dragonfly infrastructure/dragonfly \
		-f environments/production/dragonfly.yaml \
		-n $(NAMESPACE)
	@echo "✅ Dragonfly upgraded"

##@ Uninstall

uninstall-admin: ## Uninstall admin backend
	@echo "🗑️  Uninstalling admin backend..."
	helm uninstall ontu-schedule-bot-admin -n $(NAMESPACE)
	@echo "✅ Admin backend uninstalled"

uninstall-bot: ## Uninstall bot client
	@echo "🗑️  Uninstalling bot client..."
	helm uninstall ontu-schedule-bot -n $(NAMESPACE)
	@echo "✅ Bot client uninstalled"

uninstall-example: ## Uninstall example NGINX
	@echo "🗑️  Uninstalling example NGINX..."
	helm uninstall example-nginx -n $(NAMESPACE)
	@echo "✅ Example NGINX uninstalled"

uninstall-postgresql: ## Uninstall PostgreSQL
	@echo "🗑️  Uninstalling PostgreSQL..."
	helm uninstall postgresql -n $(NAMESPACE)
	@echo "✅ PostgreSQL uninstalled"

uninstall-dragonfly: ## Uninstall Dragonfly
	@echo "🗑️  Uninstalling Dragonfly..."
	helm uninstall dragonfly -n $(NAMESPACE)
	@echo "✅ Dragonfly uninstalled"

uninstall-sealed-secrets: ## Uninstall Sealed Secrets controller
	@echo "🗑️  Uninstalling Sealed Secrets controller..."
	helm uninstall sealed-secrets -n kube-system
	@echo "✅ Sealed Secrets controller uninstalled"

uninstall-all: uninstall-bot uninstall-admin uninstall-example uninstall-dragonfly uninstall-postgresql ## Uninstall all applications and infrastructure
	@echo "✅ All components uninstalled"
	@echo "⚠️  Note: PVCs are not deleted. Run 'make clean-pvcs' to delete them."

##@ Monitoring

status: ## Show status of all components
	@echo "📊 Cluster Status"
	@echo "════════════════════════════════════════"
	@echo "\n🎯 Pods:"
	@kubectl get pods -n $(NAMESPACE)
	@echo "\n🔌 Services:"
	@kubectl get svc -n $(NAMESPACE)
	@echo "\n🌐 Ingress:"
	@kubectl get ingress -n $(NAMESPACE)
	@echo "\n💾 PVCs:"
	@kubectl get pvc -n $(NAMESPACE)
	@echo "\n🔐 Sealed Secrets:"
	@kubectl get sealedsecrets -n $(NAMESPACE)
	@echo "\n🔑 Secrets:"
	@kubectl get secrets -n $(NAMESPACE) | grep -v "default-token"

verify: ## Verify all components are running
	@echo "✅ Verification Report"
	@echo "════════════════════════════════════════"
	@echo "\n🔍 Checking PostgreSQL..."
	@kubectl get pod postgresql-0 -n $(NAMESPACE) -o jsonpath='{.status.phase}' | grep -q "Running" && echo "  ✓ PostgreSQL is running" || echo "  ✗ PostgreSQL is NOT running"
	@echo "\n🔍 Checking Dragonfly..."
	@kubectl get pod dragonfly-0 -n $(NAMESPACE) -o jsonpath='{.status.phase}' | grep -q "Running" && echo "  ✓ Dragonfly is running" || echo "  ✗ Dragonfly is NOT running"
	@echo "\n🔍 Checking Admin Backend..."
	@kubectl get deployment ontu-schedule-bot-admin -n $(NAMESPACE) -o jsonpath='{.status.availableReplicas}' | grep -q "[1-9]" && echo "  ✓ Admin Backend is running" || echo "  ✗ Admin Backend is NOT running"
	@echo "\n🔍 Checking Bot Client..."
	@kubectl get deployment ontu-schedule-bot -n $(NAMESPACE) -o jsonpath='{.status.availableReplicas}' | grep -q "[1-9]" && echo "  ✓ Bot Client is running" || echo "  ✗ Bot Client is NOT running"

logs-admin: ## Show admin backend logs
	@kubectl logs -l app.kubernetes.io/name=ontu-schedule-bot-admin -n $(NAMESPACE) --tail=100 -f

logs-bot: ## Show bot client logs
	@kubectl logs -l app.kubernetes.io/name=ontu-schedule-bot -n $(NAMESPACE) --tail=100 -f

logs-postgresql: ## Show PostgreSQL logs
	@kubectl logs postgresql-0 -n $(NAMESPACE) --tail=100 -f

logs-dragonfly: ## Show Dragonfly logs
	@kubectl logs dragonfly-0 -n $(NAMESPACE) --tail=100 -f

logs-sealed-secrets: ## Show Sealed Secrets controller logs
	@kubectl logs -l app.kubernetes.io/name=sealed-secrets -n kube-system --tail=100 -f

events: ## Show recent cluster events
	@kubectl get events -n $(NAMESPACE) --sort-by='.lastTimestamp'

##@ Port Forwarding

forward-admin: ## Forward admin backend port (8080)
	@echo "🔌 Port forwarding admin backend to localhost:8080..."
	@echo "   Access at: http://localhost:8080"
	@kubectl port-forward -n $(NAMESPACE) svc/ontu-schedule-bot-admin 8080:8080

forward-postgresql: ## Forward PostgreSQL port (5432)
	@echo "🔌 Port forwarding PostgreSQL to localhost:5432..."
	@echo "   Connect with: psql -h localhost -U postgres -d ontu_schedule"
	@kubectl port-forward -n $(NAMESPACE) pod/postgresql-0 5432:5432

forward-dragonfly: ## Forward Dragonfly port (6379)
	@echo "🔌 Port forwarding Dragonfly to localhost:6379..."
	@echo "   Connect with: redis-cli -p 6379"
	@kubectl port-forward -n $(NAMESPACE) pod/dragonfly-0 6379:6379

forward-example: ## Forward example NGINX port (8081)
	@echo "🔌 Port forwarding example NGINX to localhost:8081..."
	@echo "   Access at: http://localhost:8081"
	@kubectl port-forward -n $(NAMESPACE) svc/example-nginx 8081:80

##@ Secrets Management

seal-secret: ## Seal a secret file (usage: make seal-secret FILE=secret.yaml)
	@if [ -z "$(FILE)" ]; then \
		echo "❌ Error: FILE parameter is required"; \
		echo "   Usage: make seal-secret FILE=secret.yaml"; \
		exit 1; \
	fi
	@if [ ! -f "$(FILE)" ]; then \
		echo "❌ Error: File $(FILE) not found"; \
		exit 1; \
	fi
	@echo "🔐 Sealing secret from $(FILE)..."
	@kubeseal -f $(FILE) -w $(FILE:.yaml=-sealed.yaml)
	@echo "✅ Sealed secret created: $(FILE:.yaml=-sealed.yaml)"
	@echo "⚠️  Remember to delete the unsealed file: rm $(FILE)"

create-postgresql-secret: ## Create and seal PostgreSQL secret
	@echo "🔐 Creating PostgreSQL secret..."
	@kubectl create secret generic postgresql \
		--from-literal=username=postgres \
		--from-literal=password=$$(openssl rand -base64 32) \
		--from-literal=database=ontu_schedule \
		--dry-run=client -o yaml | kubeseal -o yaml > postgresql-sealed.yaml
	@echo "✅ PostgreSQL sealed secret created: postgresql-sealed.yaml"
	@echo "📝 Apply with: kubectl apply -f postgresql-sealed.yaml"

create-dragonfly-secret: ## Create and seal Dragonfly secret
	@echo "🔐 Creating Dragonfly secret..."
	@kubectl create secret generic dragonfly \
		--from-literal=password=$$(openssl rand -base64 32) \
		--dry-run=client -o yaml | kubeseal -o yaml > dragonfly-sealed.yaml
	@echo "✅ Dragonfly sealed secret created: dragonfly-sealed.yaml"
	@echo "📝 Apply with: kubectl apply -f dragonfly-sealed.yaml"

create-bot-token-secret: ## Create and seal bot token secret (usage: make create-bot-token-secret TOKEN=your-token)
	@if [ -z "$(TOKEN)" ]; then \
		echo "❌ Error: TOKEN parameter is required"; \
		echo "   Usage: make create-bot-token-secret TOKEN=your-bot-token"; \
		exit 1; \
	fi
	@echo "🔐 Creating bot token secret..."
	@kubectl create secret generic ontu-schedule-bot-token \
		--from-literal=token=$(TOKEN) \
		--dry-run=client -o yaml | kubeseal -o yaml > bot-token-sealed.yaml
	@echo "✅ Bot token sealed secret created: bot-token-sealed.yaml"
	@echo "📝 Apply with: kubectl apply -f bot-token-sealed.yaml"

##@ Backup & Maintenance

backup-postgresql: ## Backup PostgreSQL database
	@echo "💾 Backing up PostgreSQL database..."
	@kubectl exec postgresql-0 -n $(NAMESPACE) -- pg_dump -U postgres ontu_schedule > backup-$$(date +%Y%m%d-%H%M%S).sql
	@echo "✅ Backup completed: backup-$$(date +%Y%m%d-%H%M%S).sql"

clean-pvcs: ## Delete all PVCs (WARNING: deletes data!)
	@echo "⚠️  WARNING: This will delete all PVCs and their data!"
	@echo "Press Ctrl+C to cancel, or wait 5 seconds to continue..."
	@sleep 5
	@echo "🗑️  Deleting PVCs..."
	@kubectl delete pvc --all -n $(NAMESPACE)
	@echo "✅ PVCs deleted"

clean: ## Remove generated files
	@echo "🧹 Cleaning generated files..."
	@rm -f pub-cert.pem
	@rm -f *-sealed.yaml
	@rm -f backup-*.sql
	@echo "✅ Cleanup completed"

##@ Testing

test-postgresql: ## Test PostgreSQL connection
	@echo "🧪 Testing PostgreSQL connection..."
	@kubectl run -it --rm psql-test --image=postgres:15-alpine --restart=Never -n $(NAMESPACE) -- \
		psql -h postgresql -U postgres -d ontu_schedule -c "SELECT version();"

test-dragonfly: ## Test Dragonfly connection
	@echo "🧪 Testing Dragonfly connection..."
	@kubectl run -it --rm redis-test --image=redis:alpine --restart=Never -n $(NAMESPACE) -- \
		redis-cli -h dragonfly ping

test-admin-health: ## Test admin backend health endpoint
	@echo "🧪 Testing admin backend health..."
	@kubectl run -it --rm curl-test --image=curlimages/curl:latest --restart=Never -n $(NAMESPACE) -- \
		curl -s http://ontu-schedule-bot-admin:8080/health/ready

##@ Development

template-admin: ## Show rendered admin backend templates
	@helm template ontu-schedule-bot-admin apps/ontu-schedule-bot-admin \
		-f environments/production/ontu-schedule-bot-admin.yaml

template-bot: ## Show rendered bot client templates
	@helm template ontu-schedule-bot apps/ontu-schedule-bot \
		-f environments/production/ontu-schedule-bot.yaml

template-postgresql: ## Show rendered PostgreSQL templates
	@helm template postgresql infrastructure/postgresql \
		-f environments/production/postgresql.yaml

diff-admin: ## Show diff for admin backend upgrade
	@helm diff upgrade ontu-schedule-bot-admin apps/ontu-schedule-bot-admin \
		-f environments/production/ontu-schedule-bot-admin.yaml \
		-n $(NAMESPACE) || echo "Install helm-diff plugin: helm plugin install https://github.com/databus23/helm-diff"

##@ Information

info: ## Show cluster and kubectl information
	@echo "ℹ️  Cluster Information"
	@echo "════════════════════════════════════════"
	@kubectl cluster-info
	@echo "\n📍 Current Context:"
	@kubectl config current-context
	@echo "\n🏷️  Namespace: $(NAMESPACE)"
	@echo "\n📊 Node Information:"
	@kubectl get nodes
	@echo "\n📦 Helm Releases:"
	@helm list -n $(NAMESPACE)
