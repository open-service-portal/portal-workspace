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
    openportal.dev/version: "dev"  # REQUIRED placeholder - CI/CD replaces with release version
  annotations:
    crossplane.io/version: "v2.0"
    backstage.io/source-location: "url:https://github.com/open-service-portal/template-<name>"
    openportal.dev/tags: "tag1,tag2"  # Comma-separated tags
    openportal.dev/description: "Brief description"
    openportal.dev/icon: "icon-name"  # Optional icon
```

### Version Label Management

**IMPORTANT**: All XRD files must include the `openportal.dev/version: "dev"` label as a placeholder.

**Why this pattern exists:**
1. **Development identification** - "dev" clearly marks unreleased versions in the cluster
2. **CI/CD automation** - GitHub Actions replaces "dev" with the actual version during release
3. **Avoids YAML corruption** - Version labels are only added to XRDs, not crossplane.yaml (which contains multi-line strings that yq can corrupt)

**Implementation in GitHub Actions:**
```yaml
# In release.yaml workflow
- name: Build Configuration package
  run: |
    # Add version label to XRD only (crossplane.yaml has multi-line strings that yq corrupts)
    yq -i '.metadata.labels."openportal.dev/version" = env(VERSION)' configuration/xrd.yaml
    
    # Build the .xpkg file
    crossplane xpkg build \
      --package-root=configuration/ \
      --package-file=configuration-<template-name>.xpkg
```

**Note**: Never use yq to modify crossplane.yaml files as they often contain multi-line strings in annotations that yq will corrupt. If labels are needed in crossplane.yaml, add them manually with static values.

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
    kind: ClusterProviderConfig  # Use cluster-wide config
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

3. **Use ClusterProviderConfig in providerConfigRef**
   - The v1alpha1 API requires `kind: ClusterProviderConfig`
   - This references the cluster-wide configuration set up by `setup-cluster.sh`
   - Do NOT use `kind: ProviderConfig` unless you have namespace-specific configs

4. **Do NOT create namespaces from namespaced XRs**
   - The XR already exists in a namespace
   - Deploy all resources to the XR's namespace
   - Use `{{ .observed.composite.resource.metadata.namespace }}` in templates

5. **Resource naming must be unique**
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
    kind: ClusterProviderConfig  # Use cluster-wide config
    name: kubernetes-provider
```

### Provider Configuration

The setup script (`scripts/setup-cluster.sh`) creates a ClusterProviderConfig:

```yaml
apiVersion: kubernetes.m.crossplane.io/v1alpha1
kind: ClusterProviderConfig
metadata:
  name: kubernetes-provider
spec:
  credentials:
    source: InjectedIdentity
```

This cluster-wide configuration is used by all templates. You don't need to create namespace-specific ProviderConfigs unless you have special multi-tenancy requirements.

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

All templates MUST include the standardized release workflow at `.github/workflows/release.yaml`.

### Workflow Features
- **Triggers**: Version tags (v*.*.*) or manual dispatch
- **Multi-platform builds**: linux/amd64, linux/arm64
- **Registry**: GitHub Container Registry (ghcr.io)
- **Automatic versioning**: Tags packages with version
- **GitHub Release**: Creates release with artifacts
- **Catalog update**: Auto-generates catalog entry (artifact)

### Required Configuration

1. **Package naming convention**:
   ```yaml
   env:
     REGISTRY: ghcr.io
     PACKAGE_NAME: open-service-portal/configuration-<template-name>
   ```

2. **Configuration structure**:
   ```
   template-<name>/
   ├── configuration/
   │   ├── crossplane.yaml    # Package metadata
   │   ├── xrd.yaml           # XRD definition
   │   └── composition.yaml   # Composition
   └── .github/
       └── workflows/
           └── release.yaml    # Standard workflow
   ```

3. **Package file naming**:
   - Build output: `configuration-<template-name>.xpkg`
   - Registry path: `ghcr.io/open-service-portal/configuration-<template-name>`

### Workflow Template

Copy the standard workflow and replace placeholders:
- `TEMPLATE_NAME_HERE` → `configuration-<your-template>`
- `TEMPLATE_TITLE_HERE` → Human-readable name
- `TEMPLATE_DESCRIPTION_HERE` → Brief description
- `TEMPLATE_FEATURES_HERE` → List of features

### Release Process

1. **Create version tag**:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

2. **Workflow automatically**:
   - Builds Configuration package from `configuration/` directory
   - Pushes to `ghcr.io/open-service-portal/configuration-<name>:v1.0.0`
   - Also tags as `:latest` (if not pre-release)
   - Creates GitHub release with `.xpkg` file
   - Generates `catalog-entry.yaml` artifact

3. **Manual installation**:
   ```bash
   kubectl apply -f - <<EOF
   apiVersion: pkg.crossplane.io/v1
   kind: Configuration
   metadata:
     name: configuration-<name>
     namespace: crossplane-system
   spec:
     package: ghcr.io/open-service-portal/configuration-<name>:v1.0.0
   EOF
   ```

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
1. `basic-<resource>.yaml` - Minimal configuration
2. `<resource>-with-<feature>.yaml` - Advanced features

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
- [ ] Has `openportal.dev/version: "dev"` label (placeholder for CI/CD)
- [ ] Has `backstage.io/source-location` annotation
- [ ] Composition uses Pipeline mode
- [ ] Object resources use `kubernetes.m.crossplane.io/v1alpha1` API (namespace-scoped)
- [ ] Object resources have `metadata.namespace: {{ $xrNamespace }}`
- [ ] providerConfigRef uses `kind: ClusterProviderConfig`
- [ ] References `kubernetes-provider` ClusterProviderConfig
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
11. ❌ Missing `kind: ClusterProviderConfig` in providerConfigRef
12. ❌ Creating namespaces from namespaced XRs
13. ❌ Not using unique resource names (missing XR name prefix)

## Reference Templates

Use these as examples:
- `template-dns-record` - Simple resource creation
- `template-namespace` - Complex with quotas and policies
- `template-whoami` - Application deployment
- `template-cloudflare-dnsrecord` - External provider integration