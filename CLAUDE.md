# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Important
- Never git push to main branch, always open a PR.
- Webresearch, today is 2025

## Workspace Structure

**IMPORTANT**: This directory IS the portal-workspace repository itself!

It serves as a parent/workspace repository that:
- Contains shared documentation and configuration
- Has other repositories cloned inside it (app-portal, templates, etc.)
- These nested repositories are gitignored and managed independently

```
open-service-portal/         # THIS directory = portal-workspace repo
├── .git/                   # portal-workspace git (own repository)
├── CLAUDE.md               # Workspace-level context (this file)
├── README.md               # Workspace overview
├── docs/                   # Shared documentation
│   ├── crossplane-v2-architecture.md  # Crossplane v2 overview
│   ├── crossplane-catalog-setup.md    # Template management
│   └── local-kubernetes-setup.md      # K8s setup guide
├── scripts/                # Unified setup and utility scripts
│   ├── setup-cluster.sh    # Universal K8s cluster setup
│   ├── config-local.sh     # Switch to local cluster
│   ├── config-openportal.sh # Configure OpenPortal production
│   ├── manifests-setup-cluster/  # Infrastructure manifests
│   │   ├── crossplane-functions.yaml  # Composition functions
│   │   ├── crossplane-provider-*.yaml # Provider definitions
│   │   └── flux-catalog.yaml         # Catalog watcher
│   ├── manifests-config-openportal/ # Environment configs
│   │   ├── cloudflare-zone-openportal-dev.yaml
│   │   └── environment-configs.yaml
│   └── cloudflare/         # Cloudflare debug suite
│       ├── setup.sh        # Test setup
│       ├── validate.sh     # Comprehensive validation
│       ├── remove.sh       # Cleanup
│       └── test-xr.sh      # XR testing
├── .gitignore              # Ignores nested repos below
│
├── app-portal/             # NESTED repo - Main Backstage application
│   ├── packages/           # Frontend and backend packages
│   ├── plugins/            # Custom plugins (scaffolder, kubernetes-ingestor)
│   └── app-config.yaml     # Main configuration with XRD publishing
├── catalog/                # NESTED repo - Template registry for Flux
│   └── templates/          # Template references
├── concepts/               # Architecture and design documentation
├── deploy-app-portal/      # NESTED repo - Kubernetes deployment manifests
│
├── template-dns-record/    # NESTED repo - Mock DNS template
│   └── configuration/
│       └── xrd.yaml       # XRD with openportal.dev/tags label
├── template-cloudflare-dnsrecord/  # NESTED repo - Real Cloudflare DNS
│   ├── xrd.yaml           # XRD with publishPhase annotations
│   ├── composition.yaml   # Pipeline mode composition
│   └── examples/          # XR examples
├── template-whoami/        # NESTED repo - Demo application template
│   ├── xrd.yaml           # Simple app deployment XRD
│   └── composition.yaml   # Helm + DNS composition
├── template-whoami-service/  # NESTED repo - Composite service template
│   ├── xrd.yaml           # Composition of compositions
│   └── composition.yaml   # Combines whoami + DNS
│
├── service-nodejs-template/      # NESTED repo - Node.js service template
├── service-mongodb-template/     # NESTED repo - MongoDB service template
├── service-mongodb-golden-path-template/  # NESTED repo - MongoDB with best practices
├── service-firewall-template/    # NESTED repo - Firewall rules template
├── service-dnsrecord-template/   # NESTED repo - DNS record service
├── service-cluster-template/     # NESTED repo - Cluster provisioning
│
├── backstage/              # LOCAL CLONE - Backstage core docs (gitignored)
├── backstage-terasky-plugins-fork/  # LOCAL CLONE - TeraSky plugins fork
└── scripts/                # Unified setup and utility scripts

## Setup

To set up the complete workspace, clone all repositories:

```bash
# Clone the workspace
git clone https://github.com/open-service-portal/portal-workspace.git

# Navigate to the workspace
cd portal-workspace

