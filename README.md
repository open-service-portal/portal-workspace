# Open Service Portal Workspace

This is a workspace directory containing multiple Open Service Portal repositories for unified development.

## Repository Structure

This workspace contains the following repositories:

### Core Application
- **[app-portal/](https://github.com/open-service-portal/app-portal)** - Main Backstage application

### Crossplane Templates & GitOps
- **[catalog/](https://github.com/open-service-portal/catalog)** - Template catalog (XRDs/Compositions definitions)
- **[catalog-orders/](https://github.com/open-service-portal/catalog-orders)** - XR instances created from Backstage templates
- **[template-dns-record/](https://github.com/open-service-portal/template-dns-record)** - DNS record management template
- **[template-cloudflare-dnsrecord/](https://github.com/open-service-portal/template-cloudflare-dnsrecord)** - Cloudflare DNS template
- **[template-whoami/](https://github.com/open-service-portal/template-whoami)** - Demo application template
- Additional templates to be added via catalog pattern

### Service Templates (Backstage)
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
- [Cluster Overview](./docs/cluster/overview.md) - Kubernetes cluster architecture
- [Cluster Setup](./docs/cluster/setup.md) - Set up Kubernetes locally with Crossplane
- [Catalog Setup](./docs/cluster/catalog-setup.md) - How to create and manage Crossplane templates
- [Configuration](./docs/cluster/configuration.md) - Environment and provider configuration
- [GitHub App Setup](./docs/backstage/github-app-setup.md) - Configure GitHub authentication
- [Secret Management](./docs/backstage/secret-management.md) - Managing secrets with SOPS

## Kubernetes Setup

### Prerequisites
- Kubernetes cluster (Kind, Rancher Desktop, Minikube, or cloud)
- kubectl configured
- Helm installed

### Automated Cluster Setup
```bash
# Run unified setup script for any Kubernetes cluster
./scripts/setup-cluster.sh

# This installs:
# - NGINX Ingress Controller
# - Flux GitOps with catalog watcher (for XRDs/Compositions)
# - Flux GitOps with catalog-orders watcher (for XR instances)
# - Crossplane v2.0 with namespaced XRs
# - Composition functions (go-templating, patch-and-transform, etc.)
# - Base environment configurations
# - provider-kubernetes with RBAC
# - provider-helm for chart deployments
# - provider-cloudflare for DNS management
# - Backstage service account + app-config.local.yaml
```

### Environment Configuration

The setup script automatically creates `app-portal/app-config.local.yaml` with Kubernetes credentials. For local development with self-signed certificates, uncomment `skipTLSVerify: true` in the generated config.

Configure your environment for local or production use:

```bash
# For local development
./scripts/config-local.sh

# For OpenPortal production (requires .env.openportal)
./scripts/config-openportal.sh
```

### Cloudflare DNS Management

For production DNS management with Cloudflare:

1. **Setup credentials** in `.env.openportal`:
   ```bash
   CLOUDFLARE_USER_API_TOKEN=your-api-token
   CLOUDFLARE_ZONE_ID=your-zone-id
   CLOUDFLARE_ACCOUNT_ID=your-account-id
   DNS_ZONE=your-domain.com
   ```

2. **Configure the cluster**:
   ```bash
   ./scripts/config-openportal.sh
   ```

3. **Validate the setup**:
   ```bash
   ./scripts/cloudflare/validate.sh
   ```

4. **Create DNS records** using Crossplane:
   ```yaml
   apiVersion: platform.io/v1alpha1
   kind: CloudflareDNSRecord
   metadata:
     name: my-app
   spec:
     type: A
     name: my-app
     value: "192.168.1.100"
     zone: openportal-zone  # References imported Zone
   ```

```bash
# For local development (uses mock DNS provider)
cp .env.local.example .env.local
# Edit .env.local with your local cluster context (e.g., rancher-desktop)
./scripts/config-local.sh

# For OpenPortal production (uses Cloudflare)
cp .env.openportal.example .env.openportal
# Edit .env.openportal with your Cloudflare credentials
./scripts/config-openportal.sh
```

**Configuration Scripts:**
- `config-local.sh` - Switches to local cluster, configures mock DNS for localhost
- `config-openportal.sh` - Switches to production, configures Cloudflare DNS and credentials

### Crossplane Templates
We use a GitOps catalog pattern for managing Crossplane templates:

1. **Create Template**: Follow the pattern in `template-dns-record/`
2. **Register in Catalog**: Add to `catalog/templates/`
3. **Flux Syncs**: Automatically discovers and installs templates
4. **Use Template**: Create XRs directly in your namespace (no claims needed!)

See [Crossplane Catalog Setup](./docs/crossplane-catalog-setup.md) for details.

## Key Features

### Crossplane v2 with Namespaced XRs
- Developers create XRs directly in their namespaces
- No need for separate claim resources
- Better namespace isolation and standard RBAC

### GitOps Everything
- Flux manages all deployments
- Central catalog for template discovery
- Git as single source of truth

### Modern Infrastructure as Code
- Pipeline mode compositions with functions
- Shared environment configurations
- Reusable transformation logic

## Note

This workspace parent directory is version controlled separately to maintain:
- Workspace-level documentation (this README, CLAUDE.md)
- Shared configurations and setup scripts
- Cross-repository documentation
- Unified cluster setup (`scripts/setup-cluster.sh`)

The actual repository directories are excluded via `.gitignore`.