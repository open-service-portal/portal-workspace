# Open Service Portal Workspace

This is a workspace directory containing multiple Open Service Portal repositories for unified development.

## Repository Structure

This workspace contains the following repositories:

- **[app-portal/](https://github.com/open-service-portal/app-portal)** - Main Backstage application
- **[template-golang-service/](https://github.com/open-service-portal/template-golang-service)** - Go service template
- **[template-nodejs-service/](https://github.com/open-service-portal/template-nodejs-service)** - Node.js service template
- **[docs/](https://github.com/open-service-portal/docs)** - Documentation site (future)

## Setup

To set up this workspace, clone each repository:

```bash
# Clone the workspace (this repository)
git clone git@github.com-michaelstingl:open-service-portal/portal-workspace.git open-service-portal
cd open-service-portal

# Clone individual repositories
git clone git@github.com-michaelstingl:open-service-portal/app-portal.git
# Clone additional repositories as needed
```

## Development

Each repository has its own development workflow. See [CLAUDE.md](./CLAUDE.md) for detailed development commands and architecture information.

### Quick Start

```bash
# Start Backstage
cd app-portal
yarn install
yarn dev
```

- Frontend: http://localhost:3000
- Backend API: http://localhost:7007

## Note

This workspace parent directory is version controlled separately to maintain:
- Workspace-level documentation (this README, CLAUDE.md)
- Shared configurations
- Cross-repository scripts or tools

The actual repository directories are excluded via `.gitignore`.