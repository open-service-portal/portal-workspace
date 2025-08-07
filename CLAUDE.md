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
- **app-portal/** - Main Backstage application (git@github.com-michaelstingl:open-service-portal/app-portal.git)
  - Scaffolded with `@backstage/create-app`
  - Contains frontend and backend packages
  - Configured for GitHub/GitLab integration

#### Service Templates
- **template-golang-service/** - Template for Go microservices
- **template-nodejs-service/** - Template for Node.js services
- **template-python-service/** - Template for Python services (planned)

#### Documentation
- **docs/** - Documentation website (planned)
- **portal-workspace/** - This workspace repository with meta-documentation

## Common Development Commands

### Backstage Application (app-portal/)

Start development server:
```bash
cd app-portal
yarn install
yarn dev
# Frontend: http://localhost:3000
# Backend API: http://localhost:7007
```

Build for production:
```bash
cd app-portal
yarn build:all
yarn build:backend
```

Run tests:
```bash
cd app-portal
yarn test
yarn test:all
```

Lint code:
```bash
cd app-portal
yarn lint
yarn lint:all
```

Create new plugin:
```bash
cd app-portal
yarn new
```

### Docker Operations

```bash
# Build Docker image
cd app-portal
yarn build-image

# Run with Docker Compose
docker-compose up -d
```

### Template Development

```bash
# Test template locally
cd template-golang-service
npx @backstage/cli template:install
npx @backstage/cli template:dry-run
```

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

## Troubleshooting

### Common Issues

1. **Port conflicts**
   - Frontend defaults to port 3000
   - Backend defaults to port 7007
   - Check for running processes: `lsof -i :3000`

2. **Node version mismatch**
   - Ensure Node.js 20 LTS is used
   - Use nvm to manage versions
   - Check `.nvmrc` file in repositories

3. **Authentication issues**
   - Verify GitHub/GitLab tokens are valid
   - Check token scopes (repo, read:org required)
   - Ensure tokens are properly exported

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

## SSH Configuration

For GitHub access with custom SSH config:
```
Host github.com-michaelstingl
  HostName github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
```

Use `git@github.com-michaelstingl:open-service-portal/repo.git` for cloning.

## Important Files

### Backstage Configuration
- `app-portal/app-config.yaml` - Base configuration
- `app-portal/app-config.production.yaml` - Production overrides
- `app-portal/app-config.local.yaml` - Local development (gitignored)

### Package Structure
```
app-portal/
├── packages/
│   ├── app/          # Frontend application
│   └── backend/      # Backend services
├── plugins/          # Custom plugins
└── app-config.yaml   # Configuration
```

### Template Structure
```
template-*/
├── template.yaml     # Template definition
├── skeleton/         # Template content
├── catalog-info.yaml # Component metadata
└── docs/            # Template documentation
```

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