# Clone the app-portal code repository inside the workspace
git clone https://github.com/open-service-portal/app-portal.git
```

### GitHub Organization

- **open-service-portal** - Organization for the Open Service Portal project
  - Contains Backstage application, templates, and documentation
  - URL: https://github.com/open-service-portal

### Repository Overview

#### Core Application
- **app-portal/** - Main Backstage application (git@github.com:open-service-portal/app-portal.git)
  - Scaffolded with `@backstage/create-app`
  - Contains frontend and backend packages
  - Configured for GitHub/GitLab integration

#### Crossplane Templates (Infrastructure)
- **catalog/** - Central registry for Crossplane templates (git@github.com:open-service-portal/catalog.git)
- **template-dns-record/** - Mock DNS template for testing (git@github.com:open-service-portal/template-dns-record.git)
- **template-cloudflare-dnsrecord/** - Real Cloudflare DNS management (git@github.com:open-service-portal/template-cloudflare-dnsrecord.git)
- **template-whoami/** - Demo application deployment (git@github.com:open-service-portal/template-whoami.git)
- **template-whoami-service/** - Composite service (app + DNS) (git@github.com:open-service-portal/template-whoami-service.git)

#### Backstage Templates (Services)
- **service-nodejs-template/** - Template for Node.js services (git@github.com:open-service-portal/service-nodejs-template.git)
- **service-mongodb-template/** - MongoDB database service (git@github.com:open-service-portal/service-mongodb-template.git)
- **service-mongodb-golden-path-template/** - MongoDB with best practices (git@github.com:open-service-portal/service-mongodb-golden-path-template.git)
- **service-firewall-template/** - Network firewall rules (git@github.com:open-service-portal/service-firewall-template.git)
- **service-dnsrecord-template/** - DNS record management (git@github.com:open-service-portal/service-dnsrecord-template.git)
- **service-cluster-template/** - Kubernetes cluster provisioning (git@github.com:open-service-portal/service-cluster-template.git)

#### Deployment & Infrastructure
- **deploy-app-portal/** - Kubernetes deployment manifests for Backstage (git@github.com:open-service-portal/deploy-app-portal.git)

#### Documentation & Workspace
- **portal-workspace/** - This workspace repository with documentation and setup scripts (git@github.com:open-service-portal/portal-workspace.git)
- **concepts/** - Architecture and design documentation (part of workspace)

#### Local Reference Repositories (gitignored)
- **backstage/** - Local clone of Backstage core for documentation reference
- **backstage-terasky-plugins-fork/** - Fork of TeraSky plugins for development

## Development

Each repository has its own `CLAUDE.md` file with specific development commands:

- **app-portal/CLAUDE.md** - Backstage development commands, build instructions, plugin creation
- **template-*/CLAUDE.md** - Template testing, scaffolding, and validation commands
- **docs/CLAUDE.md** - Documentation build and preview commands

See the respective repository's CLAUDE.md for detailed instructions.

## Troubleshooting

Common issues and solutions are documented in [docs/troubleshooting/](./docs/troubleshooting/).

When encountering errors, check the troubleshooting guides first.

## High-Level Architecture

### Technology Stack
- **Framework**: Backstage (latest stable version)
- **Runtime**: Node.js 20 LTS
- **Package Manager**: Yarn (Berry)
- **Language**: TypeScript
- **Database**: SQLite (dev) / PostgreSQL (production)
- **Container**: Docker / Podman
- **Orchestration**: Kubernetes
- **GitOps**: Flux with catalog pattern
- **Infrastructure**: Crossplane v2.0 with namespaced XRs
- **Composition Functions**: go-templating, patch-and-transform, auto-ready, environment-configs

### Core Components
1. **Software Catalog** - Track services, libraries, and components
2. **TechDocs** - Documentation platform
3. **Scaffolder** - Software templates for creating new services
4. **Kubernetes Plugin** - K8s resource visibility
5. **Auth** - GitHub/GitLab authentication

## Development Guidelines

### Code Style
- Use TypeScript for all new code
- Follow existing patterns in the codebase
- Prefer functional components in React
- Use Material-UI components for consistency

### Template Development

#### Backstage Service Templates
1. Follow the naming convention: `service-{name}-template`
2. Add `template.yaml` in repository root
3. Templates are auto-discovered via GitHub provider
4. Include comprehensive documentation
5. Add example service scaffolding in `content/` directory

#### Crossplane Infrastructure Templates
1. Follow the naming convention: `template-{resource}`
2. Structure:
   - `xrd.yaml` - API definition (use v2 with namespaced scope)
   - `composition.yaml` - Implementation (use Pipeline mode)
   - `rbac.yaml` - Required permissions
   - `examples/xr.yaml` - Usage examples (XRs, not claims)
3. Register in catalog repository
4. Flux automatically syncs from catalog

### Environment Variables
Required environment variables should be documented and include:
- `GITHUB_TOKEN` - GitHub Personal Access Token
- `GITLAB_TOKEN` - GitLab Personal Access Token (if using GitLab)
- Additional service-specific tokens

## Important Files

### Backstage Configuration
- `app-config.yaml` - Base configuration
- `app-config.production.yaml` - Production overrides
- `app-config.local.yaml` - Local development overrides (gitignored)

### Package Structure
```
app-portal/
├── packages/
│   ├── app/          # Frontend application
│   └── backend/      # Backend services
├── plugins/          # Custom plugins
└── app-config.yaml   # Configuration
```

## Integration Points

### GitHub Integration
- Organization: `open-service-portal`
- Discovery: Automatic repository scanning
- Templates: GitHub Actions for CI/CD

### Service Provisioning
- Crossplane v2 with namespaced XRs (no claims needed)
- GitOps workflow with Flux catalog pattern
- Pipeline mode compositions with functions
- Platform-wide environment configurations

### Kubernetes Setup
We support any Kubernetes distribution with a unified setup:

**Infrastructure Setup**
```bash
# Universal setup script for any K8s cluster
./scripts/setup-cluster.sh

