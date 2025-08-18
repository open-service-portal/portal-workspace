# Crossplane Template Catalog with Flux

This document describes how we manage Crossplane templates using a central catalog repository with Flux GitOps.

## Architecture Overview

```
┌──────────────────────────────────────────────────────────┐
│                     GitHub Organization                    │
│                                                            │
│  ┌─────────────┐   ┌──────────────────┐                  │
│  │   catalog   │   │ template-dns-    │                  │
│  │    (main)   │   │    record         │                  │
│  └──────┬──────┘   └──────────────────┘                  │
│         │                                                  │
│         │          ┌──────────────────┐                  │
│         │          │ template-postgres-│                  │
│         │          │       db          │                  │
│         │          └──────────────────┘                  │
│         │                                                  │
│         │          ┌──────────────────┐                  │
│         │          │ template-k8s-app │                  │
│         │          └──────────────────┘                  │
└─────────┼──────────────────────────────────────────────────┘
          │
          │ Flux watches catalog
          ▼
┌──────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                      │
│                                                            │
│  ┌──────────────────────────────────────────────┐        │
│  │              flux-system namespace            │        │
│  │                                               │        │
│  │  GitRepository: catalog ──────────────┐      │        │
│  │                                        ▼      │        │
│  │  Kustomization: catalog ──> Creates multiple │        │
│  │                             GitRepositories   │        │
│  │                                               │        │
│  │  GitRepository: template-dns-record          │        │
│  │  GitRepository: template-postgres-db         │        │
│  │  GitRepository: template-k8s-app             │        │
│  └──────────────────────────────────────────────┘        │
│                                                            │
│  ┌──────────────────────────────────────────────┐        │
│  │          crossplane-system namespace          │        │
│  │                                               │        │
│  │  Functions: go-templating, patch-and-transform│        │
│  │            auto-ready, environment-configs    │        │
│  │                                               │        │
│  │  EnvironmentConfig: dns-config (platform-wide)│        │
│  │                                               │        │
│  │  XRD: XDNSRecord (namespaced, v2)            │        │
│  │  Composition: dnsrecord                      │        │
│  │                                               │        │
│  │  XRD: XPostgresDB                            │        │
│  │  Composition: postgres-db                    │        │
│  └──────────────────────────────────────────────┘        │
└──────────────────────────────────────────────────────────┘
```

## How It Works

1. **Central Catalog**: The `catalog` repository acts as a registry
2. **Template Discovery**: Each template is registered in the catalog
3. **Flux Sync**: Flux watches the catalog and creates GitRepository resources
4. **Template Sync**: Each GitRepository syncs its XRDs and Compositions
5. **Ready to Use**: Developers can create XRs directly in their namespaces (Crossplane v2)

### Key Concepts

- **Namespaced XRs**: Crossplane v2 feature where XRs exist in namespaces, no claims needed
- **Pipeline Mode**: Compositions use functions for resource transformation
- **Environment Configs**: Platform-wide shared configuration
- **Composition Functions**: Reusable transformation logic (installed globally)

## Repository Structure

### Catalog Repository
```
catalog/
├── README.md
├── kustomization.yaml          # Main kustomization
├── templates/                  # Template definitions
│   ├── template-dns-record.yaml
│   ├── template-postgres-db.yaml
│   └── template-k8s-app.yaml
└── test-local-flux.yaml        # For testing
```

### Template Repository Structure
```
template-{name}/
├── README.md
├── xrd.yaml                    # Composite Resource Definition (v2, namespaced)
├── composition.yaml            # Implementation (Pipeline mode)
├── rbac.yaml                   # RBAC permissions (if needed)
└── examples/
    └── xr.yaml                 # Example XR (direct creation, no claims)
```

**Note**: EnvironmentConfigs are managed platform-wide in `scripts/cluster-manifests/environment-configs.yaml`

## Platform vs Template Resources

### Platform-Wide Resources (Installed Once)
These are installed by `scripts/setup-cluster.sh`:

