# Open Service Portal Workspace

This is a workspace directory containing multiple Open Service Portal repositories for unified development.

## Repository Structure

This workspace contains the following repositories:

- **[app-portal/](https://github.com/open-service-portal/app-portal)** - Main Backstage application
- **[service-nodejs-template/](https://github.com/open-service-portal/service-nodejs-template)** - Node.js service template
- **service-golang-template/** - Go service template (planned)
- **service-python-template/** - Python service template (planned)

## Setup

To set up this workspace, clone each repository:

```bash
# Clone the workspace (this repository)
git clone git@github.com:open-service-portal/portal-workspace.git open-service-portal
cd open-service-portal

# Clone individual repositories
git clone git@github.com:open-service-portal/app-portal.git

# Future: Clone templates when created
# git clone git@github.com:open-service-portal/service-nodejs-template.git
# git clone git@github.com:open-service-portal/service-golang-template.git
```

## Development

Each repository has its own development workflow. See [CLAUDE.md](./CLAUDE.md) for detailed development commands and architecture information.

### Quick Start

```bash
# Start Backstage
cd app-portal
yarn install
yarn start
```

- Frontend: http://localhost:3000
- Backend API: http://localhost:7007

## Documentation

- [CLAUDE.md](./CLAUDE.md) - Development instructions for Claude Code
- [GitHub App Setup](./docs/github-app-setup.md) - Configure GitHub authentication
- [Local Kubernetes Setup](./docs/local-kubernetes-setup.md) - Set up Kubernetes locally
- [Troubleshooting Guide](./docs/troubleshooting/) - Common issues and solutions

## Kubernetes Setup

### Prerequisites
- Kubernetes cluster (Kind, Rancher Desktop, Minikube, or cloud)
- kubectl configured
- Helm installed

### Cluster Setup
```bash
# Run unified setup script for any Kubernetes cluster
./scripts/setup-cluster.sh

# This installs:
# - NGINX Ingress Controller
# - Flux GitOps
# - SOPS for secret management
# - Crossplane v1.17
# - Backstage service account
```

### Secret Management
SOPS is used for encrypting secrets in Git repositories. See [SOPS Secret Management](./docs/sops-secret-management.md) for details.

## Note

This workspace parent directory is version controlled separately to maintain:
- Workspace-level documentation (this README, CLAUDE.md)
- Shared configurations
- Cross-repository scripts or tools
- Troubleshooting guides

The actual repository directories are excluded via `.gitignore`.