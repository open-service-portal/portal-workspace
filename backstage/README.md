# Backstage Reference Repositories

This directory contains local clones of Backstage and related plugin repositories for reference and development.

## Structure

```
backstage/
├── backstage/                   # Backstage core repository
├── community-plugins/           # Backstage community plugins
├── terasky-backstage-plugins/   # TeraSky OSS plugins
├── CLAUDE.md                    # Claude Code guidance
└── README.md                    # This file
```

## Quick Setup

For deep investigation into Backstage internals, clone the source repositories:

```bash
cd backstage
git clone --depth 1 https://github.com/backstage/backstage.git
git clone --depth 1 https://github.com/backstage/community-plugins.git
git clone --depth 1 https://github.com/terasky-oss/backstage-plugins.git terasky-backstage-plugins
```

These provide access to:
- Core Backstage source code and documentation
- 100+ community plugins
- TeraSky OSS plugins

See `CLAUDE.md` in this directory for detailed guidance on investigating the source code.

**Note**: The cloned repositories are NOT included in git. Each developer must clone them locally.

## Repositories

### Backstage Core
- **Repository**: https://github.com/backstage/backstage
- **Clone Type**: Shallow (--depth 1)
- **Purpose**: Core Backstage documentation, architecture, and plugin development guides

**Key Documentation Paths**:
- `backstage/docs/` - Main documentation
- `backstage/docs/getting-started/` - Getting started guides
- `backstage/docs/auth/` - Authentication providers
- `backstage/docs/plugins/` - Plugin development
- `backstage/docs/backend-system/` - Backend system (New Backend System)
- `backstage/docs/frontend-system/` - Frontend system (New Frontend System)
- `backstage/docs/features/software-templates/` - Software templates
- `backstage/docs/features/kubernetes/` - Kubernetes integration
- `backstage/docs/features/techdocs/` - TechDocs platform

### Community Plugins
- **Repository**: https://github.com/backstage/community-plugins
- **Clone Type**: Shallow (--depth 1)
- **Purpose**: 100+ community-maintained plugins with documentation

**Key Areas**:
- `community-plugins/workspaces/*/` - Individual plugin workspaces
- `community-plugins/docs/` - Community plugin guides

### TeraSky OSS Plugins
- **Repository**: https://github.com/terasky-oss/backstage-plugins
- **Clone Type**: Shallow (--depth 1)
- **Purpose**: TeraSky's open-source Backstage plugins (30+ plugins)

**Key Plugins Used in app-portal**:
- `terasky-backstage-plugins/plugins/crossplane-resources/` - Crossplane UI
- `terasky-backstage-plugins/plugins/scaffolder-backend-module-terasky-utils/` - Scaffolder utilities

**Other Notable Plugins**:
- `kubernetes-ingestor/` - Kubernetes resource discovery
- `kubernetes-resources/` - Kubernetes resource management
- `kro-resources/` - Kubernetes Resource Orchestrator
- `kyverno-policy-reports/` - Policy compliance UI
- And 20+ more plugins (see `terasky-backstage-plugins/plugins/`)

## Usage

### Searching Documentation

```bash
# Search for auth provider documentation
grep -r "oidcAuthApiRef" backstage/

# Find specific plugin examples
find community-plugins/workspaces -name "README.md" | xargs grep -l "OAuth"

# Search for New Frontend System patterns
grep -r "createExtension" backstage/docs/
```

### Updating Repositories

```bash
# Update all repositories
cd backstage/backstage && git pull
cd ../community-plugins && git pull
cd ../terasky-backstage-plugins && git pull
```

### Finding Plugin Source Code

```bash
# Find a specific plugin
find backstage -name "*kubernetes*" -type d

# List all community plugins
ls community-plugins/workspaces/
```

## Plugins Used in app-portal

### Core Backstage Plugins
All standard plugins are in `backstage/plugins/`:
- `@backstage/plugin-catalog`
- `@backstage/plugin-scaffolder`
- `@backstage/plugin-kubernetes`
- `@backstage/plugin-techdocs`
- `@backstage/plugin-search`
- And many more...

### Community Plugins
Some plugins are in `community-plugins/workspaces/`:
- Check individual workspace directories for documentation

### Third-Party Plugins

**TeraSky OSS Plugins (Cloned)**:
- `@terasky/backstage-plugin-crossplane-resources-frontend` - Available in `terasky-backstage-plugins/`
- `@terasky/backstage-plugin-scaffolder-backend-module-terasky-utils` - Available in `terasky-backstage-plugins/`

**Other Third-Party (Not Cloned)**:
- `@devangelista/backstage-scaffolder-kubernetes` - Published on npm
- `@open-service-portal/backstage-plugin-ingestor` - Our published plugin

## Maintenance

This directory is **gitignored** via `backstage*/` pattern in the workspace root.

**Shallow clones** are used to:
- Reduce disk space usage
- Speed up clone time
- Focus on latest documentation

To update to the latest version:
```bash
cd backstage/backstage && git pull --depth 1
cd ../community-plugins && git pull --depth 1
```

## Related Documentation

See workspace-level documentation:
- `/portal-workspace/CLAUDE.md` - Workspace overview
- `/app-portal/CLAUDE.md` - App-portal specific documentation
- `/docs/` - Shared documentation and guides
