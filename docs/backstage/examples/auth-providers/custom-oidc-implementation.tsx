/**
 * Example: Complete Custom OIDC/PKCE Implementation
 *
 * This demonstrates the complete frontend implementation for custom OIDC with PKCE:
 * 1. API ref definition
 * 2. API extension using ApiBlueprint
 * 3. Frontend module creation
 * 4. Custom sign-in page
 * 5. App installation
 *
 * File structure:
 * packages/app/src/
 * ├── apis/
 * │   └── oidcPkceAuthApiRef.ts       (Step 1)
 * ├── modules/
 * │   ├── auth/
 * │   │   ├── oidcPkceAuth.tsx        (Step 2)
 * │   │   └── index.tsx               (Step 3)
 * │   └── signInPage/
 * │       └── index.tsx               (Step 4)
 * └── App.tsx                          (Step 5)
 */

// ============================================================================
// Step 1: API Ref Definition
// File: packages/app/src/apis/oidcPkceAuthApiRef.ts
// ============================================================================

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

// ============================================================================
// Step 2: API Extension Creation
// File: packages/app/src/modules/auth/oidcPkceAuth.tsx
// ============================================================================

import { ApiBlueprint, createApiFactory } from '@backstage/frontend-plugin-api';
import {
  configApiRef,
  discoveryApiRef,
  oauthRequestApiRef,
} from '@backstage/core-plugin-api';
import { OAuth2 } from '@backstage/core-app-api';
// import { oidcPkceAuthApiRef } from '../../apis/oidcPkceAuthApiRef';
import LockIcon from '@material-ui/icons/Lock';

/**
 * OIDC with PKCE Auth API Extension
 *
 * This creates an API extension that:
 * - Implements the oidcPkceAuthApiRef contract
 * - Uses OAuth2.create() for the actual OAuth2 flow
 * - Depends on core APIs (config, discovery, oauthRequest)
 * - Configures provider ID, title, and icon
 */
export const oidcPkceAuthApi = ApiBlueprint.make({
  // Extension name (will be: api:app/oidc-pkce)
  name: 'oidc-pkce',

  params: {
    factory: createApiFactory({
      // API ref that this extension implements
      api: oidcPkceAuthApiRef,

      // Dependencies: Other APIs this API needs
      deps: {
        configApi: configApiRef,           // Read app-config.yaml
        discoveryApi: discoveryApiRef,     // Find backend URLs
        oauthRequestApi: oauthRequestApiRef, // Handle OAuth popup
      },

      // Factory function: Creates the actual implementation
      factory: ({ configApi, discoveryApi, oauthRequestApi }) => {
        console.log('[OIDCPKCEAuth] Creating OAuth2 instance');

        return OAuth2.create({
          configApi,
          discoveryApi,
          oauthRequestApi,

          // Provider configuration
          provider: {
            id: 'oidc-pkce',  // ← MUST MATCH backend provider ID and config key
            title: 'OIDC with PKCE',
            icon: LockIcon,
          },

          // Default scopes (can be overridden in backend)
          defaultScopes: ['openid', 'profile', 'email'],

          // Optional: Transform scopes before sending to backend
          // scopeTransform: (scopes) => [...scopes, 'additional-scope'],
        });
      },
    }),
  },
});

// ============================================================================
// Step 3: Frontend Module Creation
// File: packages/app/src/modules/auth/index.tsx
// ============================================================================

import { createFrontendModule } from '@backstage/frontend-plugin-api';
// import { oidcPkceAuthApi } from './oidcPkceAuth';

/**
 * Auth Module
 *
 * Bundles auth-related extensions into a single feature that can be
 * installed in the app. You can add multiple auth providers here.
 */
export const authModule = createFrontendModule({
  pluginId: 'app',  // Namespace: app-level extensions
  extensions: [
    oidcPkceAuthApi,  // Add OIDC/PKCE auth API
    // Add more auth APIs here if needed
  ],
});

// ============================================================================
// Step 4: Custom Sign-In Page
// File: packages/app/src/modules/signInPage/index.tsx
// ============================================================================

import {
  createFrontendModule,
  SignInPageBlueprint,
} from '@backstage/frontend-plugin-api';
import { SignInPage } from '@backstage/core-components';
// import { oidcPkceAuthApiRef } from '../../apis/oidcPkceAuthApiRef';
// import LockIcon from '@material-ui/icons/Lock';

/**
 * Custom Sign-In Page Extension
 *
 * Configures which auth providers appear on the sign-in page.
 */
const customSignInPage = SignInPageBlueprint.make({
  params: {
    // Loader: Lazy-load the sign-in page component
    loader: async () => props => (
      <SignInPage
        {...props}
        title="Select a sign-in method"
        align="center"
        providers={[
          // Custom OIDC/PKCE provider
          {
            id: 'oidc-pkce-provider',  // Unique ID for this sign-in provider
            title: 'OIDC with PKCE',
            message: 'Sign in using OIDC',
            apiRef: oidcPkceAuthApiRef,  // ← Links to auth API
          },

          // Also allow guest sign-in (optional)
          'guest',

          // You can add more providers here
          // {
          //   id: 'github-provider',
          //   title: 'GitHub',
          //   message: 'Sign in with GitHub',
          //   apiRef: githubAuthApiRef,
          // },
        ]}
      />
    ),
  },
});

/**
 * Sign-In Module
 *
 * Bundles sign-in page extension into a feature.
 */
export const signInModule = createFrontendModule({
  pluginId: 'app',
  extensions: [customSignInPage],
});

// ============================================================================
// Step 5: App Installation
// File: packages/app/src/App.tsx
// ============================================================================

