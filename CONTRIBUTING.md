# Contributing Guide

Thank you for your interest in improving the ONTU Schedule GitOps repository!

## 🎯 Repository Goals

This repository aims to provide:
- Production-ready Helm charts
- Secure secret management with GitOps
- Comprehensive documentation
- Best practices examples
- Educational resources

## 📋 Before You Start

1. Read the documentation:
   - [README.md](README.md)
   - [QUICKSTART.md](QUICKSTART.md)
   - [docs/architecture.md](docs/architecture.md)

2. Understand the structure:
   - `apps/` - Application charts
   - `infrastructure/` - Infrastructure charts
   - `environments/` - Environment configs
   - `docs/` - Documentation

3. Set up your development environment:
   - Kubernetes cluster (minikube, kind, etc.)
   - Helm 3.x
   - kubectl
   - kubeseal (for secrets)

## 🔧 Making Changes

### Adding a New Application Chart

1. Create chart directory:
```bash
mkdir -p apps/my-new-app/templates
```

2. Create required files:
```bash
touch apps/my-new-app/Chart.yaml
touch apps/my-new-app/values.yaml
touch apps/my-new-app/README.md
touch apps/my-new-app/templates/_helpers.tpl
```

3. Follow the structure from existing charts
4. Add comprehensive comments
5. Include usage examples in README
6. Create environment-specific values in `environments/production/`

### Adding Documentation

1. Use clear headings and structure
2. Include code examples
3. Add diagrams where helpful
4. Link to related documentation
5. Keep it practical and actionable

### Updating Existing Charts

1. Maintain backward compatibility when possible
2. Update version in Chart.yaml
3. Document changes in README
4. Test thoroughly
5. Update examples if needed

## ✅ Quality Standards

### Helm Charts

- [ ] Chart.yaml has correct metadata
- [ ] values.yaml has comments explaining options
- [ ] Templates have inline comments
- [ ] _helpers.tpl includes reusable functions
- [ ] README.md explains usage
- [ ] Follows Helm best practices
- [ ] Uses proper labels
- [ ] Includes resource limits
- [ ] Has health checks
- [ ] Security context defined

### Documentation

- [ ] Clear and concise
- [ ] Includes examples
- [ ] No typos or grammar errors
- [ ] Properly formatted markdown
- [ ] Links work correctly
- [ ] Code blocks have syntax highlighting
- [ ] Explains "why" not just "what"

### Security

- [ ] No secrets in plain text
- [ ] Uses SealedSecrets or external secrets
- [ ] Non-root security contexts
- [ ] Minimal container capabilities
- [ ] TLS/HTTPS where applicable
- [ ] RBAC properly configured

## 🧪 Testing

### Test Helm Charts

```bash
# Lint the chart
helm lint apps/my-app

# Template without installing
helm template my-app apps/my-app -f environments/production/my-app.yaml

# Dry-run install
helm install my-app apps/my-app --dry-run --debug

# Install in test namespace
kubectl create namespace test
helm install my-app apps/my-app -n test -f environments/production/my-app.yaml

# Verify
kubectl get all -n test
kubectl get pods -n test

# Cleanup
helm uninstall my-app -n test
kubectl delete namespace test
```

### Test Documentation

```bash
# Check markdown syntax
# Use a linter or VS Code extension

# Test commands in documentation
# Run through the examples to ensure they work

# Verify links
# Click all links to ensure they're not broken
```

## 📝 Documentation Style Guide

### Markdown Formatting

