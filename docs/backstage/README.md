# Backstage Documentation

This directory contains **general Backstage documentation** that applies to any Backstage installation.

## Contents

### Guides
- **[github-app-setup.md](./github-app-setup.md)** - Guide to setting up GitHub App integration for Backstage

### New Frontend System Documentation
- **[new-frontend-system/](./new-frontend-system/)** - Complete guide to Backstage's new frontend system (v1.42.0+)
  - 7 comprehensive documentation files (6,900+ lines)
  - 15 working code examples
  - Extension architecture, plugins, APIs, migration
  - See [new-frontend-system/INDEX.md](./new-frontend-system/INDEX.md) to get started

### Examples
- **[examples/](./examples/)** - Practical code examples for the new frontend system
  - App creation examples
  - Extension examples (simple, with inputs, with config)
  - Auth provider examples (OIDC, OAuth2)
  - Utility API examples
  - Plugin examples

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

## Documentation Research Process

Much of the documentation in this directory (especially [new-frontend-system/](./new-frontend-system/)) was created by deep-diving into Backstage source code. Here's how to use the local Backstage repositories for documentation research:

### 1. Source Code Reference

The [/backstage/](https://github.com/open-service-portal/portal-workspace/tree/main/backstage) directory in this workspace contains local clones of:
- **Backstage core** - Official source code and documentation
- **Community plugins** - 100+ community plugin implementations
- **TeraSky plugins** - Additional plugin examples

These repositories are **not tracked in git** (gitignored), so each developer must clone them locally. See [/backstage/README.md](../../backstage/README.md) for setup instructions.

### 2. Research Workflow

When creating documentation for Backstage features:

#### Phase 1: Read Official Documentation
```bash
# Start with official docs
cat /path/to/workspace/backstage/backstage/docs/frontend-system/architecture/*.md

# Check specific feature docs
ls backstage/backstage/docs/auth/
ls backstage/backstage/docs/plugins/
```

#### Phase 2: Investigate Source Code
```bash
# Find implementation details
find backstage/backstage/packages -name "*OAuth2*"

# Read actual implementation
cat backstage/backstage/packages/core-app-api/src/apis/implementations/OAuth2Api/OAuth2.tsx

# Check how standard providers are registered
grep -r "githubAuthApiRef" backstage/backstage/packages/frontend-defaults/
```

#### Phase 3: Extract Patterns
```bash
# Find examples in core plugins
ls backstage/backstage/plugins/catalog/src/

# Check community plugin patterns
find backstage/community-plugins/workspaces -name "README.md" | xargs grep -l "createFrontendPlugin"

# Verify TypeScript types
find backstage/backstage/packages -name "*.d.ts" | xargs grep -l "ApiBlueprint"
```

#### Phase 4: Create Documentation
1. **Verify accuracy** - Compare documentation claims with actual source code
2. **Extract code examples** - Use real patterns from Backstage source
3. **Test examples** - Ensure examples actually work
4. **Document edge cases** - Note any special behaviors found in source

### 3. Key Investigation Areas

For different documentation topics:

**Architecture & Extensions**:
- `/backstage/backstage/packages/frontend-plugin-api/` - Extension API
- `/backstage/backstage/packages/frontend-app-api/` - App implementation
- `/backstage/backstage/docs/frontend-system/` - Architecture docs

**Auth Providers**:
- `/backstage/backstage/plugins/auth-backend/` - Backend auth system
- `/backstage/backstage/packages/core-app-api/src/apis/implementations/` - Frontend OAuth2
- `/backstage/backstage/docs/auth/` - Auth provider docs

**Plugin Development**:
- `/backstage/backstage/plugins/` - Core plugin examples
- `/backstage/community-plugins/workspaces/` - Community examples
- `/backstage/backstage/docs/plugins/` - Plugin development guides

**Utility APIs**:
- `/backstage/backstage/packages/core-plugin-api/src/apis/` - API definitions
- `/backstage/backstage/packages/frontend-defaults/src/` - Default registrations

### 4. Example: How new-frontend-system/ Docs Were Created

The comprehensive [new-frontend-system/](./new-frontend-system/) documentation was created using this process:

1. **Started with requirements** - Identified questions that needed answers (e.g., "How does OAuth2.create() work?")
2. **Read official docs** - Started with `/backstage/backstage/docs/frontend-system/`
3. **Source code investigation** - Traced implementation in packages like `frontend-plugin-api`, `core-app-api`
4. **Pattern extraction** - Found how standard providers like GitHub are registered
5. **Example creation** - Created working examples based on real patterns
6. **Verification** - Tested examples and verified against source code
7. **Documentation** - Wrote comprehensive guides with code examples

**Result**: 7 documentation files (6,900+ lines) + 15 code examples extracted from Backstage source.

### 5. Tools for Investigation

**Search for patterns**:
```bash
# Find all uses of a pattern
grep -r "createFrontendPlugin" backstage/backstage/

# Find TypeScript definitions
find backstage/backstage/packages -name "*.d.ts" | xargs grep "ApiBlueprint"

# Search documentation
find backstage/backstage/docs -name "*.md" | xargs grep -l "extension"
```

**Navigate source**:
```bash
# List all frontend packages
ls backstage/backstage/packages/frontend-*/

# Browse plugin implementations
ls backstage/backstage/plugins/

# Check community examples
ls backstage/community-plugins/workspaces/
```

**Check versions**:
```bash
# See what version of Backstage you're referencing
cat backstage/backstage/package.json | grep version

# Check when clones were last updated
cd backstage/backstage && git log -1 --format="%ai"
```

### 6. Best Practices

When using source code for documentation:

✅ **DO**:
- Start with official docs, use source to verify and expand
- Extract real patterns from working code
- Test examples before documenting
- Note version compatibility (e.g., "Backstage v1.42.0+")
- Link to source files when referencing implementation details

❌ **DON'T**:
- Copy code verbatim without understanding
- Document internal/private APIs that may change
- Assume patterns without verifying in source
- Document without testing

### 7. Contributing Back

Knowledge extracted from Backstage source code can be:
- **Documented locally** - Like the new-frontend-system/ docs
- **Shared with community** - Via blog posts, talks, or contributions
- **Contributed upstream** - Backstage welcomes documentation improvements

## See Also

- `/docs/app-portal/` - Documentation specific to our app-portal implementation
- `/app-portal/docs/` - App-portal codebase documentation
- `/backstage/` - Reference Backstage repositories for source code investigation
