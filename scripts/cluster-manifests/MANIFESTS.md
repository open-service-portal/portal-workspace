# Cluster Manifests Documentation

This directory contains all the manifests installed by `setup-cluster.sh` to configure the Kubernetes cluster for the Open Service Portal.

## Files Overview

### Crossplane Core
- **`crossplane-provider-kubernetes.yaml`** - Provider for managing Kubernetes resources (ConfigMaps, Services, etc.)
- **`crossplane-provider-kubernetes-config.yaml`** - Auth configuration for the Kubernetes provider
- **`crossplane-provider-helm.yaml`** - Provider for deploying Helm charts (PostgreSQL, Redis, etc.)
- **`crossplane-provider-helm-config.yaml`** - Auth configuration for the Helm provider
- **`crossplane-functions.yaml`** - Composition pipeline functions for resource transformation
- **`environment-configs.yaml`** - Platform-wide shared configuration

### GitOps
- **`flux-catalog.yaml`** - Flux configuration to watch and sync the template catalog

## How Functions Work with Providers

The composition functions (go-templating, patch-and-transform, etc.) are **provider-agnostic**. They work in the pipeline to:
1. Generate or transform resource specifications
2. Pass the resources to the appropriate provider
3. The provider then creates the actual resources

### Example: Using provider-kubernetes with functions
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
          kind: Object  # This will be handled by provider-kubernetes
          spec:
            forProvider:
              manifest:
                apiVersion: v1
                kind: Service
                # ...
```

### Example: Using provider-helm with functions
```yaml
pipeline:
  - step: deploy-postgresql
    functionRef:
      name: function-patch-and-transform
    input:
      apiVersion: pt.crossplane.io/v1
      kind: Resources
      resources:
        - name: postgresql
          base:
            apiVersion: helm.crossplane.io/v1beta1
            kind: Release  # This will be handled by provider-helm
            spec:
              forProvider:
                chart:
                  name: postgresql
                  repository: https://charts.bitnami.com/bitnami
```

## No Additional Functions Needed

The existing functions are sufficient because:
- **Functions transform data** - They manipulate YAML/JSON specifications
- **Providers create resources** - They take the specs and create actual resources
- **They're complementary** - Functions prepare the "recipe", providers do the "cooking"

## Restaurant Analogy
- **Functions** = Recipe techniques (chopping, mixing, seasoning)
- **Providers** = Cooking equipment (ovens, grills, fryers)
- You can use the same techniques with different equipment!