# Installs:
# - NGINX Ingress Controller
# - Flux GitOps with catalog watcher
# - Crossplane v2.0 with namespaced XRs
# - Composition functions (globally installed)
# - Base environment configurations
# - provider-kubernetes with RBAC
# - provider-helm for chart deployments
# - provider-cloudflare for DNS management
# - Backstage service account + app-config.local.yaml
```

**Environment Configuration**
We provide configuration scripts to switch between local and production environments:

```bash
# Switch to local development cluster
./scripts/config-local.sh
# - Switches kubectl context (default: rancher-desktop)
# - Loads settings from .env.local
# - Configures mock DNS provider for localhost

# Switch to OpenPortal production cluster
./scripts/config-openportal.sh
# - Switches kubectl context to OpenPortal cluster
# - Loads settings from .env.openportal (uses set -a for envsubst)
# - Creates Cloudflare credentials secret
# - Imports Cloudflare Zone resources
# - Updates EnvironmentConfigs for production DNS
```

**Cloudflare DNS Management**
Comprehensive debug suite for Cloudflare DNS provider:

```bash
# Validate Cloudflare setup
./scripts/cloudflare/validate.sh
# - Tests API token and permissions
# - Validates provider health
# - Tests CRUD operations
# - Cleans up test resources

# Test XR with zoneIdRef pattern
./scripts/cloudflare/test-xr.sh [create|status|remove]

# Complete cleanup
./scripts/cloudflare/remove.sh
```

**Environment Files**
- `.env.local` - Local cluster configuration (copy from `.env.local.example`)
- `.env.openportal` - Production cluster configuration (copy from `.env.openportal.example`)

**Version Philosophy: Latest + Greatest**
We intentionally use the latest stable versions of all components, especially Crossplane and its providers. This approach:
- **Identifies compatibility issues early** - We discover breaking changes and API incompatibilities before they impact production deployments
- **Tests new features proactively** - We can evaluate and adopt new capabilities like namespaced resources and v2 APIs immediately
- **Provides feedback to upstream** - Early adoption helps the Crossplane community by identifying edge cases
- **Keeps our platform modern** - Ensures we're not building on deprecated or soon-to-be-obsolete APIs
- **Simplifies future migrations** - Incremental updates are easier than massive version jumps

This is a deliberate testing strategy for our local development environment. Production deployments should use pinned, thoroughly tested versions.

**Crossplane Template Usage**
```bash
# Create XRs directly in your namespace (v2 style)
kubectl apply -f - <<EOF
apiVersion: platform.io/v1alpha1
kind: XDNSRecord  # Direct XR, no claim needed!
metadata:
  name: my-app
  namespace: my-team  # Namespaced!
spec:
  type: A
  name: my-app
  value: "192.168.1.100"
EOF
```

## Local Backstage Reference Documentation

For efficient documentation search, we maintain local clones of key Backstage repositories:

### Clone Commands
```bash
# Clone Backstage core repository (shallow clone for faster download)
git clone --depth 1 git@github.com:backstage/backstage.git

