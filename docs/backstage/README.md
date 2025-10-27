# Backstage Documentation

This directory contains **general Backstage documentation** that applies to any Backstage installation.

## Contents

- `github-app-setup.md` - Guide to setting up GitHub App integration for Backstage

## Scope

Documentation here should be:
- ✅ General Backstage setup and configuration guides
- ✅ Integration guides that work for any Backstage instance
- ✅ Best practices for Backstage architecture
- ✅ Reference documentation for Backstage features

Documentation here should NOT be:
- ❌ Specific to our app-portal implementation
- ❌ Our custom plugins or configurations
- ❌ Workspace-specific scripts or tools

## Backstage Source Code (Optional)

For deep investigation into Backstage internals, you can optionally clone the source repositories:

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

See `/backstage/CLAUDE.md` for detailed guidance on investigating the source code.

## See Also

- `/docs/app-portal/` - Documentation specific to our app-portal implementation
- `/app-portal/docs/` - App-portal codebase documentation
- `/backstage/` - Reference Backstage repositories for source code investigation
