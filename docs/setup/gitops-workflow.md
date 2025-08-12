# GitOps Workflow with Backstage and Flux

This document explains how Backstage templates integrate with Flux for GitOps-based deployments.

## Overview

The Open Service Portal uses a GitOps workflow where:
1. Developers use Backstage UI to create services
2. Backstage creates Git repositories with Kubernetes manifests
3. Flux monitors these repositories and deploys to Kubernetes
4. All changes go through Git (audit trail, rollback capability)

## Architecture

```
Developer → Backstage UI → GitHub Repo → Flux → Crossplane → Kubernetes
```

## Template Types

### 1. GitOps Templates (`template-*-service`)
- Creates a new GitHub repository
- Repository contains Crossplane manifests
- Flux automatically deploys from the repo
- Best for: Production services, persistent infrastructure

### 2. Direct Templates (`template-*-experiment`)
- Applies resources directly to cluster
- No Git repository created
- Immediate deployment
- Best for: Experiments, temporary resources, development

### 3. Hybrid Templates (`template-*-hybrid`)
- Creates Git repository for GitOps
- Optionally applies immediately to cluster
- User chooses deployment method
- Best for: Flexible workflows

## Setting Up GitOps

### 1. Flux Installation

Flux is installed automatically by the setup script if a GitHub token is available:

```bash
./scripts/setup-rancher-k8s.sh
```

### 2. Repository Labels

Flux discovers repositories to monitor using GitHub topics/labels:

- `flux-managed` - Monitored by Flux for deployments
- `backstage` - Created by Backstage

### 3. Auto-Discovery Configuration

The setup script creates a GitRepository resource that monitors the organization:

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: backstage-services
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/open-service-portal
  ref:
    branch: main
```

## Creating a GitOps Template

### Example: ConfigMap Service Template

1. **Create template repository**: `template-configmap-service`

2. **Define template.yaml**:
```yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: template-configmap-service
  title: ConfigMap Service (GitOps)
spec:
  steps:
    - id: fetch
      action: fetch:template
      input:
        url: ./content
    - id: publish
      action: publish:github
      input:
        repoUrl: ${{ parameters.repoUrl }}
        topics: ['flux-managed', 'backstage']
```

3. **Create content structure**:
```
content/
├── catalog-info.yaml        # Backstage catalog entry
├── crossplane/
│   ├── namespace.yaml       # Namespace definition
│   └── configmap.yaml       # ConfigMap via Crossplane
└── kustomization.yaml       # Flux Kustomization
```

4. **ConfigMap manifest** (`content/crossplane/configmap.yaml`):
```yaml
apiVersion: kubernetes.crossplane.io/v1alpha2
kind: Object
metadata:
  name: ${{ values.name }}-configmap
spec:
  forProvider:
    manifest:
      apiVersion: v1
      kind: ConfigMap
      metadata:
        name: ${{ values.name }}
        namespace: ${{ values.namespace }}
      data:
        config: |
          ${{ values.config }}
```

## Deployment Flow

### GitOps Deployment

1. **Developer Action**: Uses Backstage template
2. **Backstage Creates**: GitHub repository with manifests
3. **Flux Detects**: New repository with `flux-managed` label
4. **Flux Syncs**: Applies manifests to cluster
5. **Crossplane Reconciles**: Creates actual Kubernetes resources

### Direct Deployment

1. **Developer Action**: Uses Backstage template
2. **Backstage Applies**: Directly to cluster via `kubernetes:apply`
3. **Immediate Result**: Resources created instantly

## Monitoring Deployments

### Check Flux Status
```bash
# View all GitRepositories
flux get sources git

# View Kustomizations
flux get kustomizations

# Check sync status
flux get all

# View events
kubectl events -n flux-system
```

### Check Crossplane Resources
```bash
# View Crossplane objects
kubectl get objects

# Check specific resource
kubectl describe object <name>
```

### Debug Failed Deployments
```bash
# Check Flux logs
flux logs --follow

# Check specific Kustomization
flux get kustomization <name> -n flux-system

# Force reconciliation
flux reconcile source git backstage-services
```

## Best Practices

### 1. Use GitOps for Production
- All production services should use GitOps templates
- Provides audit trail and rollback capability
- Enables multi-environment deployments

### 2. Label Repositories Correctly
- Always include `flux-managed` topic for GitOps repos
- Use additional labels for organization (e.g., `team-platform`)

### 3. Structure Manifests Properly
```
repo/
├── base/              # Base configurations
├── overlays/          # Environment-specific configs
│   ├── dev/
│   ├── staging/
│   └── production/
└── kustomization.yaml
```

### 4. Version Control Everything
- Commit all changes to Git
- Use meaningful commit messages
- Tag releases for production deployments

### 5. Monitor Flux Health
```bash
# Set up alerts for Flux
kubectl apply -f - <<EOF
apiVersion: notification.toolkit.fluxcd.io/v1beta3
kind: Alert
metadata:
  name: flux-system
  namespace: flux-system
spec:
  providerRef:
    name: slack
  eventSeverity: error
  eventSources:
    - kind: Kustomization
      name: '*'
    - kind: GitRepository
      name: '*'
EOF
```

## Rollback Procedures

### Git Revert
```bash
# Revert last commit
git revert HEAD
git push

# Flux will automatically sync the revert
```

### Flux Suspend/Resume
```bash
# Temporarily stop syncing
flux suspend kustomization <name>

# Fix issues, then resume
flux resume kustomization <name>
```

### Manual Override
```bash
# In emergency, apply manual fix
kubectl apply -f emergency-fix.yaml

# Then update Git to match
```

## Security Considerations

1. **Token Permissions**: Use minimal GitHub token scopes
2. **Secret Management**: Use Sealed Secrets or SOPS for sensitive data
3. **RBAC**: Limit Flux service account permissions
4. **Image Scanning**: Integrate with container scanning tools
5. **Policy Enforcement**: Use OPA Gatekeeper or Kyverno

## Troubleshooting

### Repository Not Detected
- Verify `flux-managed` topic is set
- Check Flux has access to the repository
- Verify GitRepository resource exists

### Sync Failures
- Check manifest syntax: `kubectl apply --dry-run=client -f manifest.yaml`
- Verify Crossplane providers are healthy
- Check resource quotas and limits

### Slow Deployments
- Adjust Flux interval: default is 1m
- Check Crossplane reconciliation frequency
- Monitor cluster resource usage

## Next Steps

1. Create your first GitOps template
2. Set up environment-specific overlays
3. Configure alerts and monitoring
4. Implement progressive delivery with Flagger