| Resource | Location | Purpose |
|----------|----------|---------|
| Crossplane Functions | `scripts/cluster-manifests/crossplane-functions.yaml` | Shared transformation logic |
| Environment Configs | `scripts/cluster-manifests/environment-configs.yaml` | Platform-wide configuration |
| Provider Kubernetes | `scripts/cluster-manifests/provider-kubernetes.yaml` | Kubernetes resource management |
| Flux Catalog Config | `scripts/cluster-manifests/flux-catalog.yaml` | GitOps catalog watching |

### Template-Specific Resources
These are included in each template repository:

| Resource | Purpose |
|----------|---------|
| XRD (`xrd.yaml`) | Defines the API (what users can create) |
| Composition (`composition.yaml`) | Implementation (how resources are created) |
| RBAC (`rbac.yaml`) | Permissions specific to this template |
| Examples (`examples/xr.yaml`) | Usage examples for developers |

## Setting Up a New Template

### Step 1: Create Template Repository

Create a new repository following the naming convention `template-{resource}`:

```bash
# Create repository on GitHub
gh repo create open-service-portal/template-my-resource --public

# Clone and add content
git clone git@github.com:open-service-portal/template-my-resource.git
cd template-my-resource
```

### Step 2: Add XRD and Composition

Create the XRD (the API) using Crossplane v2:
```yaml
# xrd.yaml
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
metadata:
  name: xmyresources.platform.io
spec:
  scope: Namespaced  # v2: XRs are namespaced by default
  group: platform.io
  names:
    kind: XMyResource
    plural: xmyresources
  # No claimNames needed in v2!
  defaultCompositionRef:
    name: myresource
  # ... rest of XRD
```

Create the Composition (the implementation) with Pipeline mode:
```yaml
# composition.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: myresource
spec:
  compositeTypeRef:
    apiVersion: platform.io/v1alpha1
    kind: XMyResource
  mode: Pipeline  # v2: Use Pipeline mode with functions
  pipeline:
    - step: create-resources
      functionRef:
        name: function-go-templating
      # ... rest of Composition
```

### Step 3: Register in Catalog

Create a file in the catalog repository:

```yaml
# catalog/templates/template-my-resource.yaml
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: template-my-resource
  namespace: flux-system
spec:
  interval: 5m
  url: https://github.com/open-service-portal/template-my-resource
  ref:
    branch: main
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: template-my-resource
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: template-my-resource
  path: "./"
  prune: true
  targetNamespace: crossplane-system
```

### Step 4: Update Catalog Kustomization

Add the new template to `catalog/kustomization.yaml`:

```yaml
resources:
  - templates/template-dns-record.yaml
  - templates/template-postgres-db.yaml
  - templates/template-my-resource.yaml  # Add this line
```

### Step 5: Submit PR

Submit a PR to the catalog repository. This provides:
- Review process for new templates
- Validation of naming conventions
- Security review if needed
- Documentation requirements check

## Testing Locally

### Before GitHub Push

Test the template directly:
```bash
# Apply RBAC if needed
kubectl apply -f template-my-resource/rbac.yaml

# Apply XRD and Composition
kubectl apply -f template-my-resource/xrd.yaml
kubectl apply -f template-my-resource/composition.yaml

# Verify environment config exists (should be installed by setup-cluster.sh)
kubectl get environmentconfig

# Test with example XR (no claim needed!)
kubectl apply -f template-my-resource/examples/xr.yaml

# Check resources
kubectl get xrd
kubectl get compositions
kubectl get xmyresource -A  # XRs are namespaced
```

### After GitHub Push

Test the catalog sync:
```bash
# Apply catalog configuration
kubectl apply -f catalog/test-local-flux.yaml

# Check sync status
flux get sources git catalog -n flux-system

# Check if templates are discovered
kubectl get gitrepositories -n flux-system

# Check XRDs
kubectl get xrd
```

## Monitoring and Troubleshooting