# Clone Community Plugins
git clone --depth 1 git@github.com:backstage/community-plugins.git backstage-community-plugins

# Clone TeraSky Plugins
git clone --depth 1 git@github.com:TeraSky-OSS/backstage-plugins.git backstage-terasky-plugins
```

### Core Documentation Paths
- **Backstage Core**: `/backstage/docs/` - Architecture, auth providers, plugins, tutorials
- **Community Plugins**: `/backstage-community-plugins/docs/` - Compatibility guides, maintainer docs
- **Community Plugins List**: `/backstage-community-plugins/workspaces/*/` - 100+ plugin READMEs
- **TeraSky Plugins**: `/backstage-terasky-plugins/site/docs/` - Crossplane, Kubernetes, GitOps plugins

### Key Documentation Areas
- **Getting Started**: `backstage/docs/getting-started/`
- **Auth Providers**: `backstage/docs/auth/*/provider.md`
- **Plugin Development**: `backstage/docs/plugins/`
- **Backend System**: `backstage/docs/backend-system/`
- **Frontend System**: `backstage/docs/frontend-system/`
- **Software Templates**: `backstage/docs/features/software-templates/`
- **Kubernetes Integration**: `backstage/docs/features/kubernetes/`
- **TechDocs**: `backstage/docs/features/techdocs/`

Note: These paths are gitignored via the following pattern in `.gitignore`:
```
/backstage*
```

## Best Practices

1. **Version Control**
   - Keep workspace repositories in sync
   - Use semantic versioning for releases
   - Tag stable versions

2. **Security**
   - Never commit plaintext secrets or tokens
   - Use environment variables for local development
   - Follow Backstage security guidelines
   - Use RBAC for namespace isolation with XRs

3. **Documentation**
   - Update TechDocs with service changes
   - Maintain up-to-date README files
   - Document architectural decisions


## Development Workflow

### Workflow for Changes

1. **Document concepts in workspace**
   - Create markdown files in this workspace for cross-cutting concerns
   - Document architectural decisions
   - Plan major features before implementation

2. **Work in individual repositories**
   - Create feature branches
   - Make changes in the appropriate repository
   - Test locally

3. **Submit pull requests**
   - Push feature branch to GitHub
   - Create PR with clear description
   - Link to related issues or concepts

### GitHub CLI Usage

We use GitHub CLI (`gh`) for GitHub operations with file-based bodies:

```bash
# Creating issues
gh issue create --repo open-service-portal/app-portal \
  --title "Issue title here" \
  --body-file issue-body.md

# Creating pull requests  
gh pr create --repo open-service-portal/app-portal \
  --title "feat: PR title here" \
  --body-file pr-body.md
```

**Conventions:**
- Use `--body-file` for better markdown formatting
- Don't include the title in the markdown file (use `--title` flag)
- Body files can be deleted after use


## Workspace Conventions

### Repository Naming
- `app-*` - Applications (e.g., app-portal)
- `catalog` - Crossplane template registry
- `template-*` - Crossplane infrastructure templates
- `service-*-template` - Backstage service templates
- `plugin-*` - Shared Backstage plugins (future)

### Documentation Structure
Each repository should contain:
- `README.md` - Quick start and overview
- `CLAUDE.md` - Detailed development instructions for Claude Code
- `docs/` - Extended documentation (if needed)

### Communication & Analogies
We use **restaurant industry analogies** to explain technical concepts, especially for Crossplane:
- **Menu** = XRD (Composite Resource Definition) - what customers can order
- **Kitchen** = Composition - how to prepare what was ordered
- **Supplier** = Provider (e.g., provider-helm) - source of ingredients
- **Customer** = Developer using the platform
- **Order** = XR - direct resource request (v2 style, no claim)
- **Soft Opening** = Testing phase before production

This makes complex infrastructure concepts accessible to all stakeholders.

## Key Patterns

1. **Service Discovery**: Use Backstage Software Catalog
2. **Authentication**: GitHub/GitLab OAuth  
3. **Service Templates**: Backstage Scaffolder for service creation
4. **Infrastructure Templates**: Crossplane with catalog pattern
5. **Documentation**: TechDocs with MkDocs
6. **Deployment**: GitOps workflow with Flux
7. **Resource Management**: Namespaced XRs (Crossplane v2)