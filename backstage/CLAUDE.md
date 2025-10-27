# CLAUDE.md - Backstage Reference Repositories

This directory contains local clones of Backstage and plugin repositories for reference during development.

## Purpose

These repositories are **reference-only** clones to help with:
- Understanding Backstage architecture and patterns
- Finding documentation on auth providers, plugins, and systems
- Investigating how core plugins are implemented
- Learning from community plugin examples
- Deep diving into source code when documentation is unclear

## Repository Structure

```
backstage/
├── backstage/                   # Core Backstage (10,215 files)
│   ├── docs/                   # Official documentation
│   ├── plugins/                # Core plugin implementations
│   ├── packages/               # Core packages
│   └── ...
├── community-plugins/          # Community plugins (10,712 files)
│   ├── workspaces/            # 100+ plugin workspaces
│   └── docs/                  # Community documentation
├── terasky-backstage-plugins/ # TeraSky OSS plugins
│   └── plugins/               # Crossplane and other plugins
└── README.md                   # User documentation
```

## Plugins Used in app-portal

### Core Backstage Plugins (Frontend)

All located in `backstage/backstage/plugins/`:

| Plugin Package | Path in Repository |
|----------------|-------------------|
| `@backstage/plugin-api-docs` | `backstage/backstage/plugins/api-docs/` |
| `@backstage/plugin-catalog` | `backstage/backstage/plugins/catalog/` |
| `@backstage/plugin-catalog-graph` | `backstage/backstage/plugins/catalog-graph/` |
| `@backstage/plugin-catalog-import` | `backstage/backstage/plugins/catalog-import/` |
| `@backstage/plugin-catalog-react` | `backstage/backstage/plugins/catalog-react/` |
| `@backstage/plugin-kubernetes` | `backstage/backstage/plugins/kubernetes/` |
| `@backstage/plugin-notifications` | `backstage/backstage/plugins/notifications/` |
| `@backstage/plugin-org` | `backstage/backstage/plugins/org/` |
| `@backstage/plugin-search` | `backstage/backstage/plugins/search/` |
| `@backstage/plugin-signals` | `backstage/backstage/plugins/signals/` |
| `@backstage/plugin-techdocs` | `backstage/backstage/plugins/techdocs/` |
| `@backstage/plugin-user-settings` | `backstage/backstage/plugins/user-settings/` |

### Core Backstage Plugins (Backend)

All located in `backstage/backstage/plugins/`:

| Plugin Package | Path in Repository |
|----------------|-------------------|
| `@backstage/plugin-app-backend` | `backstage/backstage/plugins/app-backend/` |
| `@backstage/plugin-auth-backend` | `backstage/backstage/plugins/auth-backend/` |
| `@backstage/plugin-auth-backend-module-auth0-provider` | `backstage/backstage/plugins/auth-backend-module-auth0-provider/` |
| `@backstage/plugin-auth-backend-module-github-provider` | `backstage/backstage/plugins/auth-backend-module-github-provider/` |
| `@backstage/plugin-auth-backend-module-guest-provider` | `backstage/backstage/plugins/auth-backend-module-guest-provider/` |
| `@backstage/plugin-auth-backend-module-oidc-provider` | `backstage/backstage/plugins/auth-backend-module-oidc-provider/` ⭐ |
| `@backstage/plugin-catalog-backend` | `backstage/backstage/plugins/catalog-backend/` |
| `@backstage/plugin-catalog-backend-module-github` | `backstage/backstage/plugins/catalog-backend-module-github/` |
| `@backstage/plugin-catalog-backend-module-github-org` | `backstage/backstage/plugins/catalog-backend-module-github-org/` |
| `@backstage/plugin-catalog-backend-module-logs` | `backstage/backstage/plugins/catalog-backend-module-logs/` |
| `@backstage/plugin-catalog-backend-module-scaffolder-entity-model` | `backstage/backstage/plugins/catalog-backend-module-scaffolder-entity-model/` |
| `@backstage/plugin-kubernetes-backend` | `backstage/backstage/plugins/kubernetes-backend/` |
| `@backstage/plugin-notifications-backend` | `backstage/backstage/plugins/notifications-backend/` |
| `@backstage/plugin-permission-backend` | `backstage/backstage/plugins/permission-backend/` |
| `@backstage/plugin-permission-backend-module-allow-all-policy` | `backstage/backstage/plugins/permission-backend-module-allow-all-policy/` |
| `@backstage/plugin-proxy-backend` | `backstage/backstage/plugins/proxy-backend/` |
| `@backstage/plugin-scaffolder-backend` | `backstage/backstage/plugins/scaffolder-backend/` |
| `@backstage/plugin-scaffolder-backend-module-github` | `backstage/backstage/plugins/scaffolder-backend-module-github/` |
| `@backstage/plugin-scaffolder-backend-module-notifications` | `backstage/backstage/plugins/scaffolder-backend-module-notifications/` |
| `@backstage/plugin-search-backend` | `backstage/backstage/plugins/search-backend/` |
| `@backstage/plugin-search-backend-module-catalog` | `backstage/backstage/plugins/search-backend-module-catalog/` |
| `@backstage/plugin-search-backend-module-pg` | `backstage/backstage/plugins/search-backend-module-pg/` |
| `@backstage/plugin-search-backend-module-techdocs` | `backstage/backstage/plugins/search-backend-module-techdocs/` |
| `@backstage/plugin-signals-backend` | `backstage/backstage/plugins/signals-backend/` |
| `@backstage/plugin-techdocs-backend` | `backstage/backstage/plugins/techdocs-backend/` |

