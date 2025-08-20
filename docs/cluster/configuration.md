# Cluster Configuration

This guide explains how to configure different Kubernetes clusters for local development and production environments after running the initial setup.

## Overview

After running `./scripts/setup-cluster.sh` (see [Cluster Setup](./setup.md)), you need to configure your cluster for the specific environment:

- **Local Development** - Uses mock DNS provider with localhost domain
- **OpenPortal Production** - Uses real Cloudflare provider with openportal.dev domain

The setup script installs everything with local defaults, so production environments need additional configuration.

## Environment Files

Create environment-specific `.env` files in the workspace root by copying the examples:

```bash
cp .env.local.example .env.local
cp .env.openportal.example .env.openportal
```

Then edit the `.env` files with your specific values.

- `.env.local` - Configuration for local development cluster
- `.env.openportal` - Configuration for OpenPortal production cluster

These files are gitignored and should not be committed.

## Configuration Scripts

### Local Development

```bash
./scripts/config-local.sh
```

Simply switches to the local Kubernetes context. The cluster already has default settings:
- Mock DNS provider for testing (set by setup-cluster.sh)
- DNS zone set to `localhost` (default)
- No external provider credentials needed

### OpenPortal Production

```bash
./scripts/config-openportal.sh
```

Configures the OpenPortal cluster with:
- Cloudflare DNS provider
- Real DNS zone (openportal.dev)
- Cloudflare API credentials
- Zone and Account IDs

## Required Environment Variables

### .env.local
```env
# Kubernetes Context
KUBE_CONTEXT=rancher-desktop
```

### .env.openportal
```env
# Kubernetes Context
KUBE_CONTEXT=openportal

# Cloudflare Configuration
CLOUDFLARE_USER_API_TOKEN=your-api-token  # User-scoped API token
CLOUDFLARE_ZONE_ID=your-zone-id           # From Cloudflare dashboard
CLOUDFLARE_ACCOUNT_ID=your-account-id     # From Cloudflare dashboard

# DNS Configuration
DNS_ZONE=openportal.dev
DNS_PROVIDER=cloudflare
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

The `setup-cluster.sh` script creates default EnvironmentConfigs suitable for local development:
- DNS zone: `localhost`
- DNS provider: `mock`

These defaults are defined in `scripts/manifests-setup-cluster/environment-configs.yaml`.

### Environment-Specific Configuration

1. **Local Development** (`config-local.sh`):
   - Simply switches kubectl context
   - Uses default EnvironmentConfigs from setup
   - No credentials needed

2. **OpenPortal Production** (`config-openportal.sh`):
   - Switches kubectl context
   - Creates Cloudflare credentials secret
   - Imports Cloudflare Zone resources
   - Updates EnvironmentConfigs with production values
   - Uses `set -a` to export variables for `envsubst`

### EnvironmentConfigs

EnvironmentConfigs are used by Crossplane compositions via `function-environment-configs` to:
- Determine which DNS provider to use
- Set the DNS zone for records
- Provide provider-specific configuration (zone IDs, account IDs)

## Notes

- Both scripts switch to the appropriate kubectl context automatically
- Configuration is applied to the `crossplane-system` namespace
- EnvironmentConfigs are used by Crossplane compositions to determine DNS behavior
- The Cloudflare Provider and ProviderConfig are installed by setup, only credentials are added later
- Manifests are organized in:
  - `scripts/manifests-setup-cluster/` - Infrastructure components
  - `scripts/manifests-config-openportal/` - Environment-specific configurations

## Cloudflare DNS Debugging

A comprehensive debug suite is available for testing Cloudflare DNS:

```bash
# Validate entire setup
./scripts/cloudflare/validate.sh

# Test XR creation with zoneIdRef
./scripts/cloudflare/test-xr.sh create
./scripts/cloudflare/test-xr.sh status
./scripts/cloudflare/test-xr.sh remove

# Complete cleanup
./scripts/cloudflare/remove.sh
```

See [Cloudflare Debug Suite](../../scripts/cloudflare/README.md) for details.

## Related Documentation

- [Platform Overview](./overview.md) - Architecture overview
- [Cluster Setup](./setup.md) - Initial cluster setup
- [Cluster Manifests](./manifests.md) - Manifest details and examples
- [Template Catalog Setup](./catalog-setup.md) - Template management