### Check Flux Sync Status
```bash
# Overall status
flux get all -n flux-system

# Catalog sync
flux get sources git catalog -n flux-system
flux get kustomizations catalog -n flux-system

# Individual templates
flux get sources git -n flux-system | grep template-
```

### Check Crossplane Resources
```bash
# XRDs (the APIs)
kubectl get xrd

# Compositions (the implementations)
kubectl get compositions

# Functions (transformation logic)
kubectl get functions

# Environment Configs (shared platform config)
kubectl get environmentconfig

# XRs (user resources - namespaced in v2)
kubectl get xdnsrecord,xpostgresdb -A
```

### Common Issues

#### Template Not Syncing
```bash
# Check GitRepository status
kubectl describe gitrepository template-my-resource -n flux-system

# Check Kustomization status
kubectl describe kustomization template-my-resource -n flux-system

# Check logs
flux logs --kind=Kustomization --name=template-my-resource
```

#### XRD Not Installing
```bash
# Check for errors
kubectl get xrd xmyresources.platform.io -o yaml

# Check Crossplane provider
kubectl get providers.pkg.crossplane.io

# Check if functions are installed
kubectl get functions

# Check environment configs
kubectl get environmentconfig
```

## Benefits of This Approach

1. **Central Registry**: Single source of truth for all templates
2. **GitOps Native**: Everything through Git commits
3. **Approval Process**: PRs to catalog provide governance
4. **Independent Repos**: Each template can be owned by different teams
5. **Version Control**: Each template can be independently versioned
6. **Easy Discovery**: Browse catalog to see available templates
7. **Automatic Sync**: New templates available immediately after PR merge
8. **Crossplane v2 Native**: Uses namespaced XRs for better isolation
9. **No Claims Needed**: Developers create XRs directly in their namespaces
10. **Pipeline Mode**: Leverages composition functions for advanced features

## Migrating from Claims to Namespaced XRs (v1 to v2)

### Key Differences

| Aspect | v1 (Claims) | v2 (Namespaced XRs) |
|--------|------------|---------------------|
| API Version | `apiextensions.crossplane.io/v1` | `apiextensions.crossplane.io/v2` |
| XRD Scope | Cluster-scoped with claims | `scope: Namespaced` |
| User Resource | DNSRecord (claim) | XDNSRecord (direct) |
| Namespace | Claim namespace → XR cluster-scoped | XR in namespace directly |
| Complexity | Two resources (XR + Claim) | One resource (XR only) |
| Access Control | Complex RBAC | Standard namespace RBAC |

### Migration Steps

1. **Update XRD**:
   - Change API version to v2
   - Add `scope: Namespaced`
   - Remove `claimNames` section
   - Add `spec.crossplane` field in schema

2. **Update Composition**:
   - Replace `claimRef` with direct namespace references
   - Update labels to use XR metadata

3. **Update User Resources**:
   - Change kind from claim (e.g., DNSRecord) to XR (e.g., XDNSRecord)
   - Add namespace to metadata
   - Move composition selection under `spec.crossplane`

### Example Migration

**Before (v1 with claim):**
```yaml
apiVersion: platform.io/v1alpha1
kind: DNSRecord  # This is a claim
metadata:
  name: my-app
  namespace: default
spec:
  type: A
  name: my-app
  value: "192.168.1.100"
```

**After (v2 namespaced XR):**
```yaml
apiVersion: platform.io/v1alpha1
kind: XDNSRecord  # Direct XR, no claim
metadata:
  name: my-app
  namespace: default  # XR is namespaced
spec:
  type: A
  name: my-app
  value: "192.168.1.100"
  # Optional Crossplane machinery
  crossplane:
    compositionRef:
      name: dnsrecord
```

## Next Steps

1. Push catalog and template-dns-record to GitHub
2. Test with a real cluster
3. Add more templates as needed
4. Consider automation for catalog updates (GitHub Actions)
5. Add template validation in CI/CD
6. Monitor adoption of namespaced XRs pattern
7. Create more templates following the v2 pattern