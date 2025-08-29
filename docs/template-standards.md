# Template Standards and Guidelines

This document defines the standards and structure that all Crossplane templates in the Open Service Portal must follow.

## Repository Naming

All template repositories must follow the pattern: `template-<resource-type>`

Examples:
- `template-namespace` - Kubernetes namespace provisioning
- `template-dns-record` - DNS record management
- `template-cloudflare-dnsrecord` - Cloudflare DNS integration

## Required Directory Structure

Every template MUST have this exact structure:

```
template-<name>/
├── .github/
│   └── workflows/
│       └── release.yaml        # GitHub Actions release workflow
├── configuration/
│   ├── README.md               # Package constraints documentation
│   ├── crossplane.yaml         # Crossplane package metadata
│   ├── xrd.yaml               # Composite Resource Definition
│   └── composition.yaml       # Composition implementation
├── examples/
│   ├── basic-<resource>.yaml  # Basic usage example
│   └── <advanced>.yaml        # Advanced examples with features
├── .gitignore                 # Must include *.xpkg
├── kustomization.yaml         # Resource bundling
├── rbac.yaml                  # RBAC permissions for Crossplane
├── mise.toml                  # Tool management
└── README.md                  # User documentation

```

## XRD Requirements

### API Version and Metadata

```yaml
---
apiVersion: apiextensions.crossplane.io/v2  # MUST use v2
kind: CompositeResourceDefinition
metadata:
  name: <resources>.openportal.dev  # MUST use openportal.dev domain
  labels:
    terasky.backstage.io/generate-form: "true"  # REQUIRED for Backstage
  annotations:
    crossplane.io/version: "v2.0"
    backstage.io/source-location: "url:https://github.com/open-service-portal/template-<name>"
    openportal.dev/tags: "tag1,tag2"  # Comma-separated tags
    openportal.dev/description: "Brief description"
    openportal.dev/icon: "icon-name"  # Optional icon
```

### Spec Requirements

```yaml
spec:
  scope: Namespaced  # MUST be Namespaced for v2 XRs
  group: openportal.dev  # MUST use openportal.dev
  names:
    kind: <ResourceName>  # NO 'X' prefix (e.g., Namespace, not XNamespace)
    plural: <resources>
  versions:
    - name: v1alpha1
      served: true
      referenceable: true
      schema:
        openAPIV3Schema:
          type: object
          required:
            - spec
          properties:
            spec:
              type: object
              # Define your resource properties here
```

## Composition Requirements

```yaml
---
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: <resources>.openportal.dev
  labels:
    crossplane.io/xrd: <resources>.openportal.dev
spec:
  compositeTypeRef:
    apiVersion: openportal.dev/v1alpha1
    kind: <ResourceName>
  
  # Use Pipeline mode for composition functions
  mode: Pipeline
  pipeline:
    - step: <step-name>
      functionRef:
        name: function-go-templating  # Or other functions
      input:
        # Function configuration
```

## Namespaced XRs and Object Resources

### Critical Requirements for Namespaced XRs

Since all XRs use `scope: Namespaced` in Crossplane v2, special care must be taken when using `provider-kubernetes` Object resources.

**IMPORTANT DISCOVERY:** Provider-kubernetes has TWO Object APIs:
- `kubernetes.crossplane.io/v1alpha2` - **cluster-scoped** (CANNOT be used with namespaced XRs)
- `kubernetes.m.crossplane.io/v1alpha1` - **namespace-scoped** (CAN be used with namespaced XRs)

### The Solution: Use Namespace-Scoped Object API

```yaml
# CORRECT: Use the namespace-scoped v1alpha1 API
apiVersion: kubernetes.m.crossplane.io/v1alpha1  # Note the .m. in the API group!
kind: Object
metadata:
  name: {{ $xrName }}-deployment
  namespace: {{ $xrNamespace }}  # REQUIRED: Object must be in XR's namespace
spec:
  forProvider:
    manifest:
      # Your Kubernetes resource here
  providerConfigRef:
    kind: ProviderConfig  # REQUIRED: kind field for v1alpha1
    name: kubernetes-provider
```

