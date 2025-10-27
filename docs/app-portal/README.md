# app-portal Documentation

This directory contains documentation **specific to our app-portal Backstage implementation**.

## Contents

- `api-access.md` - Using the `backstage-api.sh` wrapper script
- `crossplane-ingestor.md` - Our Crossplane ingestor plugin implementation
- `kubernetes-ingestor.md` - Our Kubernetes ingestor plugin implementation
- `modular-config.md` - Our modular configuration architecture
- `secret-management.md` - Our SOPS-based secret management setup

## Scope

Documentation here should be:
- ✅ Specific to our app-portal implementation
- ✅ Our custom plugins and their usage
- ✅ Our configuration patterns and conventions
- ✅ Workspace-specific tools and scripts

Documentation here should NOT be:
- ❌ General Backstage documentation (belongs in `/docs/backstage/`)
- ❌ Kubernetes cluster setup (belongs in `/docs/cluster/`)
- ❌ Crossplane template development (belongs in template repos)

## See Also

- `/app-portal/` - The app-portal codebase
- `/app-portal/docs/` - Additional app-portal documentation in the codebase
- `/app-portal/CLAUDE.md` - Development guide for the app-portal
- `/docs/backstage/` - General Backstage documentation
