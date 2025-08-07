# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Workspace Structure

This workspace contains all Open Service Portal repositories for unified Backstage development.

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

#### Service Templates (Planned)
- **template-golang-service/** - Template for Go microservices (planned)
- **template-nodejs-service/** - Template for Node.js services (planned)
- **template-python-service/** - Template for Python services (planned)

#### Documentation
- **docs/** - Documentation website (planned)
- **portal-workspace/** - This workspace repository with meta-documentation

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
- **Orchestration**: Kubernetes (optional)

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
2. Include comprehensive documentation
3. Add TechDocs support
4. Include catalog-info.yaml

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
- GitOps workflow with ArgoCD/Flux
- Kubernetes-native service definitions

## Best Practices

1. **Version Control**
   - Keep workspace repositories in sync
   - Use semantic versioning for releases
   - Tag stable versions

2. **Security**
   - Never commit secrets or tokens
   - Use environment variables for sensitive data
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

### GitHub CLI Workflow

Use GitHub CLI for efficient workflow:

```bash
# Create issue
gh issue create --repo open-service-portal/app-portal \
  --title "Add new feature" \
  --body "Description of the feature"

# Create PR
gh pr create --repo open-service-portal/app-portal \
  --title "feat: add new feature" \
  --body "Implements #123"

# Check PR status
gh pr status --repo open-service-portal/app-portal
```


## Workspace Conventions

### Repository Naming
- `app-*` - Applications (e.g., app-portal)
- `template-*` - Service templates
- `plugin-*` - Shared Backstage plugins (future)
- `docs` - Documentation site

### Documentation Structure
Each repository should contain:
- `README.md` - Quick start and overview
- `CLAUDE.md` - Detailed development instructions for Claude Code
- `docs/` - Extended documentation (if needed)

## Key Patterns

1. **Service Discovery**: Use Backstage Software Catalog
2. **Authentication**: GitHub/GitLab OAuth
3. **Templates**: Scaffolder for service creation
4. **Documentation**: TechDocs with MkDocs
5. **Deployment**: GitOps workflow with Kubernetes

## Next Steps

1. Clone and set up app-portal
2. Configure authentication providers
3. Add service templates
4. Set up CI/CD pipelines
5. Deploy to Kubernetes cluster