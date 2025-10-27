/**
 * Example: Creating a Custom OIDC API Reference
 *
 * This demonstrates how to create a custom auth API reference for OIDC/PKCE providers.
 * The API ref defines the TypeScript contract that implementations must fulfill.
 *
 * Location: packages/app/src/apis/oidcPkceAuthApiRef.ts
 */

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
 * This combines all standard auth interfaces:
 * - OAuthApi: Provides access tokens via OAuth2
 * - OpenIdConnectApi: Provides ID tokens for OIDC
 * - ProfileInfoApi: Retrieves user profile information
 * - BackstageIdentityApi: Provides Backstage-specific identity
 * - SessionApi: Manages sign-in/sign-out sessions
 *
 * @public
 * @example
 * ```typescript
 * // Use this ref when creating the API extension
 * const oidcPkceAuthApi = ApiBlueprint.make({
 *   params: {
 *     factory: createApiFactory({
 *       api: oidcPkceAuthApiRef,  // ← Use here
 *       deps: { ... },
 *       factory: () => OAuth2.create({ ... }),
 *     }),
 *   },
 * });
 *
 * // Use this ref in sign-in page configuration
 * <SignInPage
 *   providers={[
 *     {
 *       id: 'oidc-pkce',
 *       apiRef: oidcPkceAuthApiRef,  // ← Use here
 *     },
 *   ]}
 * />
 *
 * // Use this ref to consume the API
 * const oidcApi = useApi(oidcPkceAuthApiRef);  // ← Use here
 * ```
 */
export const oidcPkceAuthApiRef = createApiRef<
  OAuthApi & OpenIdConnectApi & ProfileInfoApi & BackstageIdentityApi & SessionApi
>({
  // ID must be unique across all API refs
  // Convention: auth.<provider-name>
  id: 'auth.oidc-pkce',
});

/**
 * Alternative: Generic OIDC API Reference
 *
 * Use this if you want a single ref that works with multiple OIDC providers
 * (e.g., different OIDC providers in dev vs prod environments)
 *
 * @public
 */
export const genericOidcAuthApiRef = createApiRef<
  OAuthApi & OpenIdConnectApi & ProfileInfoApi & BackstageIdentityApi & SessionApi
>({
  id: 'auth.oidc',
});

/**
 * Alternative: Reuse Existing Provider Ref
 *
 * You can also reuse standard provider refs (e.g., oktaAuthApiRef) even if
 * your backend is custom OIDC/PKCE. This works because the interface is the same.
 *
 * @example
 * ```typescript
 * import { oktaAuthApiRef } from '@backstage/core-plugin-api';
 *
 * // Use Okta's ref with your custom OIDC backend
 * const myCustomOidcApi = ApiBlueprint.make({
 *   params: {
 *     factory: createApiFactory({
 *       api: oktaAuthApiRef,  // ← Reuse existing ref
 *       deps: { ... },
 *       factory: ({ configApi, discoveryApi, oauthRequestApi }) =>
 *         OAuth2.create({
 *           provider: { id: 'my-oidc', ... },  // Your provider ID
 *           configApi,
 *           discoveryApi,
 *           oauthRequestApi,
 *         }),
 *     }),
 *   },
 * });
 * ```
 */

/**
 * Key Points:
 *
 * 1. API Ref = Contract
 *    - Defines TypeScript interface
 *    - Used by both provider and consumers
 *
 * 2. ID Must Be Unique
 *    - Convention: 'auth.<provider-name>'
 *    - Cannot conflict with other API refs
 *
 * 3. Combine Interfaces
 *    - OAuthApi: Required for access tokens
 *    - OpenIdConnectApi: Required for ID tokens (OIDC providers)
 *    - ProfileInfoApi: User profile
 *    - BackstageIdentityApi: Backstage identity
 *    - SessionApi: Sign-in/sign-out
 *
 * 4. Alternative Approaches
 *    - Create custom ref (this file)
 *    - Create generic ref (genericOidcAuthApiRef)
 *    - Reuse existing ref (oktaAuthApiRef, googleAuthApiRef, etc.)
 *
 * 5. Where to Use
 *    - API extension factory (api: oidcPkceAuthApiRef)
 *    - Sign-in page provider (apiRef: oidcPkceAuthApiRef)
 *    - Component consumption (useApi(oidcPkceAuthApiRef))
 */