- Use headers hierarchically (# → ## → ###)
- Use code blocks with language identifiers
- Use tables for structured data
- Use lists for steps or items
- Use bold for emphasis, not italics
- Use emoji sparingly for visual navigation

### Code Examples

```yaml
# ✅ Good - includes comments
apiVersion: v1
kind: Service
metadata:
  name: my-service  # Service name
spec:
  selector:
    app: my-app     # Selector for pods
  ports:
    - port: 80      # Service port
```

```yaml
# ❌ Avoid - no comments
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  selector:
    app: my-app
  ports:
    - port: 80
```

### Commands

Always include:
- What the command does
- Expected output
- Context (what directory, prerequisites)

```bash
# Good example

# Install PostgreSQL in the default namespace
helm install postgresql infrastructure/postgresql \
  -f environments/production/postgresql.yaml

# Expected output:
# NAME: postgresql
# STATUS: deployed
# ...
```

## 🎨 Coding Style

### Helm Templates

1. **Use helpers for repeated logic**
```yaml
{{- define "app.labels" -}}
app.kubernetes.io/name: {{ include "app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

2. **Include comments for complex logic**
```yaml
{{- if and .Values.ingress.enabled .Values.ingress.tls }}
# TLS is enabled, configure certificates
tls:
  {{- range .Values.ingress.tls }}
  - secretName: {{ .secretName }}
    hosts:
      {{- range .hosts }}
      - {{ . | quote }}
      {{- end }}
  {{- end }}
{{- end }}
```

3. **Use proper indentation**
```yaml
# Correct
spec:
  template:
    spec:
      containers:
        - name: app

# Incorrect
spec:
template:
spec:
containers:
- name: app
```

### Values Files

1. **Group related values**
```yaml
# Good - grouped by component
database:
  host: postgresql
  port: 5432
  name: mydb

cache:
  host: redis
  port: 6379
```

2. **Provide defaults and examples**
```yaml
# Good - has default and comment
ingress:
  # Enable ingress resource
  enabled: true
  # Ingress class name (e.g., nginx, traefik)
  className: "nginx"
```

3. **Use descriptive names**
```yaml
# Good
autoscaling:
  targetCPUUtilizationPercentage: 80

# Avoid
autoscaling:
  cpu: 80
```

## 🔄 Workflow

### For New Features

1. Create a branch: `git checkout -b feature/my-feature`
2. Make your changes
3. Test thoroughly
4. Update documentation
5. Commit with clear messages
6. Create pull request (if applicable)

### Commit Messages

Use clear, descriptive commit messages:

```
✅ Good:
- Add example application with secrets management
- Update PostgreSQL to version 15.4
- Fix ingress TLS configuration
- Improve sealed secrets documentation

❌ Avoid:
- fix bug
- update
- changes
- test
```

## 📦 Release Process

When releasing a new version:

1. Update Chart.yaml versions
2. Update CHANGELOG (if exists)
3. Tag the release: `git tag -a v1.0.0 -m "Release v1.0.0"`
4. Update documentation with any breaking changes

## 🐛 Reporting Issues

When reporting issues:

1. Check existing issues first
2. Provide clear description
3. Include steps to reproduce
4. Share error messages/logs
5. Specify versions (Kubernetes, Helm, etc.)
6. Include relevant configuration

## 💡 Suggesting Enhancements

For suggestions:

1. Describe the use case
2. Explain current limitations
3. Propose solution
4. Consider alternatives
5. Think about backward compatibility

## 🎓 Learning Resources

### Kubernetes
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)

### Helm
- [Helm Documentation](https://helm.sh/docs/)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Helm Template Guide](https://helm.sh/docs/chart_template_guide/)

### GitOps
- [GitOps Principles](https://www.gitops.tech/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Flux Documentation](https://fluxcd.io/docs/)

### Sealed Secrets
- [Sealed Secrets GitHub](https://github.com/bitnami-labs/sealed-secrets)
- [Sealed Secrets Guide](docs/sealed-secrets-guide.md)

## 📧 Contact

For questions or discussions:
- Check documentation first
- Review existing issues
- Create new issue for bugs/features

## 🙏 Thank You

Your contributions help make this repository better for everyone!

Key principles:
- **Quality over quantity**
- **Documentation is code**
- **Security first**
- **User experience matters**
- **Learn by example**

Happy contributing! 🚀