import { createApp } from '@backstage/frontend-defaults';
// import { authModule } from './modules/auth';
// import { signInModule } from './modules/signInPage';

/**
 * App Creation
 *
 * Installs all features including custom auth and sign-in page.
 */
const app = createApp({
  features: [
    // Install custom auth API
    authModule,

    // Install custom sign-in page
    signInModule,

    // Other features (plugins, themes, etc.)
    // catalogPlugin,
    // scaffolderPlugin,
    // ...
  ],
});

export default app.createRoot();

// ============================================================================
// Step 6: Backend Configuration
// File: app-config.yaml
// ============================================================================

/**
 * Backend configuration for OIDC/PKCE provider
 *
 * auth:
 *   environment: development
 *   providers:
 *     oidc-pkce:  # ← Must match provider.id in frontend (Step 2)
 *       development:
 *         metadataUrl: https://your-idp.example.com/.well-known/openid-configuration
 *         clientId: your-public-client-id
 *         # No clientSecret needed for PKCE (public client)
 *         prompt: auto
 *         scope: 'openid profile email'
 *
 * backend:
 *   baseUrl: http://localhost:7007
 *   listen:
 *     port: 7007
 *
 * app:
 *   baseUrl: http://localhost:3000
 */

// ============================================================================
// Step 7: Backend Module Registration
// File: packages/backend/src/modules/auth/oidcPkce.ts
// ============================================================================

/**
 * Backend module for OIDC/PKCE provider
 *
 * import { createBackendModule } from '@backstage/backend-plugin-api';
 * import { authProvidersExtensionPoint } from '@backstage/plugin-auth-node';
 * import { createOAuthProviderFactory } from '@backstage/plugin-auth-backend';
 * import { oidcPkceAuthenticator } from './oidcPkceAuthenticator';
 *
 * export const oidcPkceAuthModule = createBackendModule({
 *   pluginId: 'auth',
 *   moduleId: 'oidc-pkce-provider',
 *   register(reg) {
 *     reg.registerInit({
 *       deps: {
 *         providers: authProvidersExtensionPoint,
 *       },
 *       async init({ providers }) {
 *         providers.registerProvider({
 *           providerId: 'oidc-pkce',  // ← Must match frontend provider.id
 *           factory: createOAuthProviderFactory({
 *             authenticator: oidcPkceAuthenticator,  // Implements PKCE
 *             signInResolver: // ... ,
 *           }),
 *         });
 *       },
 *     });
 *   },
 * });
 *
 * // Then in packages/backend/src/index.ts:
 * // backend.add(import('./modules/auth/oidcPkce'));
 */

// ============================================================================
// Complete Flow Summary
// ============================================================================

/**
 * 1. User visits app → redirected to sign-in page (Step 4)
 * 2. User clicks "OIDC with PKCE" button
 * 3. Frontend looks up oidcPkceAuthApiRef (Step 1)
 * 4. Frontend finds API extension (Step 2) which provides OAuth2 instance
 * 5. OAuth2.create() instance calls signIn()
 * 6. Popup opens to: /api/auth/oidc-pkce/start?scope=openid+profile+email
 * 7. Backend recognizes 'oidc-pkce' provider (Step 7)
 * 8. Backend generates code_challenge (PKCE)
 * 9. Backend redirects popup to IdP authorization endpoint
 * 10. User authenticates at IdP
 * 11. IdP redirects back to: /api/auth/oidc-pkce/handler/frame?code=...
 * 12. Backend exchanges code + code_verifier for tokens (PKCE validation)
 * 13. Backend returns tokens to popup
 * 14. Frontend OAuth2 stores tokens in browser storage
 * 15. Popup closes, app is now authenticated
 * 16. Subsequent API calls include access token from storage
 */

// ============================================================================
// Key Points
// ============================================================================

/**
 * 1. Provider ID Matching
 *    - Frontend: provider: { id: 'oidc-pkce', ... }
 *    - Backend: providerId: 'oidc-pkce'
 *    - Config: auth.providers.oidc-pkce
 *    All three MUST match!
 *
 * 2. PKCE is Backend-Only
 *    - Frontend code is identical for PKCE vs client secret
 *    - code_challenge and code_verifier are backend-only
 *    - Frontend never sees PKCE parameters
 *
 * 3. OAuth2.create() is Generic
 *    - Works with any OAuth2/OIDC provider
 *    - Provider-specific logic is backend-only
 *    - Same implementation for GitHub, Google, Okta, custom OIDC, etc.
 *
 * 4. Extension Pattern
 *    - API ref defines contract (Step 1)
 *    - API extension provides implementation (Step 2)
 *    - Frontend module bundles extensions (Step 3)
 *    - Sign-in page uses API ref (Step 4)
 *    - App installs modules (Step 5)
 *
 * 5. Dependencies
 *    - configApi: Read app-config.yaml
 *    - discoveryApi: Find backend URLs
 *    - oauthRequestApi: Handle OAuth popup
 *    All three are required for OAuth2.create()
 *
 * 6. Testing
 *    - Start backend: yarn start-backend
 *    - Start frontend: yarn start
 *    - Navigate to http://localhost:3000
 *    - Should see "OIDC with PKCE" button on sign-in page
 *    - Click to test OAuth flow
 *
 * 7. Troubleshooting
 *    - Check provider IDs match in all three places
 *    - Verify IdP callback URL: http://localhost:7007/api/auth/oidc-pkce/handler/frame
 *    - Check browser console for errors
 *    - Check backend logs for auth flow
 *    - Use /visualizer to see registered extensions
 */
