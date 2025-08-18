# Crossplane v2 Architecture

This document describes our Crossplane v2 implementation using namespaced XRs and the catalog pattern.

## Key Design Decisions

### 1. Namespaced XRs (No Claims)
We use Crossplane v2's namespaced XRs feature, which means:
- Developers create `XDNSRecord` resources directly (not `DNSRecord` claims)
- XRs exist in namespaces, providing natural isolation
- Simpler mental model - one resource type instead of two
- Standard Kubernetes RBAC applies

### 2. Catalog Pattern with Flux
- Central `catalog` repository lists all approved templates
- Each template lives in its own `template-*` repository
- Flux watches the catalog and syncs templates automatically
- Manual approval via PRs to the catalog repository

### 3. Platform-Wide Resources
Installed once by `setup-cluster.sh`:
- **Composition Functions**: Shared transformation logic
- **Environment Configs**: Platform-wide settings (DNS zones, defaults)
- **Providers**: Infrastructure providers (provider-kubernetes, etc.)

Note: EnvironmentConfig CRD is included with Crossplane v2.0 using API version `v1alpha1`

### 4. Pipeline Mode Compositions
All compositions use Pipeline mode with functions:
- `function-go-templating`: Dynamic resource generation
- `function-environment-configs`: Access shared configuration
- `function-auto-ready`: Automatic readiness detection
- `function-patch-and-transform`: Traditional patching when needed

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                     Platform Team                         │
│                                                           │
│  manages:                                                 │
│  - catalog repo (template registry)                      │
│  - environment-configs (platform settings)               │
│  - composition functions (installed globally)            │
└───────────────┬─────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────┐
│                  Kubernetes Cluster                       │
│                                                           │
│  ┌──────────────────────────────────────────────┐       │
│  │            Platform-Wide Resources            │       │
│  │                                               │       │
│  │  • Environment Configs (dns-config, etc.)    │       │
│  │  • Composition Functions (go-templating...)  │       │
│  │  • Providers (provider-kubernetes...)        │       │
│  └──────────────────────────────────────────────┘       │
│                                                           │
│  ┌──────────────────────────────────────────────┐       │
│  │              Template Resources               │       │
│  │           (from template-* repos)             │       │
│  │                                               │       │
│  │  • XRDs (define APIs)                        │       │
│  │  • Compositions (implement APIs)             │       │
│  │  • RBAC (template-specific permissions)      │       │
│  └──────────────────────────────────────────────┘       │
│                                                           │
└───────────────┬─────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────┐
│                    Developer Teams                        │
│                                                           │
│  create XRs directly in their namespaces:                │
│                                                           │
│  apiVersion: platform.io/v1alpha1                        │
│  kind: XDNSRecord  # Direct XR, no claim!                │
│  metadata:                                               │
│    name: my-app                                          │
│    namespace: my-team  # Namespaced!                     │
│  spec:                                                   │
│    type: A                                               │
│    name: my-app                                          │
│    value: "192.168.1.100"                               │
└─────────────────────────────────────────────────────────┘
```

## File Structure

```
portal-workspace/
├── scripts/
│   ├── setup-cluster.sh                 # One-command cluster setup
│   └── cluster-manifests/
│       ├── crossplane-functions.yaml    # Global functions
│       ├── environment-configs.yaml     # Platform configs
│       ├── provider-kubernetes.yaml     # Provider setup
│       └── flux-catalog.yaml           # Flux catalog watcher
│
├── catalog/                            # Template registry
│   ├── kustomization.yaml
│   └── templates/
│       └── template-*.yaml             # Template references
│
└── template-dns-record/                # Example template
    ├── xrd.yaml                        # API definition (v2, namespaced)
    ├── composition.yaml                # Implementation (Pipeline mode)
    ├── rbac.yaml                       # Permissions
    └── examples/
        └── xr.yaml                     # Usage examples
```

## Key Differences from v1

| Aspect | Crossplane v1 | Crossplane v2 |
|--------|---------------|---------------|
| XRD API Version | `apiextensions.crossplane.io/v1` | `apiextensions.crossplane.io/v2` |
| XR Scope | Cluster-scoped | Namespaced by default |
| User Resource | Claim + XR (2 resources) | XR only (1 resource) |
| Composition Mode | Resources mode | Pipeline mode with functions |
| Configuration | Inline in composition | Environment configs |
| Machinery Fields | Mixed with user fields | Under `spec.crossplane` |

## Benefits

1. **Simplicity**: Developers work with one resource type (XR) instead of claims
2. **Namespace Isolation**: Natural Kubernetes namespace boundaries
3. **GitOps Native**: Everything managed through Git
4. **Reusable Functions**: Shared logic across all templates
5. **Central Configuration**: Platform settings in one place
6. **Modern Crossplane**: Using latest v2 features and best practices

## Getting Started

1. **Setup Cluster**: Run `./scripts/setup-cluster.sh`
2. **Create Template**: Follow pattern in `template-dns-record/`
3. **Register Template**: Add to `catalog/templates/`
4. **Use Template**: Create XRs directly in your namespace

## Further Reading

- [Crossplane v2 Documentation](https://docs.crossplane.io/latest/)
- [Namespaced Composite Resources](https://docs.crossplane.io/latest/concepts/composite-resources/)
- [Composition Functions](https://docs.crossplane.io/latest/concepts/composition-functions/)
- [Environment Configurations](https://docs.crossplane.io/latest/concepts/environment-configs/)