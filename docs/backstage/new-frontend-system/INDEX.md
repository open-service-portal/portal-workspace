# Backstage New Frontend System - Comprehensive Guide

> **Version**: Backstage v1.42.0+
> **Status**: Complete Reference Documentation
> **Last Updated**: 2025-10-27

## Overview

This documentation provides a comprehensive guide to Backstage's **New Frontend System**, an extension-based architecture that replaces the legacy frontend system. It includes practical examples, patterns, and answers to common questions, with a specific focus on **auth provider registration** and **custom utility APIs**.

### Purpose

- **Developer Guide**: Help developers build plugins and apps with the new frontend system
- **Migration Reference**: Assist teams migrating from legacy to new frontend system
- **Auth Provider Focus**: Deep dive into custom auth provider registration (OIDC, OAuth2, PKCE)
- **Best Practices**: Extract patterns from Backstage core and community plugins

### Key Benefits of the New Frontend System

- **Extension-Based Architecture**: Modular, composable, and declarative
- **Automatic Plugin Discovery**: Install plugins via `package.json`, no manual imports
- **Configuration-Driven**: Override extensions via `app-config.yaml`
- **Better Separation of Concerns**: Clear boundaries between plugins, extensions, and APIs
- **Type-Safe**: Strong TypeScript support throughout

---

## 📚 Documentation Structure

### Core Concepts

1. **[Architecture Overview](./01-architecture.md)** ⭐ START HERE
   - Extension tree architecture
   - Building blocks (App, Extensions, Plugins, Utility APIs)
   - Data flow and extension inputs/outputs
   - Comparison with legacy system

2. **[App Creation & Configuration](./02-app-creation.md)**
   - Creating apps with `createApp()`
   - Feature discovery and installation
   - Plugin info resolution
   - App configuration patterns

3. **[Extensions Deep Dive](./03-extensions.md)**
   - Extension structure (ID, inputs, outputs, attachment points)
   - Creating extensions with `createExtension()`
   - Extension data references
   - Extension blueprints (PageBlueprint, ApiBlueprint, etc.)
   - Configuration schemas and factories

4. **[Utility APIs](./04-utility-apis.md)**
   - What are Utility APIs?
   - Creating API refs and implementations
   - Dependencies between APIs
   - Consuming APIs in components and extensions

5. **[Auth Providers & Custom APIs](./05-auth-providers.md)** ⭐ CRITICAL FOR OIDC/PKCE
   - Standard auth API refs (GitHub, GitLab, OIDC, OAuth2)
   - How OAuth2.create() works
   - Frontend/backend separation
   - PKCE transparency
   - Registering custom auth providers
   - API factory patterns

6. **[Plugin Development](./06-plugin-development.md)**
   - Plugin structure in new frontend system
   - Alpha exports (`/alpha`)
   - Creating frontend plugins with `createFrontendPlugin()`
   - Providing extensions from plugins
   - Plugin-to-plugin communication

7. **[Migration Guide](./07-migration.md)**
   - Legacy vs New frontend system
   - Phase 1: Hybrid configuration
   - Phase 2: Complete transition
   - Migrating specific components (SignInPage, Sidebar, Routes)
   - Troubleshooting common issues

---

## 💡 Practical Examples

All code examples are extracted from Backstage core and tested patterns:

### App Creation Examples
- [`examples/app-creation/basic-app.tsx`](../examples/app-creation/basic-app.tsx) - Minimal app setup
- [`examples/app-creation/feature-discovery.yaml`](../examples/app-creation/feature-discovery.yaml) - Automatic plugin discovery
- [`examples/app-creation/plugin-overrides.yaml`](../examples/app-creation/plugin-overrides.yaml) - Override plugin info

### Extension Examples
- [`examples/extensions/simple-extension.tsx`](../examples/extensions/simple-extension.tsx) - Basic extension
- [`examples/extensions/extension-with-inputs.tsx`](../examples/extensions/extension-with-inputs.tsx) - Parent/child extensions
- [`examples/extensions/extension-with-config.tsx`](../examples/extensions/extension-with-config.tsx) - Configuration schema
- [`examples/extensions/page-blueprint.tsx`](../examples/extensions/page-blueprint.tsx) - Using PageBlueprint

