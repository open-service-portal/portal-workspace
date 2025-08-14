# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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
├── concepts/               # Architecture decisions
├── scripts/                # Unified setup and utility scripts
│   ├── setup-cluster.sh    # Universal K8s cluster setup
│   └── cluster-manifests/  # Crossplane configs
├── .claude/                # Claude Code configuration
│   └── agents/             # Custom agents for specialized tasks
├── .gitignore              # Ignores nested repos below
│
├── app-portal/             # NESTED repo (cloned separately)
│   └── .git/               # app-portal's own git
├── deploy-backstage/       # NESTED repo (cloned separately)
│   └── .git/               # deployment manifests
├── service-nodejs-template/ # NESTED repo (cloned separately)  
│   └── .git/               # template's own git
└── .github/                # NESTED repo for org profile
    └── .git/               # .github's own git
```

## Setup

To set up the complete workspace, clone all repositories:

```bash
# Clone the workspace
git clone https://github.com/open-service-portal/portal-workspace.git

# Navigate to the workspace
cd portal-workspace

# Clone the required repositories inside the workspace
git clone https://github.com/open-service-portal/app-portal.git
git clone https://github.com/open-service-portal/deploy-backstage.git
git clone https://github.com/open-service-portal/service-nodejs-template.git
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
  - Docker support with `scripts/docker-run-local.sh`

#### Deployment
- **deploy-backstage/** - Kubernetes deployment manifests (git@github.com:open-service-portal/deploy-backstage.git)
  - Kustomize-based configuration
  - Flux GitOps ready
  - SOPS encryption for secrets
  - Development and production overlays

#### Service Templates
- **service-nodejs-template/** - Template for Node.js services (git@github.com:open-service-portal/service-nodejs-template.git)
- **service-golang-template/** - Template for Go microservices (planned)
- **service-python-template/** - Template for Python services (planned)

#### Documentation
- **docs/** - Documentation website (planned)
- **portal-workspace/** - This workspace repository with meta-documentation

## Development

Each repository has its own `CLAUDE.md` file with specific development commands:

- **app-portal/CLAUDE.md** - Backstage development commands, build instructions, plugin creation
- **deploy-backstage/README.md** - Deployment instructions and GitOps configuration
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
- **GitOps**: Flux
- **Secret Management**: SOPS with age encryption
- **Infrastructure**: Crossplane v1.17

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
When creating service templates:
1. Follow the naming convention: `service-{name}-template`
2. Add `template.yaml` in repository root
3. Templates are auto-discovered via GitHub provider (pattern: `service-*-template`)
4. Include comprehensive documentation
5. Add example service scaffolding in `content/` directory

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
- Crossplane for infrastructure management
- GitOps workflow with Flux
- Kubernetes-native service definitions
- SOPS for encrypted secrets in Git

### Kubernetes Setup
We support any Kubernetes distribution with a unified setup:

**Cluster Setup**
```bash
# Universal setup script for any K8s cluster
./scripts/setup-cluster.sh

# Installs:
# - NGINX Ingress Controller
# - Flux GitOps
# - SOPS configuration with age keys
# - Crossplane v1.17
# - Backstage service account
```

**Secret Management**
```bash
# SOPS encryption is used for secrets
# See docs/sops-secret-management.md for details

# Secrets are encrypted in Git repositories
# Flux automatically decrypts using sops-age secret
```

## Best Practices

1. **Version Control**
   - Keep workspace repositories in sync
   - Use semantic versioning for releases
   - Tag stable versions

2. **Security**
   - Never commit plaintext secrets or tokens
   - Use SOPS encryption for secrets in Git
   - Age keys stored securely in cluster
   - Use environment variables for local development
   - Follow Backstage security guidelines

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
- `deploy-*` - Deployment configurations (e.g., deploy-backstage)
- `service-*-template` - Service templates
- `plugin-*` - Shared Backstage plugins (future)
- `docs` - Documentation site

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
- **Order** = Claim - request for resources
- **Soft Opening** = Testing phase before production

This makes complex infrastructure concepts accessible to all stakeholders.

## Key Patterns

1. **Service Discovery**: Use Backstage Software Catalog
2. **Authentication**: GitHub/GitLab OAuth
3. **Templates**: Scaffolder for service creation
4. **Documentation**: TechDocs with MkDocs
5. **Deployment**: GitOps workflow with Kubernetes

## Next Steps

1. Clone all required repositories
2. Run `./scripts/setup-cluster.sh` to prepare Kubernetes
3. Configure GitHub App authentication in app-portal
4. Encrypt secrets with SOPS (see docs/sops-secret-management.md)
5. Deploy Backstage using `kubectl apply -k deploy-backstage/overlays/development/`
6. Set up Flux for GitOps automation
7. Add service templates to the catalog