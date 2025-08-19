# Template Catalog Setup

This guide explains how to create and manage Crossplane templates using the catalog pattern with Flux GitOps.

## How the Catalog Works

1. **Central Registry**: `catalog` repository lists all approved templates
2. **Template Discovery**: Each template registered as a Flux GitRepository
3. **Automatic Sync**: Flux watches catalog and syncs templates to cluster
4. **Approval Process**: PRs to catalog provide governance

## Creating a New Template

### Step 1: Create Template Repository

```bash
# Create repository on GitHub
gh repo create open-service-portal/template-my-resource --public

# Clone and add content
git clone git@github.com:open-service-portal/template-my-resource.git
cd template-my-resource
```

### Step 2: Add Template Files

Required structure:
```
template-my-resource/
├── README.md
├── xrd.yaml            # API definition
├── composition.yaml    # Implementation
└── examples/
    └── example.yaml    # Usage example
```

**xrd.yaml** - Define the API (Crossplane v2, namespaced):
```yaml
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
metadata:
  name: myresources.platform.io
spec:
  scope: Namespaced  # v2: Resources are namespaced
  group: platform.io
  names:
    kind: MyResource
    plural: myresources
  defaultCompositionRef:
    name: myresource
  versions:
  - name: v1alpha1
    served: true
    referenceable: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              # Your API fields here
              name:
                type: string
              size:
                type: string
                default: "small"
```

**composition.yaml** - Implementation with Pipeline mode:
```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: myresource
spec:
  compositeTypeRef:
    apiVersion: platform.io/v1alpha1
    kind: MyResource
  mode: Pipeline  # Use Pipeline mode with functions
  pipeline:
    - step: load-env
      functionRef:
        name: function-environment-configs
      input:
        apiVersion: environmentconfigs.fn.crossplane.io/v1beta1
        kind: Input
        environmentConfigs:
        - type: Reference
          ref:
            name: dns-config
    - step: create-resources
      functionRef:
        name: function-go-templating
      input:
        apiVersion: gotemplating.fn.crossplane.io/v1beta1
        kind: GoTemplate
        source: Inline
        inline:
          template: |
            apiVersion: kubernetes.crossplane.io/v1alpha2
            kind: Object
            metadata:
              name: {{ .observed.composite.resource.metadata.name }}-deployment
            spec:
              forProvider:
                manifest:
                  apiVersion: apps/v1
                  kind: Deployment
                  # ... rest of manifest
```

**examples/example.yaml** - Usage example:
```yaml
apiVersion: platform.io/v1alpha1
kind: MyResource
metadata:
  name: my-app
  namespace: default  # Namespaced!
spec:
  name: my-app
  size: medium
```

### Step 3: Test Locally

```bash
# Apply template
kubectl apply -f xrd.yaml
kubectl apply -f composition.yaml

# Test with example
kubectl apply -f examples/example.yaml

# Verify
kubectl get myresource -A
```

### Step 4: Register in Catalog

Create `catalog/templates/template-my-resource.yaml`:

```yaml
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

Add to `catalog/kustomization.yaml`:
```yaml
resources:
  - templates/template-dns-record.yaml
  - templates/template-whoami-app.yaml
  - templates/template-my-resource.yaml  # Add this
```

### Step 5: Submit PR

Submit PR to catalog repository for review and approval.

## Monitoring Templates

### Check Sync Status
```bash
# Overall status
flux get all -n flux-system

# Template repositories
flux get sources git -n flux-system | grep template-

# Check resources
kubectl get xrd
kubectl get compositions
```

### Troubleshooting

If template not syncing:
```bash
# Check GitRepository
kubectl describe gitrepository template-my-resource -n flux-system

# Check logs
flux logs --kind=Kustomization --name=template-my-resource
```

## Best Practices

1. **Naming**: Use `template-{resource}` for repositories
2. **Versioning**: Tag releases in template repositories
3. **Documentation**: Include clear README and examples
4. **Testing**: Test locally before pushing
5. **API Design**: Keep APIs simple and user-friendly
6. **Defaults**: Provide sensible defaults in XRD schema

## Platform Resources Reference

These are installed by `setup-cluster.sh` and available to all templates:

### Providers
- `provider-kubernetes` - Manage K8s resources
- `provider-helm` - Deploy Helm charts
- `provider-cloudflare` - Manage DNS (production)

### Functions
- `function-go-templating` - Generate resources with Go templates
- `function-patch-and-transform` - Traditional patching
- `function-auto-ready` - Automatic readiness
- `function-environment-configs` - Load shared config

### Environment Configs
- `dns-config` - DNS zone and provider settings

## Related Documentation

- [Platform Overview](./overview.md) - Architecture overview
- [Cluster Setup](./setup.md) - Initial setup
- [Cluster Configuration](./configuration.md) - Environment config