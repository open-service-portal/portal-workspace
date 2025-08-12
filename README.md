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

#### Zero-Config Frontend Development

For immediate frontend development without any configuration:

```bash
cd app-portal
yarn install
yarn dev  # No tokens or secrets needed!
```

This starts Backstage with mock data and guest authentication - perfect for UI/theme development.

#### Full Development Setup

For complete functionality with GitHub integration:

```bash
# Start Backstage with full features
cd app-portal
yarn install
# Configure your .envrc with tokens (see docs/github-app-setup.md)
yarn start
```

- Frontend: http://localhost:3000
- Backend API: http://localhost:7007

## Documentation

- [CLAUDE.md](./CLAUDE.md) - Development instructions for Claude Code
- [GitHub App Setup](./docs/github-app-setup.md) - Configure GitHub authentication
- [Rancher Desktop Setup](./docs/rancher-desktop-setup.md) - Local Kubernetes with Rancher Desktop
- [Troubleshooting Guide](./docs/troubleshooting/) - Common issues and solutions

## Local Development Environment

**Rancher Desktop:**
```bash
# Run automated setup
./scripts/setup-rancher-k8s.sh

# After setup, access the cluster
kubectl config use-context rancher-desktop
kubectl get nodes

# Export kubeconfig if needed
kubectl config view --raw > rancher-kubeconfig.yaml
```
See [Rancher Desktop Setup Guide](./docs/rancher-desktop-setup.md) for details.

## Note

This workspace parent directory is version controlled separately to maintain:
- Workspace-level documentation (this README, CLAUDE.md)
- Shared configurations
- Cross-repository scripts or tools
- Troubleshooting guides

The actual repository directories are excluded via `.gitignore`.