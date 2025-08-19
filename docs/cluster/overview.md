# Crossplane Platform Overview

This document provides a high-level overview of our Crossplane v2 platform architecture.

## Key Design Principles

### 1. Namespaced XRs (Crossplane v2)
- Developers create resources directly (e.g., `WhoAmIApp`, `DNSRecord`)
- Resources exist in namespaces with natural RBAC isolation
- No separate claims needed - simpler mental model

### 2. GitOps with Catalog Pattern
- Central catalog repository lists approved templates
- Each template in its own repository
- Flux automatically syncs templates from catalog
- Manual approval via PRs to catalog

### 3. Pipeline Mode Compositions
- All templates use Pipeline mode with functions
- Shared transformation logic via composition functions
- Platform-wide configuration via EnvironmentConfigs

## Architecture Components

```
┌─────────────────────────────────────────────────────────┐
│                     Platform Team                         │
│  manages: catalog, environment configs, functions         │
└───────────────┬─────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────┐
│                  Kubernetes Cluster                       │
│                                                           │
│  Platform Resources (setup-cluster.sh):                  │
│  • Providers (kubernetes, helm, cloudflare)              │
│  • Functions (go-templating, environment-configs, etc.)  │
│  • Environment Configs (dns-config, etc.)                │
│                                                           │
│  Template Resources (from catalog):                      │
│  • XRDs - Define APIs (WhoAmIApp, DNSRecord)            │
│  • Compositions - Implement APIs                         │
└───────────────┬─────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────┐
│                    Developer Teams                        │
│  Create resources directly in their namespaces:          │
│                                                           │
│  kind: WhoAmIApp                                         │
│  metadata:                                               │
│    namespace: my-team  # Namespaced!                     │
└─────────────────────────────────────────────────────────┘
```

## Quick Comparison: v1 vs v2

| Aspect | Crossplane v1 | Crossplane v2 |
|--------|---------------|---------------|
| User creates | Claim + XR (2 resources) | XR only (1 resource) |
| Resource scope | Claims namespaced, XRs cluster | XRs namespaced |
| Composition mode | Resources mode | Pipeline mode with functions |
| Configuration | Inline | Environment configs |

## Getting Started

1. **Setup**: Run `./scripts/setup-cluster.sh` - installs all platform components
2. **Configure**: Run `./scripts/config-local.sh` or `config-openportal.sh` for environment
3. **Use**: Create resources directly in your namespace

## Learn More

- [Cluster Setup](./setup.md) - Detailed setup instructions
- [Cluster Configuration](./configuration.md) - Environment-specific settings
- [Catalog Setup](./catalog-setup.md) - Template management and creation
- [Manifests](./manifests.md) - Platform components details

## Restaurant Analogy

To understand the platform using restaurant concepts:

- **Providers** = Kitchen equipment (ovens, grills)
- **Functions** = Recipe techniques (chopping, mixing)
- **Templates** = Menu items (what customers can order)
- **Compositions** = Recipes (how to prepare orders)
- **Environment Configs** = House standards (portion sizes, seasoning)
- **Developer** = Customer (orders from menu)
- **Platform Team** = Head chef (creates menu, sets standards)