### TeraSky OSS Plugins

Located in `terasky-backstage-plugins/plugins/`:

| Plugin Package | Path in Repository |
|----------------|-------------------|
| `@terasky/backstage-plugin-crossplane-resources-frontend` | `terasky-backstage-plugins/plugins/crossplane-resources/` |
| `@terasky/backstage-plugin-scaffolder-backend-module-terasky-utils` | `terasky-backstage-plugins/plugins/scaffolder-backend-module-terasky-utils/` |

**Also available but not used**:
- `kubernetes-ingestor/` - Similar to our internal ingestor
- `kubernetes-resources/` - K8s resource management
- `kro-resources/` - Kubernetes Resource Orchestrator
- `kyverno-policy-reports/` - Policy compliance UI
- And 20+ more plugins

### Third-Party Plugins (Not Cloned)

| Plugin Package | Notes |
|----------------|-------|
| `@devangelista/backstage-scaffolder-kubernetes` | Published on npm only, no source in clones |
| `@open-service-portal/backstage-plugin-ingestor` | Our published plugin (source in `/app-portal/plugins/ingestor/`) |

### Quick Navigation Examples

```bash
# View OIDC provider source (for auth investigation)
cd backstage/backstage/plugins/auth-backend-module-oidc-provider
cat README.md

# View Kubernetes plugin implementation
cd backstage/backstage/plugins/kubernetes
ls src/

# Check TeraSky Crossplane plugin
cd terasky-backstage-plugins/plugins/crossplane-resources
cat README.md

# Compare with TeraSky K8s ingestor
cd terasky-backstage-plugins/plugins/kubernetes-ingestor
ls src/
```

## Key Investigation Areas

### For OIDC/Auth Provider Investigation

#### 1. Core Auth Documentation
```bash
# Auth provider setup docs
backstage/backstage/docs/auth/

# Specific providers
backstage/backstage/docs/auth/github/provider.md
backstage/backstage/docs/auth/oidc/provider.md
backstage/backstage/docs/auth/oauth2-custom/provider.md
```

#### 2. New Frontend System Documentation
```bash
# Frontend system architecture
backstage/backstage/docs/frontend-system/

# Extension system
backstage/backstage/docs/frontend-system/architecture/
```

#### 3. Core Plugin API Implementations
```bash
# OAuth2 implementation (generic)
backstage/backstage/packages/core-app-api/src/apis/implementations/OAuth2Api/

# Auth API definitions
backstage/backstage/packages/core-plugin-api/src/apis/definitions/auth.ts

# Frontend defaults (auto-registered APIs)
backstage/backstage/packages/frontend-defaults/
```