### Utility API Examples
- [`examples/utility-apis/creating-api-ref.ts`](../examples/utility-apis/creating-api-ref.ts) - Define API contract
- [`examples/utility-apis/api-implementation.tsx`](../examples/utility-apis/api-implementation.tsx) - Implement and register API
- [`examples/utility-apis/consuming-api.tsx`](../examples/utility-apis/consuming-api.tsx) - Use API in components

### Auth Provider Examples ⭐
- [`examples/auth-providers/custom-oidc-ref.ts`](../examples/auth-providers/custom-oidc-ref.ts) - Create custom OIDC API ref
- [`examples/auth-providers/custom-oidc-implementation.tsx`](../examples/auth-providers/custom-oidc-implementation.tsx) - Implement custom OIDC provider
- [`examples/auth-providers/oauth2-create-pattern.tsx`](../examples/auth-providers/oauth2-create-pattern.tsx) - How OAuth2.create() works

### Plugin Examples
- [`examples/plugins/simple-plugin.tsx`](../examples/plugins/simple-plugin.tsx) - Basic plugin with one page
- [`examples/plugins/plugin-with-api.tsx`](../examples/plugins/plugin-with-api.tsx) - Plugin providing utility API

---

## ❓ Requirements Questions & Answers

This section maps all questions from [`new-frontend-system-deep-dive-requirements.md`](../../../app-portal/docs/new-frontend-system-deep-dive-requirements.md) to their answers in the documentation.

### Category 1: Frontend/Backend Separation

#### ✅ Q1.1: Provider ID Mapping
**Question**: How does the frontend know which backend auth providers are available?

**Status**: ✅ ANSWERED

**Answer**:
- Frontend auth providers are **registered independently** from backend providers
- No automatic discovery of backend providers by the frontend
- Frontend creates auth API instances using `OAuth2.create()` with provider ID
- The provider ID must match between frontend API and backend authenticator
- Frontend makes requests to `/api/auth/{provider}/start` using the configured provider ID
- Backend responds based on registered provider routes

