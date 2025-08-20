# Cluster Manifests Documentation

This document describes the Kubernetes manifests used to set up the Open Service Portal platform infrastructure.

## Overview

The manifests are organized in two directories:
- `scripts/manifests-setup-cluster/` - Infrastructure components (applied by setup-cluster.sh)
- `scripts/manifests-config-openportal/` - Environment configurations (applied by config-openportal.sh)

These manifests configure:
- Crossplane providers for infrastructure management
- Composition functions for resource transformation
- Environment configurations for platform settings
- GitOps integration with Flux

## Manifest Files

### Crossplane Providers

#### provider-kubernetes
- **File**: `crossplane-provider-kubernetes.yaml`
- **Purpose**: Manages Kubernetes resources (ConfigMaps, Services, Deployments)
- **Version**: v0.14.0
- **Config**: `crossplane-provider-kubernetes-config.yaml` - Uses injected identity
- **RBAC**: `crossplane-provider-kubernetes-rbac.yaml` - Grants cluster-admin for namespace creation

#### provider-helm
- **File**: `crossplane-provider-helm.yaml`
- **Purpose**: Deploys Helm charts (PostgreSQL, Redis, applications)
- **Version**: v0.20.0
- **Config**: `crossplane-provider-helm-config.yaml` - Uses injected identity

#### provider-cloudflare
- **File**: `crossplane-provider-cloudflare.yaml`
- **Purpose**: Manages Cloudflare resources (DNS records, zones)
- **Version**: ghcr.io/cdloh/provider-cloudflare:v0.1.0 (Upjet-based)
- **Config**: `crossplane-provider-cloudflare-config.yaml` - References `cloudflare-credentials` secret
- **Note**: Uses zoneIdRef pattern for DNS records

### Composition Functions

**File**: `crossplane-functions.yaml`

Functions transform resource specifications in the composition pipeline:

- **function-go-templating** (v0.4.0) - Go templates for flexible resource generation
- **function-patch-and-transform** (v0.4.0) - Traditional patching and transformation
- **function-auto-ready** (v0.2.0) - Automatically mark resources as ready
- **function-environment-configs** (v0.4.0) - Load shared environment configurations

### Environment Configurations

**Setup Manifests** (`manifests-setup-cluster/`):
- **environment-configs.yaml** - Base defaults for local development
  - dns-config: zone=localhost, provider=mock

**Config Manifests** (`manifests-config-openportal/`):
- **environment-configs.yaml** - Production overrides (uses envsubst)
  - dns-config: zone=${DNS_ZONE}, provider=${DNS_PROVIDER}
  - cloudflare-config: zone_id=${CLOUDFLARE_ZONE_ID}, account_id=${CLOUDFLARE_ACCOUNT_ID}
- **cloudflare-zone-openportal-dev.yaml** - Zone import for openportal.dev

### GitOps Integration

**File**: `flux-catalog.yaml`

Configures Flux to:
- Watch the catalog repository for Crossplane templates
- Automatically sync and apply template updates
- Enable GitOps workflow for infrastructure

## How Functions Work with Providers

Functions and providers work together in a pipeline:

1. **Functions transform data** - Manipulate YAML/JSON specifications
2. **Providers create resources** - Take specs and create actual resources
3. **They're complementary** - Functions prepare the "recipe", providers do the "cooking"

### Example: Using provider-kubernetes with go-templating

```yaml
pipeline:
  - step: create-service
    functionRef:
      name: function-go-templating
    input:
      apiVersion: gotemplating.crossplane.io/v1beta1
      kind: GoTemplate
      source: Inline
      inline:
        template: |
          apiVersion: kubernetes.crossplane.io/v1alpha2
          kind: Object  # Handled by provider-kubernetes
          spec:
            forProvider:
              manifest:
                apiVersion: v1
                kind: Service
                metadata:
                  name: {{ .observed.composite.resource.metadata.name }}
```

### Example: Using provider-helm with go-templating

```yaml
pipeline:
  - step: deploy-postgresql
    functionRef:
      name: function-go-templating
    input:
      apiVersion: gotemplating.crossplane.io/v1beta1
      kind: GoTemplate
      source: Inline
      inline:
        template: |
          apiVersion: helm.crossplane.io/v1beta1
          kind: Release  # Handled by provider-helm
          metadata:
            name: {{ .observed.composite.resource.metadata.name }}-postgresql
          spec:
            forProvider:
              chart:
                name: postgresql
                repository: https://charts.bitnami.com/bitnami
```

## Best Practices

1. **Use go-templating for new compositions** - More modern and flexible than patch-and-transform
2. **Load environment configs** - Use function-environment-configs for shared settings
3. **Keep providers minimal** - Only install providers you actually need
4. **Version pin functions** - Specify exact versions for reproducibility

## Restaurant Analogy

To understand how these components work together:

- **Providers** = Kitchen equipment (ovens, grills, fryers)
- **Functions** = Recipe techniques (chopping, mixing, seasoning)
- **Environment Configs** = House standards (portion sizes, seasoning levels)
- **Flux** = Supply chain automation (automatic restocking)

You use the same techniques (functions) with different equipment (providers) to prepare dishes (resources) according to house standards (configs).

## Related Documentation

- [Platform Overview](./overview.md) - Architecture overview
- [Cluster Setup](./setup.md) - How to set up a Kubernetes cluster
- [Cluster Configuration](./configuration.md) - Environment-specific configuration
- [Template Catalog Setup](./catalog-setup.md) - Template management