#### 4. Auth Backend Implementation
```bash
# Backend auth system
backstage/backstage/plugins/auth-backend/

# OIDC provider module
backstage/backstage/plugins/auth-backend-module-oidc-provider/

# OAuth2 provider base
backstage/backstage/plugins/auth-backend/src/providers/oauth2/
```

### For Plugin Development

#### Core Plugin Examples
```bash
# Standard plugins structure
backstage/backstage/plugins/catalog/
backstage/backstage/plugins/scaffolder/
backstage/backstage/plugins/kubernetes/
```

#### Community Plugin Examples
```bash
# Browse 100+ community plugins
community-plugins/workspaces/

# Each workspace has its own README and docs
community-plugins/workspaces/*/README.md
```

#### TeraSky Plugins
```bash
# Crossplane and utilities
terasky-backstage-plugins/plugins/crossplane-resources-frontend/
terasky-backstage-plugins/plugins/scaffolder-backend-module-terasky-utils/
```

## Common Search Tasks

### Finding Auth API References

```bash
# Search for all auth API refs
grep -r "AuthApiRef" backstage/backstage/packages/core-plugin-api/

# Find OIDC references
grep -r "oidc" backstage/backstage/packages/core-plugin-api/src/apis/definitions/

# Find OAuth2 implementation
find backstage/backstage/packages -name "*OAuth2*"
```

### Finding Extension Patterns

```bash
# Search for extension creation patterns
grep -r "createExtension" backstage/backstage/docs/

# Find ApiBlueprint usage
grep -r "ApiBlueprint" backstage/backstage/packages/

# Search for extension data usage
grep -r "coreExtensionData" backstage/backstage/packages/frontend-plugin-api/
```

### Finding Provider Registration Examples

```bash
# How GitHub provider is registered
grep -r "githubAuthApiRef" backstage/backstage/packages/

# Frontend defaults registration
grep -r "createApiFactory" backstage/backstage/packages/frontend-defaults/

# Check how providers are auto-discovered
grep -r "discoveryApi" backstage/backstage/packages/core-app-api/
```

### Understanding New Frontend System

```bash
# Read architecture docs
cat backstage/backstage/docs/frontend-system/architecture/01-introduction.md

# Check migration guide
cat backstage/backstage/docs/frontend-system/migration.md

# Find extension examples
find backstage/backstage/docs/frontend-system -name "*.md" | xargs grep -l "example"
```

## Investigation Workflow

### Phase 1: Documentation Reading

1. **Start with official docs**:
   ```bash
   # Read the specific auth provider docs
   cat backstage/backstage/docs/auth/oidc/provider.md

   # Check OAuth2 custom provider docs
   cat backstage/backstage/docs/auth/oauth2-custom/provider.md
   ```

2. **Read New Frontend System docs**:
   ```bash
   # List all frontend system docs
   ls backstage/backstage/docs/frontend-system/

   # Read extension system docs
   cat backstage/backstage/docs/frontend-system/architecture/*.md
   ```

### Phase 2: Source Code Investigation

1. **Find the implementation**:
   ```bash
   # Locate OAuth2 implementation
   find backstage/backstage/packages/core-app-api -name "*OAuth2*"

   # Read the source
   cat backstage/backstage/packages/core-app-api/src/apis/implementations/OAuth2Api/OAuth2.tsx
   ```

2. **Trace API definitions**:
   ```bash
   # Find all auth API definitions
   cat backstage/backstage/packages/core-plugin-api/src/apis/definitions/auth.ts

   # Check exports
   grep -r "export.*AuthApiRef" backstage/backstage/packages/
   ```

3. **Check default registrations**:
   ```bash
   # See what's in frontend-defaults
   ls backstage/backstage/packages/frontend-defaults/src/

   # Find API factories
   grep -r "ApiFactory" backstage/backstage/packages/frontend-defaults/
   ```

### Phase 3: Pattern Matching

1. **Find similar implementations**:
   ```bash
   # How does GitHub auth work?
   grep -r "githubAuthApiRef" backstage/backstage/packages/frontend-defaults/

   # Check Okta implementation
   grep -r "oktaAuthApiRef" backstage/backstage/packages/
   ```

2. **Check community examples**:
   ```bash
   # Search for custom auth in community plugins
   grep -r "createApiFactory" community-plugins/workspaces/

   # Find auth-related plugins
   ls community-plugins/workspaces/ | grep auth
   ```

