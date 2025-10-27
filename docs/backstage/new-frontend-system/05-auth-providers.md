# Auth Providers & Custom APIs

> **Critical Documentation for OIDC/PKCE Implementation**
>
> This guide answers all auth provider questions from the deep dive requirements, focusing on custom OIDC with PKCE implementation.

## Table of Contents

- [Overview](#overview)
- [Standard Auth API Refs](#standard-auth-api-refs)
- [OAuth2.create() Deep Dive](#oauth2create-deep-dive)
- [Frontend/Backend Separation](#frontendbackend-separation)
- [PKCE and Frontend Transparency](#pkce-and-frontend-transparency)
- [Creating Custom Auth API Refs](#creating-custom-auth-api-refs)
- [Registering Custom Auth Providers](#registering-custom-auth-providers)
- [How Standard Providers Are Registered](#how-standard-providers-are-registered)
- [Overriding Standard Providers](#overriding-standard-providers)
- [Complete OIDC/PKCE Example](#complete-oidcpkce-example)
- [Troubleshooting](#troubleshooting)

---

## Overview

### Key Concepts

**Auth API References**: TypeScript interfaces + API refs that define auth provider contracts
- Example: `githubAuthApiRef`, `googleAuthApiRef`, `oktaAuthApiRef`
- Created using `createApiRef<T>({ id: 'auth.provider-name' })`

**OAuth2 Implementation**: Generic OAuth2/OIDC flow handler (`OAuth2.create()`)
- Used by **all** standard providers internally
- Completely provider-agnostic
- Handles: popup flow, token caching, auto-refresh, nonce/CSRF protection

**API Extensions**: Extensions that provide Utility API implementations
- Created using `ApiBlueprint.make()`
- Attach to `core` extension's `apis` input
- Can have dependencies on other APIs

### Critical Insight for OIDC/PKCE

**PKCE is 100% backend-transparent** to the frontend. The frontend OAuth2 flow is **identical** whether the backend uses:
- PKCE (public client)
- Client secret (confidential client)
- Any other OAuth2 variation

This means: **You can use a standard or generic OIDC auth API ref with your custom PKCE backend, requiring ZERO custom frontend code.**

---

## Standard Auth API Refs

### Available in `@backstage/core-plugin-api`

Location: `backstage/packages/core-plugin-api/src/apis/definitions/auth.ts`

```typescript
// All standard auth API refs
export const githubAuthApiRef: ApiRef<OAuthApi & ProfileInfoApi & BackstageIdentityApi & SessionApi>;
export const gitlabAuthApiRef: ApiRef<OAuthApi & OpenIdConnectApi & ProfileInfoApi & BackstageIdentityApi & SessionApi>;
export const googleAuthApiRef: ApiRef<OAuthApi & OpenIdConnectApi & ProfileInfoApi & BackstageIdentityApi & SessionApi>;
export const oktaAuthApiRef: ApiRef<OAuthApi & OpenIdConnectApi & ProfileInfoApi & BackstageIdentityApi & SessionApi>;
export const microsoftAuthApiRef: ApiRef<OAuthApi & OpenIdConnectApi & ProfileInfoApi & BackstageIdentityApi & SessionApi>;
export const oneloginAuthApiRef: ApiRef<OAuthApi & OpenIdConnectApi & ProfileInfoApi & BackstageIdentityApi & SessionApi>;
export const bitbucketAuthApiRef: ApiRef<OAuthApi & ProfileInfoApi & BackstageIdentityApi & SessionApi>;
export const bitbucketServerAuthApiRef: ApiRef<OAuthApi & ProfileInfoApi & BackstageIdentityApi & SessionApi>;
export const atlassianAuthApiRef: ApiRef<OAuthApi & ProfileInfoApi & BackstageIdentityApi & SessionApi>;
export const vmwareCloudAuthApiRef: ApiRef<OAuthApi & OpenIdConnectApi & ProfileInfoApi & BackstageIdentityApi & SessionApi>;
```

### Important Findings

1. **No generic `oidcAuthApiRef`** exists in core packages
2. **No generic `oauth2AuthApiRef`** exists in core packages
3. All OIDC-compatible providers include `OpenIdConnectApi`
4. You can **create your own** using the same pattern

### Interface Definitions

```typescript
/**
 * Core OAuth2/OIDC interfaces from @backstage/core-plugin-api
 */

export interface OAuthApi {
  getAccessToken(scope?: string): Promise<string>;
}

export interface OpenIdConnectApi {
  getIdToken(): Promise<string>;
}

export interface ProfileInfoApi {
  getProfile(): Promise<ProfileInfo>;
}

export interface BackstageIdentityApi {
  getBackstageIdentity(): Promise<BackstageIdentity>;
  getCredentials(): Promise<{ token?: string }>;
}

export interface SessionApi {
  signIn(): Promise<void>;
  signOut(): Promise<void>;
  sessionState$(): Observable<SessionState>;
}
```

---

## OAuth2.create() Deep Dive

### Source Code

Location: `backstage/packages/core-app-api/src/apis/implementations/auth/oauth2/OAuth2.ts`

### How It Works

The `OAuth2` class is a **generic implementation** that handles all OAuth2/OIDC flows:

```typescript
/**
 * Simplified representation of OAuth2 class structure
 */
class OAuth2 implements OAuthApi, OpenIdConnectApi, ProfileInfoApi, BackstageIdentityApi, SessionApi {
  private constructor(
    private readonly connector: DefaultAuthConnector,
    private readonly sessionManager: RefreshingAuthSessionManager,
    private readonly oauthRequestApi: OAuthRequestApi,
  ) {}

  static create(options: {
    configApi: ConfigApi;
    discoveryApi: DiscoveryApi;
    oauthRequestApi: OAuthRequestApi;
    environment?: string;
    provider: {
      id: string;  // e.g., 'github', 'oidc-pkce', 'my-custom-oidc'
      title: string;
      icon: ComponentType<{}>;
    };
    defaultScopes?: string[];
    scopeTransform?: (scopes: string[]) => string[];
  }): OAuthApi & OpenIdConnectApi & ProfileInfoApi & BackstageIdentityApi & SessionApi {
    // 1. Read environment-specific config
    const { baseUrl, callbackUrl } = readEnvConfig(options.configApi, options.provider.id, options.environment);

    // 2. Create auth connector (handles OAuth popup flow)
    const connector = new DefaultAuthConnector({
      discoveryApi: options.discoveryApi,
      environment: options.environment,
      provider: options.provider,
      oauthRequestApi: options.oauthRequestApi,
      baseUrl,
      callbackUrl,
    });

    // 3. Create session manager (handles token caching, refresh)
    const sessionManager = new RefreshingAuthSessionManager({
      connector,
      defaultScopes: new Set(options.defaultScopes || []),
      scopeTransform: options.scopeTransform,
      sessionScopes: () => ({...}),
    });

    // 4. Return OAuth2 instance
    return new OAuth2(connector, sessionManager, options.oauthRequestApi);
  }

  async getAccessToken(scope?: string): Promise<string> {
    const session = await this.sessionManager.getSession({ scopes: scope ? [scope] : [] });
    return session.accessToken;
  }

  async getIdToken(): Promise<string> {
    const session = await this.sessionManager.getSession({ optional: true });
    return session?.idToken || '';
  }

  // ... implements all interfaces
}
```

### Key Points

1. **Provider-Agnostic**: Only needs provider ID to construct backend URLs
2. **No Provider Logic**: Doesn't know about PKCE, client secrets, specific scopes, etc.
3. **Backend Endpoints**: Constructs URLs like `/api/auth/{provider}/start`, `/api/auth/{provider}/refresh`
4. **Token Management**: Automatic refresh when < 3 minutes to expiry
5. **Security**: Nonce and CSRF protection built-in

### What OAuth2.create() Does NOT Do

- ❌ Generate code_challenge (PKCE)
- ❌ Send client_secret
- ❌ Validate scopes
- ❌ Know about provider-specific features
- ❌ Interact directly with provider (Google, GitHub, etc.)

### What OAuth2.create() DOES Do

- ✅ Open OAuth popup window
- ✅ Handle authorization code flow
- ✅ Cache tokens in browser storage
- ✅ Auto-refresh tokens before expiry
- ✅ Provide typed access to tokens (access token, ID token)
- ✅ Manage sign-in/sign-out state

---

## Frontend/Backend Separation

### How Frontend Discovers Backend Providers

**Answer**: It doesn't. Frontend and backend auth providers are registered independently.

### Frontend Auth Flow

```
1. User clicks "Sign in with OIDC"
2. Frontend calls myCustomOidcApi.signIn()
3. OAuth2 instance opens popup: /api/auth/oidc-pkce/start?scope=openid
4. Backend receives request, recognizes 'oidc-pkce' provider
5. Backend generates code_challenge (PKCE), redirects to IdP
6. User authenticates at IdP
7. IdP redirects to backend callback: /api/auth/oidc-pkce/handler/frame
8. Backend exchanges code + code_verifier for tokens (PKCE)
9. Backend returns tokens to popup
10. Frontend OAuth2 stores tokens, closes popup
11. Frontend app is now authenticated
```

### Key Point: Provider ID Must Match

```typescript
// Frontend: Create API with provider ID
const oidcPkceApi = ApiBlueprint.make({
  params: {
    factory: createApiFactory({
      api: customOidcApiRef,
      deps: { configApi: configApiRef, discoveryApi: discoveryApi, oauthRequestApi: oauthRequestApiRef },
      factory: ({ configApi, discoveryApi, oauthRequestApi }) =>
        OAuth2.create({
          configApi,
          discoveryApi,
          oauthRequestApi,
          provider: {
            id: 'oidc-pkce',  // ← Must match backend
            title: 'OIDC with PKCE',
            icon: () => null,
          },
        }),
    }),
  },
});
```

```typescript
// Backend: Register provider with matching ID
backend.add(
  createBackendModule({
    pluginId: 'auth',
    moduleId: 'oidc-pkce',
    register(reg) {
      reg.registerInit({
        deps: { /* ... */ },
        async init({ /* ... */ }) {
          authProviders.registerProvider({
            providerId: 'oidc-pkce',  // ← Must match frontend
            factory: createOAuthProviderFactory({
              authenticator: oidcPkceAuthenticator,  // Custom PKCE authenticator
              signInResolver: /* ... */,
            }),
          });
        },
      });
    },
  }),
);
```

### Configuration

```yaml
# app-config.yaml
auth:
  environment: development
  providers:
    oidc-pkce:  # ← Must match frontend and backend provider ID
      development:
        metadataUrl: https://idp.example.com/.well-known/openid-configuration
        clientId: my-public-client-id
        # No clientSecret needed for PKCE
        prompt: auto
        scope: openid profile email
```

---

## PKCE and Frontend Transparency

### The Complete Answer

**PKCE is 100% transparent to the frontend.** The frontend code is **byte-for-byte identical** for:
- OAuth2 with client secret (confidential client)
- OAuth2 with PKCE (public client)
- Plain OAuth2 (not recommended)

### Why PKCE is Backend-Only

**PKCE (Proof Key for Code Exchange)** adds these steps to OAuth2 authorization code flow:

```
Backend generates:
  code_verifier = random_string(43-128 chars)
  code_challenge = BASE64URL(SHA256(code_verifier))

Backend sends in authorization request:
  /authorize?code_challenge=xyz&code_challenge_method=S256&...

Backend sends in token request:
  POST /token
  code=abc&code_verifier=original_random_string&...
```

**Frontend never sees**:
- `code_verifier`
- `code_challenge`
- `code_challenge_method`

Frontend only sees the standard OAuth2 authorization code flow:
1. Redirect to `/authorize` (with code_challenge added by backend)
2. Receive authorization code
3. Backend exchanges code for tokens (using code_verifier)
4. Frontend receives tokens

### Code Comparison

```typescript
// Frontend code for GitHub (client secret)
const githubApi = OAuth2.create({
  provider: { id: 'github', title: 'GitHub', icon: GitHubIcon },
  configApi,
  discoveryApi,
  oauthRequestApi,
});

// Frontend code for custom OIDC (PKCE) - IDENTICAL!
const oidcApi = OAuth2.create({
  provider: { id: 'oidc-pkce', title: 'OIDC', icon: OidcIcon },
  configApi,
  discoveryApi,
  oauthRequestApi,
});
```

The only difference is the `provider.id` string. Everything else is **exactly the same**.

### Testing PKCE Transparency

You can verify this by:
1. Implementing backend with PKCE
2. Using any standard OIDC frontend auth API ref
3. It will work without any frontend changes

---

## Creating Custom Auth API Refs

### Pattern: Custom OIDC API Ref

**File**: `packages/app/src/apis/oidcPkceAuthApiRef.ts`

```typescript
import { createApiRef } from '@backstage/frontend-plugin-api';
import type {
  OAuthApi,
  OpenIdConnectApi,
  ProfileInfoApi,
  BackstageIdentityApi,
  SessionApi,
} from '@backstage/core-plugin-api';

/**
 * API Reference for custom OIDC with PKCE authentication.
 *
 * Implements all standard auth interfaces:
 * - OAuthApi: Access tokens
 * - OpenIdConnectApi: ID tokens
 * - ProfileInfoApi: User profile
 * - BackstageIdentityApi: Backstage identity
 * - SessionApi: Sign-in/sign-out
 *
 * @public
 */
export const oidcPkceAuthApiRef = createApiRef<
  OAuthApi & OpenIdConnectApi & ProfileInfoApi & BackstageIdentityApi & SessionApi
>({
  id: 'auth.oidc-pkce',
});
```

### Alternative: Generic OIDC Ref

If you want to reuse across multiple OIDC providers:

```typescript
/**
 * Generic OIDC API Reference for any OIDC-compliant provider.
 * Can be used with custom PKCE, standard OIDC, or any OAuth2/OIDC provider.
 */
export const genericOidcAuthApiRef = createApiRef<
  OAuthApi & OpenIdConnectApi & ProfileInfoApi & BackstageIdentityApi & SessionApi
>({
  id: 'auth.oidc',
});
```

### Using Provider-Specific Refs

You can also reuse existing provider refs like `oktaAuthApiRef` even if your backend is custom:

```typescript
import { oktaAuthApiRef } from '@backstage/core-plugin-api';

// Use Okta's auth API ref with your custom OIDC/PKCE backend
const myOidcApi = ApiBlueprint.make({
  params: {
    factory: createApiFactory({
      api: oktaAuthApiRef,  // Reuse existing ref
      deps: { /* ... */ },
      factory: ({ configApi, discoveryApi, oauthRequestApi }) =>
        OAuth2.create({
          provider: { id: 'my-oidc-provider', /* ... */ },
          configApi,
          discoveryApi,
          oauthRequestApi,
        }),
    }),
  },
});
```

This works because the interface is the same - only the provider ID changes.

---

## Registering Custom Auth Providers

### Complete Registration Pattern

**Step 1: Create API Ref** (if not using standard ref)

See [Creating Custom Auth API Refs](#creating-custom-auth-api-refs) above.

**Step 2: Create API Extension**

**File**: `packages/app/src/modules/auth/oidcPkceAuth.tsx`

```typescript
import { ApiBlueprint, createApiFactory } from '@backstage/frontend-plugin-api';
import { configApiRef, discoveryApiRef, oauthRequestApiRef } from '@backstage/core-plugin-api';
import { OAuth2 } from '@backstage/core-app-api';
import { oidcPkceAuthApiRef } from '../../apis/oidcPkceAuthApiRef';
import LockIcon from '@material-ui/icons/Lock';

export const oidcPkceAuthApi = ApiBlueprint.make({
  name: 'oidc-pkce',  // Extension will be: api:app/oidc-pkce
  params: {
    factory: createApiFactory({
      api: oidcPkceAuthApiRef,
      deps: {
        configApi: configApiRef,
        discoveryApi: discoveryApiRef,
        oauthRequestApi: oauthRequestApiRef,
      },
      factory: ({ configApi, discoveryApi, oauthRequestApi }) =>
        OAuth2.create({
          configApi,
          discoveryApi,
          oauthRequestApi,
          provider: {
            id: 'oidc-pkce',  // Must match backend provider ID and config key
            title: 'OIDC with PKCE',
            icon: LockIcon,
          },
          defaultScopes: ['openid', 'profile', 'email'],
        }),
    }),
  },
});
```

**Step 3: Create Frontend Module**

**File**: `packages/app/src/modules/auth/index.tsx`

```typescript
import { createFrontendModule } from '@backstage/frontend-plugin-api';
import { oidcPkceAuthApi } from './oidcPkceAuth';

export const authModule = createFrontendModule({
  pluginId: 'app',  // Namespace for app-level extensions
  extensions: [
    oidcPkceAuthApi,  // Can add multiple auth APIs here
  ],
});
```

**Step 4: Install in App**

**File**: `packages/app/src/App.tsx`

```typescript
import { createApp } from '@backstage/frontend-defaults';
import { authModule } from './modules/auth';

const app = createApp({
  features: [
    authModule,  // Install auth module
    // ... other features
  ],
});

export default app.createRoot();
```

**Step 5: Configure Sign-In Page**

**File**: `packages/app/src/modules/signInPage/index.tsx`

```typescript
import { SignInPageBlueprint } from '@backstage/frontend-plugin-api';
import { SignInPage } from '@backstage/core-components';
import { oidcPkceAuthApiRef } from '../../apis/oidcPkceAuthApiRef';

export const customSignInPage = SignInPageBlueprint.make({
  params: {
    loader: async () => props => (
      <SignInPage
        {...props}
        providers={[
          {
            id: 'oidc-pkce-provider',
            title: 'OIDC with PKCE',
            message: 'Sign in using OIDC',
            apiRef: oidcPkceAuthApiRef,
          },
          'guest',  // Also allow guest auth
        ]}
      />
    ),
  },
});

export const signInModule = createFrontendModule({
  pluginId: 'app',
  extensions: [customSignInPage],
});
```

**Step 6: Backend Configuration**

**File**: `app-config.yaml`

```yaml
auth:
  environment: development
  providers:
    oidc-pkce:  # Must match provider.id in frontend
      development:
        metadataUrl: ${OIDC_METADATA_URL}
        clientId: ${OIDC_CLIENT_ID}
        # clientSecret not needed for PKCE
        prompt: auto
        scope: 'openid profile email'
```

**Step 7: Backend Module** (for reference)

**File**: `packages/backend/src/modules/auth/oidcPkce.ts`

```typescript
import { createBackendModule } from '@backstage/backend-plugin-api';
import { authProvidersExtensionPoint } from '@backstage/plugin-auth-node';
import { createOAuthProviderFactory } from '@backstage/plugin-auth-backend';
import { oidcPkceAuthenticator } from './oidcPkceAuthenticator';

export const oidcPkceAuthModule = createBackendModule({
  pluginId: 'auth',
  moduleId: 'oidc-pkce-provider',
  register(reg) {
    reg.registerInit({
      deps: {
        providers: authProvidersExtensionPoint,
      },
      async init({ providers }) {
        providers.registerProvider({
          providerId: 'oidc-pkce',  // Must match frontend
          factory: createOAuthProviderFactory({
            authenticator: oidcPkceAuthenticator,  // Implements PKCE
            signInResolver: /* ... */,
          }),
        });
      },
    });
  },
});
```

---

## How Standard Providers Are Registered

### Default Registration in `@backstage/frontend-defaults`

Standard providers (GitHub, Google, Okta, etc.) are automatically registered when you use:

```typescript
import { createApp } from '@backstage/frontend-defaults';
```

### Under the Hood

Location: `backstage/packages/frontend-defaults/src/`

The `@backstage/frontend-defaults` package includes:
- All standard auth API extensions
- Default implementations using `OAuth2.create()`
- Icons and provider metadata
- Default scopes

### Why GitHub Auth "Just Works"

```typescript
// When you import from frontend-defaults
import { createApp } from '@backstage/frontend-defaults';

// You automatically get these APIs registered:
const defaultApis = [
  githubAuthApi,      // Already registered
  googleAuthApi,      // Already registered
  oktaAuthApi,        // Already registered
  microsoftAuthApi,   // Already registered
  // ... and more
  configApi,
  discoveryApi,
  storageApi,
  errorApi,
  // ... etc.
];

const app = createApp({
  // These default APIs are always included
  features: [/* your plugins */],
});
```

### Standard Provider Pattern (GitHub Example)

```typescript
// Simplified from @backstage/frontend-defaults

const githubAuthApi = ApiBlueprint.make({
  name: 'github',
  params: {
    factory: createApiFactory({
      api: githubAuthApiRef,
      deps: {
        configApi: configApiRef,
        discoveryApi: discoveryApiRef,
        oauthRequestApi: oauthRequestApiRef,
      },
      factory: ({ configApi, discoveryApi, oauthRequestApi }) =>
        OAuth2.create({
          configApi,
          discoveryApi,
          oauthRequestApi,
          provider: {
            id: 'github',
            title: 'GitHub',
            icon: GitHubIcon,
          },
          defaultScopes: ['read:user'],
        }),
    }),
  },
});
```

### Custom Providers Follow Same Pattern

Your custom providers use **exactly the same pattern** as standard providers. The only differences:
1. You register manually (not in frontend-defaults)
2. You choose your own provider ID
3. You may use custom API ref

---

## Overriding Standard Providers

### Use Case: Customize GitHub Scopes

You want to use GitHub auth but need additional scopes.

**Solution: Override GitHub Auth API Extension**

```typescript
import { ApiBlueprint } from '@backstage/frontend-plugin-api';
import { githubAuthApiRef, configApiRef, discoveryApiRef, oauthRequestApiRef } from '@backstage/core-plugin-api';
import { OAuth2 } from '@backstage/core-app-api';
import GitHubIcon from '@material-ui/icons/GitHub';

const customGithubAuthApi = ApiBlueprint.make({
  name: 'github',  // Same name = override default
  params: {
    factory: createApiFactory({
      api: githubAuthApiRef,  // Use standard ref
      deps: {
        configApi: configApiRef,
        discoveryApi: discoveryApiRef,
        oauthRequestApi: oauthRequestApiRef,
      },
      factory: ({ configApi, discoveryApi, oauthRequestApi }) =>
        OAuth2.create({
          configApi,
          discoveryApi,
          oauthRequestApi,
          provider: {
            id: 'github',
            title: 'GitHub',
            icon: GitHubIcon,
          },
          // Add custom scopes
          defaultScopes: ['read:user', 'read:org', 'repo'],
        }),
    }),
  },
});

// Install before default features
const app = createApp({
  features: [
    createFrontendModule({
      pluginId: 'app',
      extensions: [customGithubAuthApi],  // This will override default
    }),
    // ... other features
  ],
});
```

### Extension Priority

- Extensions with same ID: **last one wins**
- Explicit features (in `features` array): **higher priority than discovered**
- Frontend modules: Can be ordered in `features` array

### Disabling Standard Providers

**Option 1: Configuration**

```yaml
# app-config.yaml
app:
  extensions:
    - api:core.auth.github: false  # Disable GitHub auth API extension
```

**Option 2: Don't Use Standard Sign-In**

```typescript
// Custom sign-in page without GitHub
const customSignInPage = SignInPageBlueprint.make({
  params: {
    loader: async () => props => (
      <SignInPage
        {...props}
        providers={[
          // Only custom providers, no GitHub
          { id: 'my-oidc', title: 'My OIDC', apiRef: myOidcApiRef },
          'guest',
        ]}
      />
    ),
  },
});
```

---

## Complete OIDC/PKCE Example

This section provides a **complete, working example** of custom OIDC with PKCE, step-by-step.

### Directory Structure

```
packages/app/
├── src/
│   ├── apis/
│   │   └── oidcPkceAuthApiRef.ts      # Custom API ref
│   ├── modules/
│   │   ├── auth/
│   │   │   ├── index.tsx              # Auth module (exports)
│   │   │   └── oidcPkceAuth.tsx       # Auth API extension
│   │   └── signInPage/
│   │       └── index.tsx              # Custom sign-in page
│   ├── App.tsx                        # App entry point
│   └── index.tsx                      # React root
└── package.json
```

### Step-by-Step Implementation

#### 1. Create Custom API Ref

**File**: `src/apis/oidcPkceAuthApiRef.ts`

```typescript
import { createApiRef } from '@backstage/frontend-plugin-api';
import type {
  OAuthApi,
  OpenIdConnectApi,
  ProfileInfoApi,
  BackstageIdentityApi,
  SessionApi,
} from '@backstage/core-plugin-api';

export const oidcPkceAuthApiRef = createApiRef<
  OAuthApi & OpenIdConnectApi & ProfileInfoApi & BackstageIdentityApi & SessionApi
>({
  id: 'auth.oidc-pkce',
});
```

#### 2. Create Auth API Extension

**File**: `src/modules/auth/oidcPkceAuth.tsx`

```typescript
import { ApiBlueprint, createApiFactory } from '@backstage/frontend-plugin-api';
import { configApiRef, discoveryApiRef, oauthRequestApiRef } from '@backstage/core-plugin-api';
import { OAuth2 } from '@backstage/core-app-api';
import { oidcPkceAuthApiRef } from '../../apis/oidcPkceAuthApiRef';
import LockIcon from '@material-ui/icons/Lock';

export const oidcPkceAuthApi = ApiBlueprint.make({
  name: 'oidc-pkce',
  params: {
    factory: createApiFactory({
      api: oidcPkceAuthApiRef,
      deps: {
        configApi: configApiRef,
        discoveryApi: discoveryApiRef,
        oauthRequestApi: oauthRequestApiRef,
      },
      factory: ({ configApi, discoveryApi, oauthRequestApi }) =>
        OAuth2.create({
          configApi,
          discoveryApi,
          oauthRequestApi,
          provider: {
            id: 'oidc-pkce',  // Must match backend
            title: 'OIDC with PKCE',
            icon: LockIcon,
          },
          defaultScopes: ['openid', 'profile', 'email'],
        }),
    }),
  },
});
```

#### 3. Create Auth Module

**File**: `src/modules/auth/index.tsx`

```typescript
import { createFrontendModule } from '@backstage/frontend-plugin-api';
import { oidcPkceAuthApi } from './oidcPkceAuth';

export const authModule = createFrontendModule({
  pluginId: 'app',
  extensions: [oidcPkceAuthApi],
});
```

#### 4. Create Custom Sign-In Page

**File**: `src/modules/signInPage/index.tsx`

```typescript
import { createFrontendModule, SignInPageBlueprint } from '@backstage/frontend-plugin-api';
import { SignInPage } from '@backstage/core-components';
import { oidcPkceAuthApiRef } from '../../apis/oidcPkceAuthApiRef';
import LockIcon from '@material-ui/icons/Lock';

const customSignInPage = SignInPageBlueprint.make({
  params: {
    loader: async () => props => (
      <SignInPage
        {...props}
        providers={[
          {
            id: 'oidc-pkce-provider',
            title: 'OIDC with PKCE',
            message: 'Sign in using OIDC',
            apiRef: oidcPkceAuthApiRef,
          },
          'guest',
        ]}
      />
    ),
  },
});

export const signInModule = createFrontendModule({
  pluginId: 'app',
  extensions: [customSignInPage],
});
```

#### 5. Install Modules in App

**File**: `src/App.tsx`

```typescript
import { createApp } from '@backstage/frontend-defaults';
import { authModule } from './modules/auth';
import { signInModule } from './modules/signInPage';

const app = createApp({
  features: [
    authModule,     // Install auth API
    signInModule,   // Install custom sign-in page
    // Feature discovery will install other plugins automatically
  ],
});

export default app.createRoot();
```

#### 6. Configure Backend

**File**: `app-config.yaml`

```yaml
auth:
  environment: development
  providers:
    oidc-pkce:
      development:
        metadataUrl: https://your-idp.example.com/.well-known/openid-configuration
        clientId: your-public-client-id
        # No clientSecret for PKCE
        prompt: auto
        scope: 'openid profile email'

# Backend discovery
backend:
  baseUrl: http://localhost:7007
  listen:
    port: 7007

# Frontend config
app:
  baseUrl: http://localhost:3000
```

#### 7. Enable Feature Discovery (Optional)

**File**: `app-config.yaml`

```yaml
app:
  packages: all  # Auto-discover and install all plugins
```

#### 8. Test It!

```bash
# Install dependencies
yarn install

# Start backend
yarn start-backend

# Start frontend (in another terminal)
yarn start

# Navigate to http://localhost:3000
# You should see "OIDC with PKCE" button on sign-in page
```

---

## Troubleshooting

### Common Issues

#### 1. "API ref not found" Error

**Symptom**: `Error: No implementation available for auth.oidc-pkce`

**Causes**:
- Auth module not installed in `createApp({ features: [] })`
- API extension name doesn't match
- Module not imported in App.tsx

**Solution**:
```typescript
// Verify module is installed
const app = createApp({
  features: [
    authModule,  // ← Make sure this is present
    // ...
  ],
});
```

#### 2. Backend "Unknown provider" Error

**Symptom**: `Error: No auth provider registered for 'oidc-pkce'`

**Causes**:
- Backend module not installed
- Provider ID mismatch between frontend and backend
- Backend module not registered in backend index.ts

**Solution**:
```typescript
// Backend index.ts
backend.add(import('./modules/auth/oidcPkce'));

// Verify provider IDs match
Frontend: provider: { id: 'oidc-pkce', ... }
Backend: providerId: 'oidc-pkce'
Config: auth.providers.oidc-pkce
```

#### 3. Infinite Redirect Loop

**Symptom**: Browser keeps redirecting between app and IdP

**Causes**:
- Callback URL not configured correctly in IdP
- Missing `baseUrl` configuration
- CORS issues

**Solution**:
```yaml
# Verify configuration
backend:
  baseUrl: http://localhost:7007  # Must match IdP callback config
  cors:
    origin: http://localhost:3000
    credentials: true

# IdP callback should be:
# http://localhost:7007/api/auth/oidc-pkce/handler/frame
```

#### 4. "Invalid token" Error

**Symptom**: Auth succeeds but API calls fail with 401

**Causes**:
- Backend sign-in resolver not configured
- Token not being sent in requests
- Token validation failing

**Solution**:
- Check backend logs for sign-in resolver errors
- Verify `BackstageIdentityApi` implementation
- Check backend token validation configuration

#### 5. Sign-In Button Not Appearing

**Symptom**: Custom OIDC button not showing on sign-in page

**Causes**:
- Sign-in module not installed
- API ref mismatch in sign-in page configuration
- Custom sign-in page not overriding default

**Solution**:
```typescript
// Verify sign-in module installed
const app = createApp({
  features: [
    authModule,
    signInModule,  // ← Must be present
  ],
});

// Verify API ref matches in both places
// Auth extension: api: oidcPkceAuthApiRef
// Sign-in page: apiRef: oidcPkceAuthApiRef
```

#### 6. Type Errors with OAuth2.create()

**Symptom**: TypeScript errors when calling `OAuth2.create()`

**Causes**:
- OAuth2 not exported from `@backstage/core-app-api`
- Using wrong import path

**Solution**:
```typescript
// Correct import (may not be exported in older versions)
import { OAuth2 } from '@backstage/core-app-api';

// If not exported, you may need to use createApiFactory pattern differently
// or upgrade to newer Backstage version
```

### Debugging Tips

#### 1. Check Extension Tree

Install `@backstage/plugin-app-visualizer`:

```bash
cd packages/app
yarn add @backstage/plugin-app-visualizer
```

Navigate to `/visualizer` to see:
- All registered extensions
- Extension tree structure
- Which APIs are available
- Whether your custom auth API is registered

#### 2. Enable Debug Logging

```yaml
# app-config.yaml
app:
  debug: true  # Enable frontend debug mode
```

```typescript
// Add logging to your auth extension
factory: ({ configApi, discoveryApi, oauthRequestApi }) => {
  console.log('[OIDCPKCEAuth] Creating OAuth2 instance with provider: oidc-pkce');
  return OAuth2.create({ /* ... */ });
}
```

#### 3. Check Browser Console

Look for:
- API registration messages
- OAuth popup errors
- CORS errors
- Token storage errors

#### 4. Check Backend Logs

Look for:
- Provider registration messages
- OAuth flow logs
- Token exchange errors
- PKCE validation errors

### Getting Help

If you're still stuck:

1. **Check GitHub Issues**: https://github.com/backstage/backstage/issues
2. **Join Discord**: https://discord.gg/backstage-687207715902193673 (#support channel)
3. **Review Official Docs**: https://backstage.io/docs/auth/
4. **Check this guide's examples**: See `../examples/auth-providers/`

---

## Summary

### Key Points

1. **PKCE is Backend-Only**: Frontend code is identical for PKCE vs client secret
2. **OAuth2.create() is Generic**: Works with any OAuth2/OIDC provider
3. **Provider ID Must Match**: Frontend, backend, and config must use same provider ID
4. **ApiBlueprint Pattern**: Use `ApiBlueprint.make()` to register custom auth providers
5. **No Standard OIDC Ref**: Create your own or reuse provider-specific ref (e.g., `oktaAuthApiRef`)

### Recommended Pattern for Custom OIDC/PKCE

```
1. Create custom API ref (or reuse oktaAuthApiRef)
2. Create API extension using ApiBlueprint + OAuth2.create()
3. Create frontend module and install in app
4. Configure sign-in page with custom provider
5. Register backend PKCE authenticator
6. Configure auth.providers.{provider} in app-config.yaml
7. Test: Frontend → Backend → IdP → Backend → Frontend
```

### Next Steps

- See [Complete OIDC/PKCE Example](#complete-oidcpkce-example) for working code
- Check [`../examples/auth-providers/`](../examples/auth-providers/) for more examples
- Read [04-utility-apis.md](./04-utility-apis.md) for general Utility API patterns
- Review [07-migration.md](./07-migration.md) for migrating from legacy auth

---

**Navigation**:
- [← Previous: Utility APIs](./04-utility-apis.md)
- [Next: Plugin Development →](./06-plugin-development.md)
- [Back to Index](./INDEX.md)
