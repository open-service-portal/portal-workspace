/**
 * Example: Understanding OAuth2.create() Pattern
 *
 * This demonstrates how OAuth2.create() works internally and why it's
 * generic enough to work with any OAuth2/OIDC provider including PKCE.
 *
 * Key Insight: OAuth2.create() is completely provider-agnostic. It only
 * needs a provider ID to construct backend URLs. All provider-specific
 * logic (PKCE, client secrets, scopes, etc.) is handled by the backend.
 */

import type {
  ConfigApi,
  DiscoveryApi,
  OAuthRequestApi,
} from '@backstage/core-plugin-api';

/**
 * Simplified representation of how OAuth2.create() works internally
 *
 * Source: backstage/packages/core-app-api/src/apis/implementations/auth/oauth2/OAuth2.ts
 */

// ============================================================================
// OAuth2 Class Structure
// ============================================================================

interface OAuth2Options {
  configApi: ConfigApi;
  discoveryApi: DiscoveryApi;
  oauthRequestApi: OAuthRequestApi;
  provider: {
    id: string;      // e.g., 'github', 'oidc-pkce', 'google'
    title: string;   // e.g., 'GitHub', 'OIDC with PKCE'
    icon: React.ComponentType;
  };
  defaultScopes?: string[];
  scopeTransform?: (scopes: string[]) => string[];
  environment?: string;
}

class OAuth2Simplified {
  private baseUrl: string;
  private popupOptions: any;

  static create(options: OAuth2Options) {
    // 1. Read backend base URL from config
    const baseUrl = options.configApi.getString('backend.baseUrl');

    // 2. Construct provider-specific endpoints
    const startUrl = `${baseUrl}/api/auth/${options.provider.id}/start`;
    const frameUrl = `${baseUrl}/api/auth/${options.provider.id}/handler/frame`;
    const refreshUrl = `${baseUrl}/api/auth/${options.provider.id}/refresh`;

    // 3. Create OAuth2 instance with these URLs
    return new OAuth2Simplified(startUrl, frameUrl, refreshUrl);
  }

  // Implementation methods...
  async signIn() { /* Open popup to startUrl */ }
  async getAccessToken() { /* Retrieve from storage or refresh */ }
  async getIdToken() { /* Retrieve ID token from session */ }
  // ... etc
}

// ============================================================================
// Key Point: Provider-Agnostic URLs
// ============================================================================

/**
 * OAuth2.create() constructs backend URLs using ONLY the provider ID.
 * It doesn't know or care about:
 * - Whether backend uses PKCE or client secret
 * - What scopes the provider supports
 * - What endpoints the IdP has
 * - How tokens are validated
 *
 * Examples of constructed URLs:
 *
 * GitHub (client secret):
 *   /api/auth/github/start
 *   /api/auth/github/handler/frame
 *   /api/auth/github/refresh
 *
 * OIDC with PKCE (public client):
 *   /api/auth/oidc-pkce/start
 *   /api/auth/oidc-pkce/handler/frame
 *   /api/auth/oidc-pkce/refresh
 *
 * Custom OAuth2 provider:
 *   /api/auth/my-custom/start
 *   /api/auth/my-custom/handler/frame
 *   /api/auth/my-custom/refresh
 *
 * The pattern is ALWAYS the same: /api/auth/{provider.id}/{endpoint}
 */

// ============================================================================
// What OAuth2.create() Does
// ============================================================================

/**
 * 1. Authorization Flow
 *    - Opens popup to /api/auth/{provider}/start?scope=...
 *    - Backend handles redirect to IdP
 *    - Waits for callback to /api/auth/{provider}/handler/frame
 *    - Extracts tokens from callback
 *    - Stores tokens in browser storage
 *    - Closes popup
 *
 * 2. Token Storage
 *    - Stores access_token, id_token, refresh_token in localStorage
 *    - Stores expiry time for automatic refresh
 *    - Provides type-safe access via methods
 *
 * 3. Token Refresh
 *    - Checks token expiry before each use
 *    - Auto-refreshes if < 3 minutes to expiry
 *    - Calls /api/auth/{provider}/refresh
 *
 * 4. Session Management
 *    - Provides signIn() / signOut() methods
 *    - Observable session state
 *    - Handles multi-tab synchronization
 *
 * 5. Security
 *    - CSRF protection with state parameter
 *    - Nonce validation for OIDC
 *    - Secure token storage
 */