**Important Guidelines:**

1. **Use the correct Object API version**
   - Use `kubernetes.m.crossplane.io/v1alpha1` (namespace-scoped)
   - NOT `kubernetes.crossplane.io/v1alpha2` (cluster-scoped)
   - The `.m.` stands for "managed" and indicates namespace-scoped resources

2. **Add namespace to Object metadata**
   - Object resources need `metadata.namespace: {{ $xrNamespace }}`
   - This places the Object resource itself in the XR's namespace

3. **Include kind in providerConfigRef**
   - The v1alpha1 API requires `kind: ProviderConfig`
   - This is different from v1alpha2 which has a default

4. **Create namespaced ProviderConfig**
   - Create a ProviderConfig in the same namespace as your XRs
   - Use `kubernetes.m.crossplane.io/v1alpha1` API for the ProviderConfig

5. **Do NOT create namespaces from namespaced XRs**
   - The XR already exists in a namespace
   - Deploy all resources to the XR's namespace
   - Use `{{ .observed.composite.resource.metadata.namespace }}` in templates

6. **Resource naming must be unique**
   - Include XR name in resource names: `name: {{ $xrName }}-deployment`
   - This prevents conflicts when multiple XRs exist in the same namespace

### Example: Complete Working Pattern

```yaml
# In your go-templating function:
{{- $xrName := .observed.composite.resource.metadata.name }}
{{- $xrNamespace := .observed.composite.resource.metadata.namespace }}

apiVersion: kubernetes.m.crossplane.io/v1alpha1  # Namespace-scoped API
kind: Object
metadata:
  name: {{ $xrName }}-service
  namespace: {{ $xrNamespace }}  # Object in XR's namespace
spec:
  forProvider:
    manifest:
      apiVersion: v1
      kind: Service
      metadata:
        name: {{ $xrName }}           # Unique name
        namespace: {{ $xrNamespace }} # Service in XR's namespace
  providerConfigRef:
    kind: ProviderConfig  # Required for v1alpha1
    name: kubernetes-provider
```

### Setting up ProviderConfig

You need a namespaced ProviderConfig:

```yaml
apiVersion: kubernetes.m.crossplane.io/v1alpha1
kind: ProviderConfig
metadata:
  name: kubernetes-provider
  namespace: your-namespace  # Same namespace as XRs
spec:
  credentials:
    source: InjectedIdentity
```

