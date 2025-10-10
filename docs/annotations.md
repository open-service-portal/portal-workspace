# Annotation Namespace Strategy

This document defines the annotation namespace strategy for the Open Service Portal project, covering XRDs, Backstage templates, and runtime-generated entities.

## Table of Contents

- [Overview](#overview)
- [Annotation Namespaces](#annotation-namespaces)
- [Standard Backstage Annotations](#standard-backstage-annotations)
- [Open Service Portal Annotations](#open-service-portal-annotations)
- [Crossplane Standard Annotations](#crossplane-standard-annotations)
- [GitHub Integration Annotations](#github-integration-annotations)
- [Third-Party Plugin Annotations](#third-party-plugin-annotations)
- [Migration from Legacy Namespaces](#migration-from-legacy-namespaces)

## Overview

We use a **standard-first approach**: official Backstage annotations for standard features, custom `openportal.dev/*` namespace for project-specific features only.

### Design Principles

1. **Standard First** - Use official `backstage.io/*` annotations for standard Backstage features
2. **Vendor Neutral** - Avoid vendor-specific namespaces unless actively maintained by that vendor
3. **Purpose-Based** - Group by purpose (transform, GitOps, runtime), not by feature type
4. **Clear Ownership** - Use `openportal.dev/*` for features we own and maintain
5. **No Duplication** - One source of truth per concept

## Annotation Namespaces

We use four primary annotation namespaces:

| Namespace | Purpose | Examples |
|-----------|---------|----------|
| `backstage.io/*` | Standard Backstage metadata | title, description, owner, lifecycle |
| `openportal.dev/*` | Open Service Portal features | XRD transform, GitOps, runtime metadata |
| `crossplane.io/*` | Crossplane standard metadata | version, XRD references |
| `github.com/*` | GitHub integration | project-slug |
| `terasky.backstage.io/*` | TeraSky plugin compatibility (limited use) | See [Third-Party Plugins](#third-party-plugin-annotations) |

## Standard Backstage Annotations

**Namespace**: `backstage.io/*`
**Used in**: XRD metadata, generated Backstage entities
**Purpose**: Standard Backstage catalog metadata

### Display & Documentation

```yaml
backstage.io/title: "My Resource"
  # Display title for the resource
  # Used by: XRD transform helpers, Backstage UI
  # Example: "ManagedNamespace Template"

backstage.io/description: "Create and manage resources"
  # Human-readable description
  # Used by: Generated templates, API entities, Backstage UI
  # Example: "Crossplane template for managing Kubernetes namespaces"

backstage.io/source-location: "url:https://github.com/org/repo"
  # Source code repository URL
  # Used by: Backstage catalog, TechDocs
  # Format: url:{github-url}

backstage.io/techdocs-ref: "url:https://github.com/org/repo"
  # Documentation reference URL
  # Used by: TechDocs plugin
  # Format: url:{docs-url}
```

### Ownership & Organization

```yaml
backstage.io/owner: "platform-team"
  # Owner team or user
  # Used by: Backstage catalog, RBAC, generated entities
  # Should match a Group or User entity in catalog

backstage.io/system: "infrastructure-templates"
  # System grouping for organizational hierarchy
  # Used by: Backstage catalog navigation
  # Should match a System entity in catalog

backstage.io/lifecycle: "production"
  # Lifecycle stage of the resource
  # Used by: API entities, Backstage catalog filtering
  # Values: experimental, production, deprecated
```

### Generation Metadata

```yaml
backstage.io/managed-by: "xrd-transform"
  # Identifies the tool that generated this entity
  # Added automatically by: XRD transform tool
  # Used for: Tracking generated entities
```

## Open Service Portal Annotations

**Namespace**: `openportal.dev/*`
**Used in**: XRD metadata, runtime-generated entities
**Purpose**: Project-specific features (XRD transform, GitOps, Crossplane)

### XRD Transform Configuration

These annotations control how XRDs are transformed into Backstage templates:

```yaml
openportal.dev/template: "custom"
  # Main Backstage template selector
  # Used by: XRD transform CLI
  # Default: "default"
  # Available: default, debug, custom
  # Location: plugins/ingestor/templates/backstage/*.hbs

openportal.dev/api-template: "openapi"
  # API documentation template selector
  # Used by: XRD transform CLI for generating API entities
  # Default: "default"
  # Available: default, custom
  # Location: plugins/ingestor/templates/api/*.hbs

openportal.dev/parameters-template: "cluster-scoped"
  # Parameters section template selector
  # Used by: XRD transform for template parameters generation
  # Default: "default" (includes namespace)
  # Available: default, cluster-scoped
  # Location: plugins/ingestor/templates/parameters/*.hbs

openportal.dev/steps-template: "cluster-scoped"
  # Steps section template selector
  # Used by: XRD transform for template steps generation
  # Default: "default" (includes namespace in manifest)
  # Available: default, cluster-scoped
  # Location: plugins/ingestor/templates/steps/*.hbs
```

**Example**: Cluster-scoped resource (ManagedNamespace)
```yaml
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
metadata:
  name: managednamespaces.openportal.dev
  annotations:
    backstage.io/title: "ManagedNamespace Template"
    backstage.io/description: "Manage Kubernetes namespaces"
    openportal.dev/parameters-template: "cluster-scoped"
    openportal.dev/steps-template: "cluster-scoped"
```

### Project Metadata

```yaml
openportal.dev/tags: "dns,cloudflare,infrastructure"
  # Comma-separated tags for categorization
  # Used by: Generated templates, catalog filtering
  # Parsed into array for Backstage tags field

openportal.dev/version: "v1.0.0"
  # Release version or "dev" for development
  # Used by: CI/CD pipelines, release tracking
  # Values: semantic version (v1.2.3) or "dev"
```

### GitOps Publishing Configuration

```yaml
openportal.dev/publish-phase: |
  gitRepo: "github.com?owner=org&repo=catalog-orders"
  gitBranch: "main"
  gitLayout: "cluster-scoped"
  basePath: "system/ManagedNamespace"
  createPr: true
  # GitOps publishing configuration (YAML block)
  # Used by: Backstage scaffolder publish step
  # Defines where and how to commit XR instances

openportal.dev/skip-publish-step: "true"
  # Skip the GitOps publishing step
  # Used by: Backstage scaffolder
  # Values: "true" or "false"
```

### Crossplane Configuration

```yaml
openportal.dev/default-composition: "whoamiapp"
  # Default composition name when none specified
  # Used by: Crossplane composition selection
  # Should match a Composition resource name

openportal.dev/composition-strategy: "pipeline"
  # Composition mode strategy
  # Used by: Composition architecture documentation
  # Values: pipeline, direct
  # Note: Crossplane v2 uses Pipeline mode by default
```

### Runtime Generated (by Entity Provider)

These annotations are added automatically by the Kubernetes entity provider:

```yaml
openportal.dev/kubernetes-kind: "CompositeResourceDefinition"
  # Kubernetes resource kind
  # Added by: KubernetesEntityProvider
  # Used for: Resource type identification

openportal.dev/kubernetes-name: "whoamiapps.openportal.dev"
  # Kubernetes resource name
  # Added by: KubernetesEntityProvider
  # Used for: Resource identification

openportal.dev/kubernetes-api-version: "apiextensions.crossplane.io/v2"
  # Kubernetes API version
  # Added by: KubernetesEntityProvider
  # Used for: API versioning info

openportal.dev/kubernetes-namespace: "default"
  # Kubernetes namespace (empty for cluster-scoped)
  # Added by: KubernetesEntityProvider
  # Used for: Namespace filtering
```

## Crossplane Standard Annotations

**Namespace**: `crossplane.io/*`
**Used in**: XRD metadata, generated entities
**Purpose**: Crossplane-specific metadata

```yaml
crossplane.io/version: "v2.0"
  # Crossplane version compatibility
  # Used by: Crossplane validation
  # Should match installed Crossplane version

# Generated by XRD Transform (in output entities)
crossplane.io/xrd-name: "whoamiapps.openportal.dev"
  # Reference to source XRD name
  # Added by: XRD transform tool
  # Used for: Traceability

crossplane.io/xrd-group: "openportal.dev"
  # Reference to source XRD group
  # Added by: XRD transform tool
  # Used for: Grouping related resources
```

## GitHub Integration Annotations

**Namespace**: `github.com/*`
**Used in**: XRD metadata
**Purpose**: GitHub-specific integrations

```yaml
github.com/project-slug: "open-service-portal/template-whoami"
  # GitHub repository identifier
  # Used by: GitHub integrations, CI/CD
  # Format: owner/repo
```

## Third-Party Plugin Annotations

### TeraSky Plugins

We use two TeraSky plugins that may rely on `terasky.backstage.io/*` annotations:

1. **`@terasky/backstage-plugin-crossplane-resources-frontend`** (v2.0.2)
   - Purpose: Display Crossplane claims and managed resources in Backstage UI
   - Required annotations: **None specific** - Works with standard Backstage entity types
   - Entity types: `crossplane-claim`, `crossplane-xr`

2. **`@terasky/backstage-plugin-scaffolder-backend-module-terasky-utils`** (v1.7.1)
   - Purpose: Additional scaffolder actions
   - Required annotations: **None specific**

**Important**: We do NOT use the TeraSky Kubernetes Ingestor plugin. Our custom ingestor uses `openportal.dev/*` annotations instead of `terasky.backstage.io/*` for runtime-generated metadata.

### If Using TeraSky Ingestor (Not Recommended)

If you were to use TeraSky's Kubernetes Ingestor, these annotations would be relevant:

```yaml
# DO NOT USE - For reference only
terasky.backstage.io/add-to-catalog: "true"        # Opt-in for ingestion
terasky.backstage.io/owner: "team-name"            # Use backstage.io/owner instead
terasky.backstage.io/system: "system-name"         # Use backstage.io/system instead
terasky.backstage.io/backstage-namespace: "default" # Backstage entity namespace
```

**Recommendation**: Use our custom ingestor with `openportal.dev/*` annotations instead.

## Migration from Legacy Namespaces

### Removed Annotations

The following `terasky.backstage.io/*` annotations are **no longer used** and should be migrated:

| Old (Removed) | New (Use Instead) | Notes |
|---------------|-------------------|-------|
| `terasky.backstage.io/lifecycle` | `backstage.io/lifecycle` | Standard Backstage |
| `terasky.backstage.io/owner` | `backstage.io/owner` | Standard Backstage |
| `terasky.backstage.io/system` | `backstage.io/system` | Standard Backstage |
| `terasky.backstage.io/tags` | `openportal.dev/tags` | Use our namespace |
| `terasky.backstage.io/publish-phase` | `openportal.dev/publish-phase` | GitOps config |
| `terasky.backstage.io/default-composition` | `openportal.dev/default-composition` | Crossplane config |
| `terasky.backstage.io/composition-strategy` | `openportal.dev/composition-strategy` | Crossplane config |
| `terasky.backstage.io/kubernetes-resource-*` | `openportal.dev/kubernetes-*` | Runtime metadata |
| `terasky.backstage.io/component-type` | *(removed)* | Use entity `kind` instead |
| `terasky.backstage.io/add-to-catalog` | *(removed)* | Not used |
| `terasky.backstage.io/auto-apply` | *(removed)* | Not used |
| `terasky.backstage.io/generate-form` | *(removed)* | Was a label, not annotation |
| `openportal.dev/title` | `backstage.io/title` | Use standard |
| `backstage.io/template` | `openportal.dev/template` | XRD transform feature |
| `backstage.io/api-template` | `openportal.dev/api-template` | XRD transform feature |
| `backstage.io/parameters-template` | `openportal.dev/parameters-template` | XRD transform feature |
| `backstage.io/steps-template` | `openportal.dev/steps-template` | XRD transform feature |

### Migration Checklist

When migrating XRDs to the new annotation namespace:

- [ ] Replace `terasky.backstage.io/lifecycle` with `backstage.io/lifecycle`
- [ ] Replace `terasky.backstage.io/owner` with `backstage.io/owner`
- [ ] Replace `terasky.backstage.io/system` with `backstage.io/system`
- [ ] Replace `terasky.backstage.io/tags` with `openportal.dev/tags`
- [ ] Replace `openportal.dev/title` with `backstage.io/title`
- [ ] Move XRD transform template selectors to `openportal.dev/*` namespace
- [ ] Remove unused `terasky.backstage.io/*` annotations
- [ ] Verify generated templates work correctly

## Examples

### Complete XRD Annotation Example (Namespaced Resource)

```yaml
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
metadata:
  name: whoamiapps.openportal.dev
  labels:
    openportal.dev/version: "dev"
  annotations:
    # Standard Backstage
    backstage.io/title: "Who Am I App"
    backstage.io/description: "Simple demo application with automatic domain configuration"
    backstage.io/owner: "platform-team"
    backstage.io/system: "demo-applications"
    backstage.io/lifecycle: "production"
    backstage.io/source-location: "url:https://github.com/open-service-portal/template-whoami"

    # XRD Transform (uses default templates - no overrides needed)

    # Project Metadata
    openportal.dev/tags: "demo,application"
    openportal.dev/version: "dev"

    # Crossplane
    crossplane.io/version: "v2.0"

    # GitHub
    github.com/project-slug: "open-service-portal/template-whoami"
spec:
  scope: Namespaced  # Uses default parameters/steps templates
  # ... rest of spec
```

### Complete XRD Annotation Example (Cluster-Scoped Resource)

```yaml
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
metadata:
  name: managednamespaces.openportal.dev
  labels:
    openportal.dev/version: "dev"
  annotations:
    # Standard Backstage
    backstage.io/title: "ManagedNamespace Template"
    backstage.io/description: "Crossplane template for managing Kubernetes namespaces with automated RBAC"
    backstage.io/owner: "platform-team"
    backstage.io/system: "infrastructure-templates"
    backstage.io/lifecycle: "experimental"
    backstage.io/source-location: "url:https://github.com/open-service-portal/template-namespace"
    backstage.io/techdocs-ref: "url:https://github.com/open-service-portal/template-namespace"

    # XRD Transform - cluster-scoped templates
    openportal.dev/parameters-template: "cluster-scoped"
    openportal.dev/steps-template: "cluster-scoped"

    # Project Metadata
    openportal.dev/tags: "namespace,kubernetes,core,rbac,infrastructure,platform"
    openportal.dev/version: "dev"

    # GitOps Publishing
    openportal.dev/publish-phase: |
      gitRepo: "github.com?owner=open-service-portal&repo=catalog-orders"
      gitBranch: "main"
      gitLayout: "cluster-scoped"
      basePath: "system/ManagedNamespace"
      createPr: true

    # Crossplane
    crossplane.io/version: "v2.0"

    # GitHub
    github.com/project-slug: "open-service-portal/template-namespace"
spec:
  scope: Cluster  # Must be cluster-scoped to create Namespace resources
  # ... rest of spec
```

## Best Practices

1. **Always use `backstage.io/*` for standard features** - Don't reinvent standard annotations
2. **Use `openportal.dev/*` sparingly** - Only for truly project-specific features
3. **Document all custom annotations** - Update this file when adding new annotations
4. **Validate annotations in CI/CD** - Ensure XRDs follow the annotation strategy
5. **Keep annotations DRY** - Don't duplicate information across multiple annotations
6. **Use semantic values** - Follow established conventions (e.g., lifecycle values)

## Related Documentation

- [XRD Transform Guide](./xrd-transform.md) - Using the XRD transform tool
- [Template Development](./template-development.md) - Creating custom templates
- [GitOps Workflow](./gitops-workflow.md) - Publishing configuration
- [Backstage Catalog](https://backstage.io/docs/features/software-catalog/) - Official documentation

---

**Last Updated**: 2025-10-07
**Maintained By**: Open Service Portal Team
