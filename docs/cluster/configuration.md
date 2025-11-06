# Cluster Configuration

This guide explains how to configure different Kubernetes clusters for local development and production environments after running the initial setup.

## Overview

After running `./scripts/cluster-setup.sh` (see [Cluster Setup](./setup.md)), you need to configure your cluster for the specific environment:

- **Local Development** - Uses External-DNS without credentials (dry-run mode)
- **OpenPortal Production** - Uses External-DNS with Cloudflare credentials

The setup script installs infrastructure components, then configuration scripts apply environment-specific settings.

## Configuration Methods

### Method 1: Auto-Detection (Recommended)

```bash
./scripts/cluster-config.sh
```

This script automatically:
- Detects current kubectl context
- Looks for `.env.${context}` file (e.g., `.env.rancher-desktop`)
- Creates `app-config.${context}.local.yaml` for Backstage
- Configures External-DNS with credentials if provided
- Updates EnvironmentConfigs

### Method 2: Specific Scripts

```bash
# For local development
./scripts/cluster-config-local.sh

# For OpenPortal production
./scripts/cluster-config-openportal.sh
```

## Environment Files

Environment files are named after kubectl contexts. Create them by copying examples:

```bash
# For rancher-desktop
cp .env.rancher-desktop.example .env.rancher-desktop

# For docker-desktop
cp .env.docker-desktop.example .env.docker-desktop

# For OpenPortal
cp .env.openportal.example .env.openportal
```

Then edit the files with your specific values. These files are gitignored and should not be committed.

## Required Environment Variables

### Local Development (.env.rancher-desktop)
```env
# Note: CLUSTER_NAME is auto-detected from kubectl context

# Base domain for applications
BASE_DOMAIN=localhost

# Optional: Enable real DNS via Cloudflare
# CLOUDFLARE_API_TOKEN=your-api-token
# CLOUDFLARE_ZONE_NAME=openportal.dev
```

### Production (.env.openportal)
```env
# Note: CLUSTER_NAME is auto-detected from kubectl context

# Base domain for applications
BASE_DOMAIN=openportal.dev

# Cloudflare Configuration
CLOUDFLARE_API_TOKEN=your-api-token       # API token with DNS edit permissions
CLOUDFLARE_ZONE_NAME=openportal.dev       # DNS zone to manage

# Legacy variables (for backward compatibility)
CLOUDFLARE_USER_API_TOKEN=${CLOUDFLARE_API_TOKEN}
CLOUDFLARE_ZONE_ID=your-zone-id           # From Cloudflare dashboard
CLOUDFLARE_ACCOUNT_ID=your-account-id     # From Cloudflare dashboard
```

## Usage

1. Create the appropriate `.env` file for your environment
2. Run the corresponding configuration script
3. The script will:
   - Load environment variables
   - Configure provider credentials (if needed)
   - Update DNS and provider configurations
   - Create necessary EnvironmentConfigs for Crossplane

## How It Works

### Default Configuration

The `cluster-setup.sh` script installs:
- External-DNS with custom CRDs (externaldns.openportal.dev)
- Default EnvironmentConfigs with BASE_DOMAIN
- Backstage service account and token

### Configuration Process

1. **Auto-detection** (`cluster-config.sh`):
   - Reads current kubectl context
   - Loads `.env.${context}` file
   - Creates Backstage config file
   - Configures External-DNS credentials
   - Updates EnvironmentConfigs

2. **External-DNS Configuration**:
   - Without credentials: Runs in dry-run mode (logs only)
   - With Cloudflare credentials: Creates real DNS records
   - Supports namespace isolation (records in any namespace)

### DNS Management

DNS records are managed through:
1. **CloudflareDNSRecord XR** → Creates DNSEndpoint
2. **DNSEndpoint resource** → Watched by External-DNS
3. **External-DNS controller** → Creates actual DNS records

See [DNS Management](./dns-management.md) for detailed information.

## Notes

- Configuration scripts can auto-detect kubectl context (no CLUSTER_NAME needed)
- External-DNS credentials go in `external-dns` namespace
- EnvironmentConfigs are used by Crossplane compositions
- Backstage config files use `.local.yaml` suffix for gitignore
- Manifests are organized in:
  - `scripts/manifests/setup/` - Infrastructure components
  - `scripts/manifests/config/` - Environment configurations

## Template Management

```bash
# Check template status and releases
./scripts/template-status.sh

# Reload templates after updates
./scripts/template-reload.sh
```

## Related Documentation

- [Platform Overview](./overview.md) - Architecture overview
- [Cluster Setup](./setup.md) - Initial cluster setup
- [DNS Management](./dns-management.md) - External-DNS configuration and usage
- [Cluster Manifests](./manifests.md) - Manifest details and examples
- [Template Catalog Setup](./catalog-setup.md) - Template management