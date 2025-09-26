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
- **[template-cloudflare-dnsrecord/](https://github.com/open-service-portal/template-cloudflare-dnsrecord)** - DNS management via External-DNS
- **[template-whoami/](https://github.com/open-service-portal/template-whoami)** - Demo application template
- **[template-whoami-service/](https://github.com/open-service-portal/template-whoami-service)** - Composite service (app + DNS)

### Service Templates (Backstage)
- **[service-nodejs-template/](https://github.com/open-service-portal/service-nodejs-template)** - Node.js service template
- **[service-mongodb-template/](https://github.com/open-service-portal/service-mongodb-template)** - MongoDB database service
- **[service-mongodb-golden-path-template/](https://github.com/open-service-portal/service-mongodb-golden-path-template)** - MongoDB with best practices
- **[service-firewall-template/](https://github.com/open-service-portal/service-firewall-template)** - Network firewall rules
- **[service-dnsrecord-template/](https://github.com/open-service-portal/service-dnsrecord-template)** - DNS record management
- **[service-cluster-template/](https://github.com/open-service-portal/service-cluster-template)** - Kubernetes cluster provisioning

## Setup

To set up this workspace, clone each repository:

```bash
# Clone the workspace (this repository)
git clone git@github.com:open-service-portal/portal-workspace.git open-service-portal
cd open-service-portal

# Clone core application repository
git clone git@github.com:open-service-portal/app-portal.git

# Clone all repositories with the sync script
./scripts/repos-sync.sh
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
- [DNS Management](./docs/cluster/dns-management.md) - DNS management with External-DNS
- [Manifests](./docs/cluster/manifests.md) - Platform manifest documentation
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
./scripts/cluster-setup.sh

# This installs:
# - NGINX Ingress Controller
# - Flux GitOps with catalog watcher (for XRDs/Compositions)
# - Flux GitOps with catalog-orders watcher (for XR instances)
# - Crossplane v2.0 with namespaced XRs
# - Composition functions (go-templating, patch-and-transform, etc.)
# - Base environment configurations
# - provider-kubernetes with RBAC
# - provider-helm for chart deployments
# - External-DNS for DNS management (supports multiple providers)
# - Backstage service account + token
```

### Environment Configuration

Configure your cluster after setup:

```bash
# Option 1: Auto-detect cluster from kubectl context (recommended)
./scripts/cluster-config.sh

# The config script will:
# - Create Backstage configuration (app-config.{context}.local.yaml)
# - Configure External-DNS with Cloudflare credentials (if provided)
# - Update EnvironmentConfigs
# - Configure Flux to watch catalog-orders
```

For the generic `cluster-config.sh`, create an environment file matching your context:
```bash
# For rancher-desktop
cp .env.rancher-desktop.example .env.rancher-desktop
# Edit with your settings
vim .env.rancher-desktop
```

### DNS Management with External-DNS

We use External-DNS for DNS management, which supports namespace isolation and multiple DNS providers.

#### Setup

1. **Configure credentials** in your environment file:
   ```bash
   # For production (.env.openportal)
   CLOUDFLARE_API_TOKEN=your-api-token
   CLOUDFLARE_ZONE_ID=your-zone-id
   CLOUDFLARE_ZONE_NAME=openportal.dev
   
   # For local with real DNS (.env.rancher-desktop)
   BASE_DOMAIN=localhost              # For local app access
   CLOUDFLARE_API_TOKEN=your-token    # Optional: for real DNS
   CLOUDFLARE_ZONE_NAME=openportal.dev # Zone for DNS records
   ```

2. **Apply configuration**:
   ```bash
   ./scripts/config.sh  # Auto-detects cluster
   ```

#### Creating DNS Records

DNS records are created via CloudflareDNSRecord XRs or DNSEndpoint resources:

**Option 1: Using CloudflareDNSRecord XR (recommended)**
```yaml
apiVersion: openportal.dev/v1alpha1
kind: CloudflareDNSRecord
metadata:
  name: my-app
  namespace: my-namespace
spec:
  name: my-app
  type: A
  value: "192.168.1.100"
  ttl: 300
```

**Option 2: Direct DNSEndpoint**
```yaml
apiVersion: externaldns.openportal.dev/v1alpha1
kind: DNSEndpoint
metadata:
  name: my-app-dns
  namespace: my-namespace
spec:
  endpoints:
  - dnsName: my-app.openportal.dev
    recordType: A
    targets: ['192.168.1.100']
```

### Template Management

We provide scripts to manage Crossplane templates:

```bash
# Check status of all templates (releases and PRs)
./scripts/template-status.sh

# Reload all templates in the cluster
./scripts/template-reload.sh

# Create a new release for a template
./scripts/template-release.sh template-name
```

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

### Scripts Reference

### Cluster Management
- `cluster-setup.sh` - Universal K8s cluster setup with all platform components
- `cluster-config.sh` - Auto-detect and configure based on kubectl context
- `cluster-cleanup.sh` - Remove all platform components cleanly
- `cluster-kubeconfig.sh` - Extract and manage kubeconfig files

### Template Management
- `template-status.sh` - Check template releases and PR status
- `template-reload.sh` - Reload templates with finalizer handling
- `template-release.sh` - Automate GitHub releases for templates

### Repository Management
- `repos-sync.sh` - Clone/update all nested repositories

## Custom Plugins

The app-portal includes custom plugins:
- **kubernetes-ingestor** - Enhanced Kubernetes resource monitoring
- **scaffolder actions** - Custom actions for template processing

## Note

This workspace parent directory is version controlled separately to maintain:
- Workspace-level documentation (this README, CLAUDE.md)
- Shared configurations and setup scripts
- Cross-repository documentation
- Unified cluster setup and management scripts

The actual repository directories are excluded via `.gitignore`.