// ============================================================================
// What OAuth2.create() Does NOT Do
// ============================================================================

/**
 * OAuth2.create() is intentionally DUMB. It doesn't:
 *
 * ❌ Generate code_challenge (PKCE)
 * ❌ Send client_secret
 * ❌ Validate scopes
 * ❌ Know about IdP endpoints
 * ❌ Interact directly with IdP (Google, GitHub, etc.)
 * ❌ Implement provider-specific features
 * ❌ Handle provider-specific token formats
 * ❌ Perform token validation
 *
 * All of these are handled by the BACKEND.
 */

// ============================================================================
// Example: GitHub vs OIDC/PKCE
// ============================================================================

/**
 * Frontend code for GitHub (client secret)
 */
const githubApi = OAuth2Simplified.create({
  provider: { id: 'github', title: 'GitHub', icon: GitHubIcon },
  configApi,
  discoveryApi,
  oauthRequestApi,
  defaultScopes: ['read:user'],
});

/**
 * Frontend code for OIDC with PKCE (public client)
 *
 * Notice: The code is IDENTICAL except for provider ID!
 */
const oidcPkceApi = OAuth2Simplified.create({
  provider: { id: 'oidc-pkce', title: 'OIDC', icon: OidcIcon },
  configApi,
  discoveryApi,
  oauthRequestApi,
  defaultScopes: ['openid', 'profile'],
});

/**
 * Both result in the same methods:
 * - await githubApi.signIn()          / await oidcPkceApi.signIn()
 * - await githubApi.getAccessToken()  / await oidcPkceApi.getAccessToken()
 * - await githubApi.getIdToken()      / await oidcPkceApi.getIdToken()
 * - await githubApi.signOut()         / await oidcPkceApi.signOut()
 */

// ============================================================================
// Example: Authorization Flow with PKCE
// ============================================================================

/**
 * Complete flow showing frontend/backend interaction
 */
async function demonstrateOAuth2Flow() {
  // 1. User clicks "Sign in with OIDC"
  console.log('User initiates sign-in');

  // 2. Frontend calls signIn() on OAuth2 instance
  await oidcPkceApi.signIn();

  /**
   * What happens under the hood:
   *
   * Frontend:
   *   1. Opens popup to: /api/auth/oidc-pkce/start?scope=openid+profile
   *
   * Backend (PKCE):
   *   2. Generates code_verifier (random 128-char string)
   *   3. Generates code_challenge = BASE64URL(SHA256(code_verifier))
   *   4. Stores code_verifier in session
   *   5. Redirects popup to IdP:
   *      https://idp.example.com/authorize?
   *        client_id=...&
   *        redirect_uri=http://localhost:7007/api/auth/oidc-pkce/handler/frame&
   *        code_challenge=xyz123&              ← PKCE parameter (backend adds)
   *        code_challenge_method=S256&         ← PKCE parameter (backend adds)
   *        scope=openid+profile&
   *        response_type=code&
   *        state=...&                          ← CSRF protection
   *        nonce=...                           ← OIDC nonce
   *
   * User:
   *   6. Authenticates at IdP
   *
   * IdP:
   *   7. Redirects to callback:
   *      /api/auth/oidc-pkce/handler/frame?code=abc123&state=...
   *
   * Backend (PKCE):
   *   8. Validates state (CSRF check)
   *   9. Retrieves code_verifier from session
   *   10. Exchanges code for tokens:
   *       POST https://idp.example.com/token
   *       Content-Type: application/x-www-form-urlencoded
   *
   *       code=abc123&
   *       client_id=...&
   *       redirect_uri=.../handler/frame&
   *       code_verifier=<original_random_string>&  ← PKCE verification
   *       grant_type=authorization_code
   *
   * IdP:
   *   11. Validates code_verifier against original code_challenge
   *   12. Returns tokens:
   *       {
   *         "access_token": "...",
   *         "id_token": "...",
   *         "refresh_token": "...",
   *         "expires_in": 3600
   *       }
   *
   * Backend:
   *   13. Validates tokens
   *   14. Creates Backstage identity
   *   15. Returns tokens to popup:
   *       {
   *         "accessToken": "...",
   *         "idToken": "...",
   *         "profile": { ... },
   *         "expiresInSeconds": 3600
   *       }
   *
   * Frontend:
   *   16. Receives tokens in popup
   *   17. Stores in localStorage:
   *       backstage-auth-oidc-pkce-session = {
   *         accessToken: "...",
   *         idToken: "...",
   *         expiresAt: Date.now() + 3600000
   *       }
   *   18. Closes popup
   *   19. App is now authenticated!
   */

  // 3. App can now make authenticated requests
  const accessToken = await oidcPkceApi.getAccessToken();
  console.log('Got access token:', accessToken);

  const idToken = await oidcPkceApi.getIdToken();
  console.log('Got ID token:', idToken);

  const profile = await oidcPkceApi.getProfile();
  console.log('Got profile:', profile);

  // 4. Tokens are automatically refreshed before expiry
  // OAuth2 checks: if (now + 3min > expiresAt) { refresh() }
}