**Documentation**: See [05-auth-providers.md § Frontend/Backend Separation](./05-auth-providers.md#frontendbackend-separation)

**Example**: [`examples/auth-providers/frontend-backend-matching.tsx`](../examples/auth-providers/frontend-backend-matching.tsx)

---

#### ✅ Q1.2: OAuth2 Generic Implementation
**Question**: Is the `OAuth2.create()` implementation generic enough to work with any backend provider by name?

**Status**: ✅ ANSWERED

**Answer**:
- **YES**, `OAuth2.create()` is completely generic and provider-agnostic
- It only needs: configApi, discoveryApi, oauthRequestApi, and a provider ID
- The same OAuth2 class handles all OAuth2/OIDC flows (GitHub, Google, Okta, custom OIDC, etc.)
- Provider-specific logic is **backend-only** (scopes, client credentials, PKCE, etc.)
- Frontend only handles: popup flow, token storage, refresh logic

**Documentation**: See [05-auth-providers.md § OAuth2.create() Deep Dive](./05-auth-providers.md#oauth2create-deep-dive)

**Example**: [`examples/auth-providers/oauth2-create-pattern.tsx`](../examples/auth-providers/oauth2-create-pattern.tsx)

---

#### ✅ Q1.3: PKCE Transparency
**Question**: Is PKCE completely transparent to the frontend, handled entirely by the backend?

**Status**: ✅ ANSWERED

**Answer**:
- **YES**, PKCE is **100% backend-transparent to the frontend**
- Frontend code is **identical** for PKCE vs client secret flows
- `code_challenge` and `code_verifier` are generated and handled by backend only
- Frontend only sees: standard OAuth2 authorization code flow
- This confirms the hypothesis: **zero custom frontend code needed for PKCE**

**Documentation**: See [05-auth-providers.md § PKCE and Frontend Transparency](./05-auth-providers.md#pkce-and-frontend-transparency)

**Key Insight**: You can use the standard `oidcAuthApiRef` (or create a generic one) with a custom PKCE backend, requiring **no custom frontend auth code**.

---

### Category 2: Standard Auth Provider API References

#### ✅ Q2.1: OIDC Auth API Reference
**Question**: Does Backstage core provide a standard `oidcAuthApiRef`?

**Status**: ⚠️ PARTIALLY ANSWERED

**Answer**:
- **NO standard `oidcAuthApiRef`** exported from core packages (as of investigation)
- However, provider-specific refs exist: `oktaAuthApiRef`, `googleAuthApiRef`, `microsoftAuthApiRef`, etc.
- These all implement `OAuthApi`, `OpenIdConnectApi`, `ProfileInfoApi`, `BackstageIdentityApi`, and `SessionApi`
- **You can create your own generic `oidcAuthApiRef`** using the same pattern
- Or use a provider-specific ref (e.g., `oktaAuthApiRef`) even if your backend is custom OIDC

**Documentation**: See [05-auth-providers.md § Standard Auth API Refs](./05-auth-providers.md#standard-auth-api-refs)

**Example**: [`examples/auth-providers/custom-oidc-ref.ts`](../examples/auth-providers/custom-oidc-ref.ts)

---

#### ✅ Q2.2: Generic OAuth2 API Reference
**Question**: Is there a generic `oauth2AuthApiRef` that works with any OAuth2-compatible provider?

**Status**: ✅ ANSWERED

**Answer**:
- **NO generic `oauth2AuthApiRef`** exported, but easy to create
- All standard providers (GitHub, Google, Okta, etc.) use `OAuth2.create()` internally
- Pattern: Create custom API ref + use `OAuth2.create()` with your provider ID
- This is the recommended approach for custom OAuth2/OIDC providers

**Documentation**: See [05-auth-providers.md § Creating Custom Auth API Refs](./05-auth-providers.md#creating-custom-auth-api-refs)

**Example**: [`examples/auth-providers/generic-oauth2-ref.ts`](../examples/auth-providers/generic-oauth2-ref.ts)

---

### Category 3: How Standard Providers Work

#### ✅ Q3.1: GitHub Auth Registration
**Question**: How is `githubAuthApiRef` registered and made available in the New Frontend System?

**Status**: ✅ ANSWERED

**Answer**:
- Standard providers are registered in `@backstage/frontend-defaults`
- They are **automatically available** when using `createApp()` from `@backstage/frontend-defaults`
- Registration happens via API extensions created with `ApiBlueprint`
- Extensions attach to `core` extension's `apis` input
- No manual registration needed for standard providers (GitHub, Google, etc.)

**Documentation**: See [05-auth-providers.md § How Standard Providers Are Registered](./05-auth-providers.md#how-standard-providers-are-registered)

**File Reference**: `backstage/packages/frontend-defaults/src/` (see investigation report)

---

#### ✅ Q3.2: Default API Factories
**Question**: Does `@backstage/frontend-defaults` automatically register API factories for standard auth providers?

**Status**: ✅ ANSWERED

**Answer**:
- **YES**, `@backstage/frontend-defaults` includes default API factories
- Standard auth providers (GitHub, Google, Okta, etc.) are pre-registered
- Also includes: configApi, discoveryApi, storageApi, errorApi, and more
- This is why GitHub auth works "out of the box" without explicit registration
- Custom auth providers must be registered manually using `ApiBlueprint`

**Documentation**: See [04-utility-apis.md § Default Utility APIs](./04-utility-apis.md#default-utility-apis)

---

### Category 4: New Frontend System Extension Points

#### ✅ Q4.1: API Registration Extension Point
**Question**: What is the correct extension point for registering custom API implementations?

**Status**: ✅ ANSWERED

**Answer**:
- Use `ApiBlueprint.make()` to create API extensions
- API extensions attach to `core` extension's `apis` input automatically (handled by blueprint)
- Register via `createFrontendModule()` and add to app's `features` array
- **Pattern**:
  ```typescript
  const myApi = ApiBlueprint.make({
    name: 'my-api',
    params: {
      api: myApiRef,
      deps: { configApi: configApiRef },
      factory: ({ configApi }) => new MyApiImpl({ configApi }),
    },
  });

  const myModule = createFrontendModule({
    pluginId: 'app',
    extensions: [myApi],
  });

  createApp({ features: [myModule] });
  ```

**Documentation**: See [04-utility-apis.md § Registering Custom APIs](./04-utility-apis.md#registering-custom-apis)

**Example**: [`examples/utility-apis/api-registration-complete.tsx`](../examples/utility-apis/api-registration-complete.tsx)

---

#### ✅ Q4.2: Extension Data Types for APIs
**Question**: What is the correct way to use `coreExtensionData` for API factories?

**Status**: ✅ ANSWERED

**Answer**:
- **Don't use `coreExtensionData.apiFactory` directly** when using blueprints
- `ApiBlueprint` handles all extension data internally
- If using `createExtension()` directly (not recommended for APIs):
  - Import `apiFactoryDataRef` from `@backstage/frontend-plugin-api`
  - Return `[apiFactoryDataRef(factory)]` from factory function
- **Recommendation**: Always use `ApiBlueprint.make()` for APIs

**Documentation**: See [03-extensions.md § Extension Data References](./03-extensions.md#extension-data-references)

---

#### ✅ Q4.3: ApiBlueprint vs createExtension
**Question**: When should we use `ApiBlueprint.make()` vs `createExtension()` for API registration?

**Status**: ✅ ANSWERED

**Answer**:
- **ALWAYS use `ApiBlueprint.make()`** for Utility APIs
- `createExtension()` is low-level and requires manual extension data handling
- `ApiBlueprint` provides:
  - Correct attachment point (to `core/apis`)
  - Proper extension data output (apiFactoryDataRef)
  - Type safety and validation
  - Consistent naming patterns
- `createExtension()` is for advanced custom extension types only

**Documentation**: See [04-utility-apis.md § API Blueprints vs createExtension](./04-utility-apis.md#api-blueprints-vs-createextension)

---

### Category 5: Custom Auth Provider Support

#### ✅ Q5.1: Custom Provider Support Status
**Question**: Are custom auth providers officially supported in New Frontend System v1.42.0+?

**Status**: ✅ ANSWERED

**Answer**:
- **YES**, fully supported via `ApiBlueprint` pattern
- Same mechanism used internally for standard providers
- Well-documented pattern (though scattered across docs)
- Production-ready and stable
- Recommended approach: `ApiBlueprint.make()` + `OAuth2.create()`

**Documentation**: See [05-auth-providers.md § Custom Provider Support](./05-auth-providers.md#custom-provider-support)

---

#### ✅ Q5.2: Provider Override Pattern
**Question**: Can a custom backend module override a standard provider?

**Status**: ✅ ANSWERED

**Answer**:
- **YES**, through extension overrides
- Frontend: Create API extension with same ID as standard provider
- Backend: Register backend module with same provider ID
- Last-registered extension wins (frontend), modules extend backend
- Useful for: customizing GitHub scope, adding PKCE to OIDC, etc.

**Documentation**: See [05-auth-providers.md § Overriding Standard Providers](./05-auth-providers.md#overriding-standard-providers)

**Example**: [`examples/auth-providers/override-github-scopes.tsx`](../examples/auth-providers/override-github-scopes.tsx)

---

###Category 6: Migration Patterns

#### ✅ Q6.1: Legacy vs New Frontend Comparison
**Question**: What changed in auth provider registration between Legacy and New Frontend Systems?

**Status**: ✅ ANSWERED

**Answer**:

| Aspect | Legacy Frontend System | New Frontend System |
|--------|------------------------|---------------------|
| **Registration** | `createApiFactory()` in `apis.ts` | `ApiBlueprint.make()` in module |
| **Installation** | Pass to `createApp({ apis: [...] })` | Pass to `createApp({ features: [module] })` |
| **Location** | `packages/app/src/apis.ts` | `packages/app/src/modules/` or plugin |
| **Discovery** | Manual import required | Can use automatic discovery |
| **Override** | Replace in apis array | Extension override or feature order |
| **Configuration** | Code only | Can use app-config.yaml |

**Documentation**: See [07-migration.md § Migrating Auth Providers](./07-migration.md#migrating-auth-providers)

**Example**: [`examples/auth-providers/legacy-vs-new-comparison.tsx`](../examples/auth-providers/legacy-vs-new-comparison.tsx)

---

#### ✅ Q6.2: Missing Migration Documentation
**Question**: Is there migration documentation for custom auth providers specifically?

**Status**: ⚠️ PARTIALLY ANSWERED

**Answer**:
- **Limited official migration docs** for custom auth providers
- General migration guide covers API factories → ApiBlueprint pattern
- No specific "OIDC with PKCE" migration guide
- This documentation fills that gap
- Official docs focus on standard providers (GitHub, Google, etc.)

**Documentation**: This guide serves as the missing documentation

**See**: [07-migration.md § Auth Provider Migration Details](./07-migration.md#auth-provider-migration-details)

---

## 🎯 Key Takeaways

### For Custom OIDC/PKCE Implementation

1. **Backend and Frontend are Independent**
   - Register PKCE provider in backend module
   - Frontend uses standard OAuth2 flow (PKCE is transparent)
   - Provider IDs must match

2. **Minimal Frontend Code Required**
   - Create custom API ref (or use generic OIDC ref)
   - Use `OAuth2.create()` with provider ID
   - Register using `ApiBlueprint.make()`

3. **PKCE is Backend-Only**
   - No frontend changes needed for PKCE vs client secret
   - Frontend code is identical
   - Backend handles `code_challenge`, `code_verifier`, etc.

### General New Frontend System

1. **Extension-Based Everything**
   - Apps, plugins, pages, APIs, themes - all are extensions
   - Extensions form a tree structure
   - Configuration can override any extension

2. **Blueprints Simplify Common Patterns**
   - `ApiBlueprint` for utility APIs
   - `PageBlueprint` for pages
   - `SignInPageBlueprint` for sign-in pages
   - `ThemeBlueprint` for themes

3. **Feature Discovery Eliminates Boilerplate**
   - Add plugin to package.json
   - Enable `app.packages: all` in config
   - No manual imports needed

---

## 📖 Additional Resources

### Backstage Official Docs
- [Frontend System Architecture](../../backstage/backstage/docs/frontend-system/)
- [Plugin Development](../../backstage/backstage/docs/plugins/)
- [Auth Providers](../../backstage/backstage/docs/auth/)

### Source Code Reference
- Core Frontend Packages: `backstage/packages/frontend-*`
- Core Auth Implementation: `backstage/packages/core-app-api/src/apis/implementations/auth/`
- Frontend Defaults: `backstage/packages/frontend-defaults/`
- Auth Backend: `backstage/plugins/auth-backend/`
- OIDC Provider Module: `backstage/plugins/auth-backend-module-oidc-provider/`

### Community Resources
- [Backstage Discord](https://discord.gg/backstage-687207715902193673) - #support channel
- [GitHub Discussions](https://github.com/backstage/backstage/discussions)
- [GitHub Issues](https://github.com/backstage/backstage/issues)

---

## 🧪 Testing Examples

### Running Examples Locally

All examples can be tested by:
1. Creating a new Backstage app with `npx @backstage/create-app --next`
2. Copying example code into appropriate files
3. Running `yarn dev` to test

### Example Docker Setup (Bonus)

For quickly testing examples:

```bash
# Build a test image with Backstage v1.42.0+
docker build -t backstage-test -f Dockerfile.test .

# Run with example mounted
docker run -it -v $(pwd)/examples:/app/examples backstage-test

# Inside container
cd /app && yarn dev
```

See [`examples/README.md`](../examples/README.md) for Docker setup details.

---

## 🤝 Contributing

Found an error or want to improve the documentation?
1. Check existing issues: [GitHub Issues](https://github.com/open-service-portal/portal-workspace/issues)
2. Create a PR with your changes
3. Update the requirements tracking if you answer new questions

---

## 📅 Document Maintenance

- **Created**: 2025-10-27
- **Backstage Version**: v1.42.0+
- **Status**: Complete
- **Next Review**: When Backstage releases major frontend system changes

---

**Navigation**:
- [Next: Architecture Overview →](./01-architecture.md)
- [Jump to Auth Providers →](./05-auth-providers.md)
- [View Examples →](../examples/)