For more details, see [Crossplane PR #6588](https://github.com/crossplane/crossplane/pull/6588) which enforces that namespaced XRs cannot create cluster-scoped resources.

## Configuration Package (crossplane.yaml)

```yaml
apiVersion: meta.pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: configuration-<resource>
  annotations:
    meta.crossplane.io/maintainer: Open Service Portal Team
    meta.crossplane.io/source: github.com/open-service-portal/template-<name>
    meta.crossplane.io/license: Apache-2.0
    meta.crossplane.io/description: |
      Description of what this template provides
    meta.crossplane.io/readme: |
      Detailed README content
spec:
  crossplane:
    version: ">=v1.14.0"
  dependsOn:
    - provider: xpkg.upbound.io/crossplane-contrib/provider-kubernetes
      version: ">=v0.13.0"
```

## Kustomization File

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Only include the Crossplane resources, not the examples
resources:
  - configuration/xrd.yaml
  - configuration/composition.yaml
  - rbac.yaml
# Note: examples/*.yaml are intentionally NOT included
```

## RBAC File

```yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: crossplane-<resource>-resources
  labels:
    rbac.crossplane.io/aggregate-to-crossplane: "true"
    app.kubernetes.io/component: crossplane
    app.kubernetes.io/part-of: <resource>-template
rules:
# Define permissions for resources your composition creates
- apiGroups:
  - ""
  resources:
  - <kubernetes-resources>
  verbs:
  - create
  - delete
  - get
  - list
  - patch
  - update
  - watch
```

## GitHub Actions Release Workflow

Use the standard release workflow from `template-dns-record/.github/workflows/release.yaml`:
- Triggers on version tags (v*.*.*)
- Builds Crossplane Configuration package
- Pushes to GitHub Container Registry
- Creates GitHub release
- Automatically creates PR to update catalog

## Supporting Files

### .gitignore
```
# Build artifacts
*.xpkg
```

### mise.toml
```toml
[tools]
crossplane-cli = "latest"
```

### configuration/README.md
```markdown
# Configuration package contents

> Including YAML files that aren't Compositions or CompositeResourceDefinitions isn't supported.  
> &mdash; [*Crossplane docs*](https://docs.crossplane.io/latest/packages/configurations/#build-the-package)
```

## Examples Structure

Provide at least:
1. **basic-<resource>.yaml** - Minimal configuration
2. **<resource>-with-<feature>.yaml** - Advanced features

Example format:
```yaml
# Example: Brief description
apiVersion: openportal.dev/v1alpha1
kind: <ResourceName>
metadata:
  name: example-name
  namespace: default  # XR can be created in any namespace
spec:
  # Minimal required fields
  name: example
  # Additional fields with comments
```

## Documentation Requirements

### Main README.md

Must include:
1. **Overview** - What the template provides
2. **Components** - List of files and their purpose
3. **Usage** - Basic and advanced examples
4. **Features** - Key capabilities
5. **Installation** - How to apply via catalog
6. **Parameters** - Table of all spec fields
7. **Restaurant Analogy** - Explain using restaurant metaphor

## Versioning and Releases

1. Use semantic versioning: `v<major>.<minor>.<patch>`
2. Create annotated tags with detailed release notes
3. GitHub Actions automatically:
   - Builds Configuration package
   - Pushes to ghcr.io
   - Creates GitHub release
   - Opens PR to update catalog

## Testing Checklist

Before releasing a template:

- [ ] XRD uses `apiextensions.crossplane.io/v2`
- [ ] Group is `openportal.dev`
- [ ] Scope is `Namespaced`
- [ ] No 'X' prefix in kind name
- [ ] Has `terasky.backstage.io/generate-form` label
- [ ] Has `backstage.io/source-location` annotation
- [ ] Composition uses Pipeline mode
- [ ] Object resources use `kubernetes.m.crossplane.io/v1alpha1` API (namespace-scoped)
- [ ] Object resources have `metadata.namespace: {{ $xrNamespace }}`
- [ ] providerConfigRef includes `kind: ProviderConfig`
- [ ] Namespaced ProviderConfig exists in target namespace
- [ ] No namespace creation from namespaced XRs
- [ ] Resources use XR's namespace via template variable
- [ ] Resource names include XR name for uniqueness
- [ ] All required files present
- [ ] RBAC permissions are minimal but sufficient
- [ ] Examples work when applied
- [ ] README is complete with restaurant analogy
- [ ] Release workflow is configured

## Common Mistakes to Avoid

1. ❌ Using `platform.io` instead of `openportal.dev`
2. ❌ Using v1 API instead of v2
3. ❌ Missing `scope: Namespaced`
4. ❌ Using 'X' prefix in resource names
5. ❌ Missing kustomization.yaml
6. ❌ Missing rbac.yaml
7. ❌ Including examples in kustomization.yaml
8. ❌ Missing backstage annotations
9. ❌ Using `kubernetes.crossplane.io/v1alpha2` Object API (cluster-scoped) with namespaced XRs
10. ❌ Missing `metadata.namespace` on Object resources
11. ❌ Missing `kind: ProviderConfig` in providerConfigRef for v1alpha1 API
12. ❌ No namespaced ProviderConfig in the XR's namespace
13. ❌ Creating namespaces from namespaced XRs
14. ❌ Not using unique resource names (missing XR name prefix)

## Reference Templates

Use these as examples:
- `template-dns-record` - Simple resource creation
- `template-namespace` - Complex with quotas and policies
- `template-whoami` - Application deployment
- `template-cloudflare-dnsrecord` - External provider integration