## Key Files for OIDC Investigation

### Must Read Files

1. **Auth API Definitions**:
   - `backstage/packages/core-plugin-api/src/apis/definitions/auth.ts`
   - All standard auth API refs are defined here

2. **OAuth2 Implementation**:
   - `backstage/packages/core-app-api/src/apis/implementations/OAuth2Api/`
   - Generic OAuth2 flow implementation

3. **Frontend Defaults**:
   - `backstage/packages/frontend-defaults/src/`
   - Shows how standard providers are auto-registered

4. **Auth Backend OIDC Module**:
   - `backstage/plugins/auth-backend-module-oidc-provider/`
   - PKCE and OIDC backend implementation

5. **New Frontend System Extension API**:
   - `backstage/packages/frontend-plugin-api/src/extensions/`
   - Extension creation patterns

### Critical Questions to Answer

Use these files to answer:
- Q: Is there a standard `oidcAuthApiRef`?
  - Check: `backstage/packages/core-plugin-api/src/apis/definitions/auth.ts`

- Q: How does OAuth2.create() work?
  - Check: `backstage/packages/core-app-api/src/apis/implementations/OAuth2Api/OAuth2.tsx`

- Q: How are standard providers registered?
  - Check: `backstage/packages/frontend-defaults/src/`

- Q: What's the correct extension pattern for APIs?
  - Check: `backstage/packages/frontend-plugin-api/src/extensions/`
  - Check: `backstage/docs/frontend-system/`

- Q: Is PKCE frontend-transparent?
  - Check: `backstage/plugins/auth-backend-module-oidc-provider/`
  - Check: OAuth2Api implementation

## Useful Commands

### Quick Documentation Lookup

```bash
# Find all markdown docs mentioning OIDC
find backstage/backstage/docs -name "*.md" | xargs grep -l "OIDC"

# Search for specific API patterns
grep -r "createApiFactory" backstage/backstage/packages/ | head -20

# List all auth provider docs
ls backstage/backstage/docs/auth/*/provider.md
```

### Source Code Exploration

```bash
# Find all exports from core-plugin-api
grep -r "^export" backstage/backstage/packages/core-plugin-api/src/apis/

# List all auth-related packages
ls backstage/backstage/plugins/ | grep auth

# Check TypeScript definitions
find backstage/backstage/packages -name "*.d.ts" | xargs grep -l "AuthApi"
```

### Version Information

```bash
# Check Backstage version
cat backstage/backstage/package.json | grep version

# Check when repo was cloned (to know if update needed)
cd backstage/backstage && git log -1 --format="%ai"
```

## Updating Reference Repos

When Backstage releases new versions or you need latest docs:

```bash
# Update core
cd backstage/backstage
git fetch --depth 1
git reset --hard origin/master

# Update community plugins
cd ../community-plugins
git fetch --depth 1
git reset --hard origin/main

# Update TeraSky plugins
cd ../terasky-backstage-plugins
git fetch --depth 1
git reset --hard origin/main
```

## Notes

- All repositories are **shallow clones** (--depth 1) to save space
- These repos are **gitignored** in portal-workspace via `backstage/.gitignore`
- Only README.md, CLAUDE.md, and .gitignore are tracked in git
- Changes made to cloned repos will NOT be committed to portal-workspace
- Use these repos for **reading only**, not development
- For actual development, work in `/app-portal/`

### Git Structure

```
portal-workspace (tracked in git)
└── backstage/
    ├── .gitignore         ✅ Tracked in git
    ├── CLAUDE.md          ✅ Tracked in git
    ├── README.md          ✅ Tracked in git
    ├── backstage/         ❌ Ignored (20,000+ files)
    ├── community-plugins/ ❌ Ignored (10,000+ files)
    └── terasky-backstage-plugins/ ❌ Ignored (large repo)
```

Each developer must clone the reference repos locally (see README.md for commands).

## Related Documentation

- `/portal-workspace/CLAUDE.md` - Workspace overview
- `/app-portal/CLAUDE.md` - App development guide
- `/app-portal/docs/new-frontend-system-deep-dive-requirements.md` - OIDC investigation requirements