// ============================================================================
// Key Takeaways
// ============================================================================

/**
 * 1. Frontend is Provider-Agnostic
 *    OAuth2.create() only needs provider ID. It doesn't know about PKCE,
 *    client secrets, or any provider-specific details.
 *
 * 2. PKCE is 100% Backend
 *    code_challenge and code_verifier are generated, sent, and validated
 *    entirely by the backend. Frontend never sees them.
 *
 * 3. Same Code for All Providers
 *    The ONLY difference in frontend code is the provider.id string.
 *    Everything else is identical.
 *
 * 4. Backend Does the Heavy Lifting
 *    - Generates PKCE parameters
 *    - Handles IdP redirects
 *    - Exchanges codes for tokens
 *    - Validates tokens
 *    - Creates Backstage identity
 *
 * 5. Frontend is Just a Client
 *    - Opens popups
 *    - Stores tokens
 *    - Provides tokens to components
 *    - Handles token refresh
 *
 * 6. This Enables Custom Providers
 *    You can implement ANY OAuth2/OIDC provider by:
 *    - Registering backend authenticator
 *    - Using OAuth2.create() in frontend
 *    - Matching provider IDs
 *    No custom frontend auth code needed!
 */

// ============================================================================
// Real World Usage
// ============================================================================

/**
 * How to use OAuth2.create() for custom OIDC/PKCE:
 */
import { ApiBlueprint, createApiFactory } from '@backstage/frontend-plugin-api';
import {
  configApiRef,
  discoveryApiRef,
  oauthRequestApiRef,
} from '@backstage/core-plugin-api';
import { OAuth2 } from '@backstage/core-app-api';

const myOidcApi = ApiBlueprint.make({
  name: 'my-oidc',
  params: {
    factory: createApiFactory({
      api: myOidcApiRef,  // Your custom API ref
      deps: {
        configApi: configApiRef,
        discoveryApi: discoveryApiRef,
        oauthRequestApi: oauthRequestApiRef,
      },
      factory: ({ configApi, discoveryApi, oauthRequestApi }) =>
        OAuth2.create({
          // Only thing that matters: provider ID!
          provider: {
            id: 'my-oidc',  // ← Must match backend
            title: 'My OIDC Provider',
            icon: MyIcon,
          },
          configApi,
          discoveryApi,
          oauthRequestApi,
          defaultScopes: ['openid', 'profile', 'email'],
        }),
    }),
  },
});

/**
 * That's it! OAuth2.create() handles:
 * - Authorization flow
 * - Token storage
 * - Token refresh
 * - Session management
 * - Security (CSRF, nonce)
 *
 * Your backend handles:
 * - PKCE generation/validation
 * - IdP communication
 * - Token validation
 * - Identity resolution
 */
