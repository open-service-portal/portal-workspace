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
# git clone git@github.com:open-service-portal/template-golang-service.git
# git clone git@github.com:open-service-portal/template-nodejs-service.git
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

## 📚 Documentation

- [CLAUDE.md](./CLAUDE.md) - Development instructions for Claude Code
- [Docker Development](./docs/docker-development.md) - Building and running Backstage in Docker
- [GitHub App Setup](./docs/github-app-setup.md) - Configure GitHub authentication
- [SOPS Secret Management](./docs/sops-secret-management.md) - How we manage secrets securely
- [Local Kubernetes Setup](./docs/local-kubernetes-setup.md) - Setting up local Kubernetes with Crossplane
- [Troubleshooting Guide](./docs/troubleshooting/) - Common issues and solutions

## Local Development Environment

For local Kubernetes development:
```bash
# Run automated setup (requires kubectl, helm, etc.)
./scripts/setup-cluster.sh

# After setup, verify the cluster
kubectl get nodes
kubectl get pods -n crossplane-system

# Export kubeconfig if needed
kubectl config view --raw > kubeconfig.yaml
```
See [Local Kubernetes Setup](./docs/local-kubernetes-setup.md) for details.

## Note

This workspace parent directory is version controlled separately to maintain:
- Workspace-level documentation (this README, CLAUDE.md)
- Shared configurations
- Cross-repository scripts or tools
- Troubleshooting guides

The actual repository directories are excluded via `.gitignore`.