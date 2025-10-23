# OIDC Kubernetes Authentication Implementation

## Goal

Enable user-scoped Kubernetes access in Backstage using OIDC authentication, where users can only see and interact with Kubernetes resources they have RBAC permissions for, while maintaining independent service account access for the ingestor plugin.

### Key Objectives

1. **Multi-Provider Authentication**: Support both GitHub (for Backstage catalog) and OIDC (for Kubernetes cluster access) authentication providers simultaneously
2. **User-Scoped Kubernetes RBAC**: Users see only the Kubernetes resources their identity has permissions for, enforced by cluster RBAC
3. **Automatic Token Acquisition**: OIDC tokens obtained on-demand when users access Kubernetes resources, not requiring separate login
4. **Per-Cluster Configuration**: Flexible authentication strategy per cluster (OIDC vs service account)
5. **Ingestor Independence**: XRD discovery and template generation continues using dedicated service account, unaffected by user authentication

## Context & Analysis

### Current Setup

**Authentication:**
- GitHub OAuth for Backstage catalog access
- Guest authentication for development

**Kubernetes Access:**
- Currently uses static service account token (`KUBERNETES_SERVICE_ACCOUNT_TOKEN`)
- All users share the same cluster admin credentials
- No user-level RBAC enforcement in Backstage

**OIDC Infrastructure:**
- Cluster: `openportal` (Rackspace HCP)
- Provider: Auth0 via `login.spot.rackspace.com`
- Client ID: `mwG3lUMV8KyeMqHe4fJ5Bb3nM1vBvRNa`
- Scopes: `openid`, `profile`, `email`
- Organization: `org_zOuCBHiyF1yG8d1D`
- Uses `kubectl` exec plugin with `oidc-login`

**Ingestor Plugin:**
- Discovers Crossplane XRDs from clusters
- Transforms XRDs into Backstage template entities
- Requires cluster-wide read access for resource discovery
- Currently shares authentication with Kubernetes plugin

### Architecture Insights

The kubeconfig reveals:
- **Two contexts**: `ngpc-user` (static token) and `oidc` (dynamic OIDC)
- **Auth0-based OIDC**: Provides standard claims (`email`, `name`, `sub`) plus custom claims (`group`)
- **JWT structure**: Includes `org_id` for multi-tenant organization support
- **Token caching**: kubectl uses `~/.kube/cache/oidc-login/` for token caching

## Choices Made

### 1. Authentication Flow: Automatic On-Demand OIDC

**Choice:** Automatic/on-demand OIDC token acquisition

**Rationale:**
- Better user experience - users don't need to authenticate twice
- OIDC credentials only requested when accessing Kubernetes resources
- Aligns with Backstage's existing auth flow patterns
- Users can still login with GitHub for catalog access

**Alternative Considered:** Separate OIDC login button
- Rejected: Creates friction and confusion (which provider to choose?)
- Users would need to understand the difference between GitHub and OIDC auth

### 2. Identity Mapping: Configurable Per-Cluster

**Choice:** Flexible identity resolver configuration per cluster

**Initial Configuration:**
- Start with email matching (`emailMatchingUserEntityProfileEmail`)
- Allow future reconfiguration to username/subject or custom claims
- Not required to match GitHub identity (independent auth systems)

**Rationale:**
- Different clusters may have different identity requirements
- Email is commonly available in both OIDC and Backstage user entities
- Flexibility to adapt as requirements evolve
- GitHub and OIDC identities can be separate (e.g., GitHub username vs corporate email)

**Options Available:**
- `emailMatchingUserEntityProfileEmail`: Match OIDC email with Backstage user entity email
- `usernameMatchingUserEntityName`: Match OIDC `preferred_username` with entity name
- Custom resolvers: Use specific OIDC claims (e.g., `sub`, `group`, custom attributes)

### 3. Cluster Scope: Per-Cluster Configuration

**Choice:** Individual authentication configuration per cluster

**Rationale:**
- Local development clusters (rancher-desktop, docker-desktop) can continue using service accounts
- Production clusters (openportal) can enforce OIDC with RBAC
- Gradual rollout - test OIDC on one cluster before expanding
- Different clusters may have different security requirements

**Configuration Strategy:**
```yaml
clusters:
  - name: openportal           # Production - OIDC required
    authProvider: oidc
  - name: rancher-desktop      # Local dev - service account
    authProvider: serviceAccount
```

### 4. Ingestor Authentication: Dedicated Service Account

**Choice:** Separate service account with cluster-wide read permissions for ingestor

**Rationale:**
- **Separation of concerns**: User permissions shouldn't affect system discovery
- **Reliability**: XRD discovery works regardless of which users are logged in
- **Security**: Least privilege - ingestor only needs read access, not write
- **Independence**: Template generation continues even if user auth fails

**Implementation:**
- Create `backstage-ingestor` ServiceAccount per cluster
- Grant cluster-wide read RBAC (ClusterRole + ClusterRoleBinding)
- Use dedicated token: `INGESTOR_SERVICE_ACCOUNT_TOKEN`
- Configure separately from user-facing Kubernetes plugin

## Implementation Plan

### Phase 1: OIDC Authentication Provider Setup

#### 1.1 Install OIDC Auth Module

**Backend Package:**
```bash
cd packages/backend
yarn add @backstage/plugin-auth-backend-module-oidc-provider
```

**Register Module:**
```typescript
// packages/backend/src/index.ts
backend.add(import('@backstage/plugin-auth-backend-module-oidc-provider'));
```

#### 1.2 Configure OIDC Provider

**Create/Update:** `app-config/auth.yaml`

```yaml
auth:
  environment: development
  providers:
    guest:
      userEntityRef: user:default/guest
      ownershipEntityRefs:
        - user:default/guest
        - group:default/all-users

    github:
      development:
        clientId: ${AUTH_GITHUB_CLIENT_ID}
        clientSecret: ${AUTH_GITHUB_CLIENT_SECRET}
        signIn:
          resolvers:
            - resolver: usernameMatchingUserEntityName

    # NEW: OIDC Provider for Kubernetes cluster access
    oidc:
      development:
        metadataUrl: https://login.spot.rackspace.com/.well-known/openid-configuration
        clientId: mwG3lUMV8KyeMqHe4fJ5Bb3nM1vBvRNa
        clientSecret: ${AUTH_OIDC_CLIENT_SECRET}
        scope: 'openid profile email'
        prompt: auto  # Prompt user when needed, not on every request
        # Additional Auth0 parameters
        additionalScopes:
          - organization
        signIn:
          resolver:
            # Start with email matching - reconfigurable later
            emailMatchingUserEntityProfileEmail: {}
```

**Environment Variables:**

Add to `.env.openportal.example` and encrypted `.env.enc`:
```bash
# OIDC Authentication for Kubernetes
AUTH_OIDC_CLIENT_SECRET=<obtain-from-auth0-console>
```

#### 1.3 Update Frontend Sign-In Page

**File:** `packages/app/src/App.tsx`

```typescript
import { githubAuthApiRef, oidcAuthApiRef } from '@backstage/core-plugin-api';

const signInPage = SignInPageBlueprint.make({
  params: {
    loader: async () => props =>
      (
        <SignInPage
          {...props}
          providers={[
            'guest',
            {
              id: 'github-auth-provider',
              title: 'GitHub',
              message: 'Sign in using GitHub',
              apiRef: githubAuthApiRef,
            },
            {
              id: 'oidc-auth-provider',
              title: 'Rackspace OIDC',
              message: 'Sign in using Rackspace SSO',
              apiRef: oidcAuthApiRef,
            },
          ]}
        />
      ),
  },
});
```

**Testing Phase 1:**
1. Start Backstage: `yarn start`
2. Visit sign-in page - verify OIDC option appears
3. Test OIDC login flow
4. Verify user entity resolved correctly

### Phase 2: Per-Cluster Kubernetes Authentication

#### 2.1 Update Kubernetes Configuration

**File:** `app-config/kubernetes.yaml`

```yaml
kubernetes:
  serviceLocatorMethod:
    type: 'multiTenant'

  clusterLocatorMethods:
    - type: 'config'
      clusters:
        # Production Cluster - OIDC User Authentication
        - name: openportal
          url: https://hcp-ebadc4bb-307d-482e-a9d9-fdca15fd5ff1.spot.rackspace.com/
          authProvider: oidc
          oidcTokenProvider: oidc  # References auth.providers.oidc
          skipTLSVerify: false
          # CA data from kubeconfig
          caData: ${KUBERNETES_OPENPORTAL_CA_DATA}
          # Optional: Custom identity claim mapping
          oidcOptions:
            # If email doesn't work, can switch to:
            # tokenProvider: custom
            # claimMapping:
            #   email: email
            #   name: name
            #   groups: group

        # Local Development Cluster - Service Account
        - name: ${KUBERNETES_CLUSTER_NAME:-rancher-desktop}
          url: ${KUBERNETES_API_URL}
          authProvider: serviceAccount
          serviceAccountToken: ${KUBERNETES_SERVICE_ACCOUNT_TOKEN}
          skipTLSVerify: true
```

#### 2.2 Environment Configuration

**Extract CA Data from kubeconfig:**
```bash
# Extract certificate-authority-data for openportal cluster
kubectl config view --raw -o jsonpath='{.clusters[?(@.name=="openportal")].cluster.certificate-authority-data}'
```

**Update `.env.openportal` or cluster-specific env file:**
```bash
# Kubernetes Cluster - OpenPortal Production
KUBERNETES_OPENPORTAL_CA_DATA=<base64-encoded-ca-cert>

# Backend service account (for ingestor)
KUBERNETES_SERVICE_ACCOUNT_TOKEN=<backend-service-account-token>
```

**Update Context-Specific Config:**

Create `app-config.openportal.local.yaml`:
```yaml
kubernetes:
  clusterLocatorMethods:
    - type: 'config'
      clusters:
        - name: openportal
          url: https://hcp-ebadc4bb-307d-482e-a9d9-fdca15fd5ff1.spot.rackspace.com/
          authProvider: oidc
          oidcTokenProvider: oidc
          caData: ${KUBERNETES_OPENPORTAL_CA_DATA}
```

### Phase 3: Ingestor with Dedicated Service Account

#### 3.1 Create Ingestor Service Account

**Script:** `scripts/create-ingestor-serviceaccount.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${1:-openportal}"
NAMESPACE="${2:-backstage-system}"

echo "Creating ingestor service account in cluster: $CLUSTER_NAME"

# Create namespace if it doesn't exist
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Create ServiceAccount
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backstage-ingestor
  namespace: $NAMESPACE
---
apiVersion: v1
kind: Secret
metadata:
  name: backstage-ingestor-token
  namespace: $NAMESPACE
  annotations:
    kubernetes.io/service-account.name: backstage-ingestor
type: kubernetes.io/service-account-token
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: backstage-ingestor-reader
rules:
  # Read XRDs and Compositions
  - apiGroups: ["apiextensions.k8s.io"]
    resources: ["customresourcedefinitions"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apiextensions.crossplane.io"]
    resources: ["compositeresourcedefinitions", "compositions"]
    verbs: ["get", "list", "watch"]
  # Read all resource types for discovery
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: backstage-ingestor-reader-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: backstage-ingestor-reader
subjects:
  - kind: ServiceAccount
    name: backstage-ingestor
    namespace: $NAMESPACE
EOF

# Wait for token to be created
echo "Waiting for token secret..."
kubectl wait --for=jsonpath='{.data.token}' \
  secret/backstage-ingestor-token \
  -n "$NAMESPACE" \
  --timeout=30s

# Extract token
TOKEN=$(kubectl get secret backstage-ingestor-token \
  -n "$NAMESPACE" \
  -o jsonpath='{.data.token}' | base64 -d)

echo ""
echo "✅ Ingestor service account created successfully!"
echo ""
echo "Add this to your .env.$CLUSTER_NAME file:"
echo "INGESTOR_SERVICE_ACCOUNT_TOKEN=$TOKEN"
```

**Run the script:**
```bash
chmod +x scripts/create-ingestor-serviceaccount.sh
./scripts/create-ingestor-serviceaccount.sh openportal
```

#### 3.2 Configure Ingestor Plugin

**Option A: If ingestor supports separate cluster config**

Update `app-config/ingestor.yaml`:
```yaml
ingestor:
  mappings:
    namespaceModel: 'namespace'
    systemModel: 'cluster'
    nameModel: 'name-namespace-cluster'
    titleModel: 'name'

  # Ingestor-specific cluster access (overrides kubernetes config)
  kubernetes:
    enabled: true
    clusters:
      # Production - dedicated ingestor service account
      - name: openportal
        url: https://hcp-ebadc4bb-307d-482e-a9d9-fdca15fd5ff1.spot.rackspace.com/
        authProvider: serviceAccount
        serviceAccountToken: ${INGESTOR_SERVICE_ACCOUNT_TOKEN}
        caData: ${KUBERNETES_OPENPORTAL_CA_DATA}

      # Local dev - shared service account
      - name: ${KUBERNETES_CLUSTER_NAME}
        url: ${KUBERNETES_API_URL}
        authProvider: serviceAccount
        serviceAccountToken: ${KUBERNETES_SERVICE_ACCOUNT_TOKEN}
        skipTLSVerify: true

    taskRunner:
      frequency: 20
      timeout: 600

    excludedNamespaces:
      - kube-public
      - kube-system
      - kube-node-lease
      - flux-system
      - crossplane-system
      - backstage-system

  crossplane:
    enabled: true
    xrds:
      enabled: true
      ingestAllXRDs: true
      templateDir: './ingestor-templates'
      taskRunner:
        frequency: 20
        timeout: 600
      gitops:
        owner: 'open-service-portal'
        repo: 'catalog-orders'
        targetBranch: 'main'
```

**Option B: If ingestor uses backend Kubernetes client**

The ingestor may need code changes to use a separate KubernetesClient instance. Check the ingestor plugin source to determine if it:
- Uses `@backstage/plugin-kubernetes-backend` client (shares user auth)
- Has its own client (can configure independently)

**Update `.env.openportal`:**
```bash
# Dedicated ingestor service account token
INGESTOR_SERVICE_ACCOUNT_TOKEN=<token-from-create-script>
```

### Phase 4: Testing & Validation

#### 4.1 Test OIDC Authentication Flow

**Test Cases:**

1. **GitHub Login (Existing Flow)**
   ```
   ✓ Login with GitHub
   ✓ Access catalog entities
   ✓ Verify no OIDC prompt yet
   ```

2. **Kubernetes Resource Access (New Flow)**
   ```
   ✓ Navigate to Kubernetes plugin page
   ✓ Verify OIDC consent prompt appears
   ✓ Complete OIDC authentication
   ✓ Verify resources load with user's RBAC scope
   ```

3. **User RBAC Enforcement**
   ```
   ✓ Create test user with limited RBAC (e.g., read-only to specific namespace)
   ✓ Login with that user
   ✓ Verify only permitted resources visible
   ✓ Verify forbidden resources return 403 errors (not shown)
   ```

4. **Token Caching**
   ```
   ✓ Access Kubernetes resources
   ✓ Navigate away and back
   ✓ Verify no re-authentication required (token cached)
   ✓ Check browser localStorage/sessionStorage for token
   ```

#### 4.2 Test Ingestor Independence

**Test Cases:**

1. **XRD Discovery**
   ```
   ✓ Ensure ingestor service account has proper permissions
   ✓ Check logs for successful cluster connections
   ✓ Verify XRDs discovered from all clusters
   ```

2. **Template Generation**
   ```
   ✓ Navigate to catalog templates
   ✓ Verify templates generated from XRDs
   ✓ Check template metadata (annotations, labels)
   ✓ Test template scaffolding
   ```

3. **User Auth Independence**
   ```
   ✓ Login with user having no Kubernetes permissions
   ✓ Verify templates still appear (ingestor uses service account)
   ✓ Template creation may fail (user has no write permissions) - expected behavior
   ```

#### 4.3 Test Per-Cluster Configuration

**Test Cases:**

1. **OIDC Cluster (openportal)**
   ```
   ✓ Select openportal cluster in UI
   ✓ Verify OIDC authentication required
   ✓ Check resources filtered by user RBAC
   ```

2. **Service Account Cluster (rancher-desktop)**
   ```
   ✓ Select rancher-desktop cluster in UI
   ✓ Verify no OIDC prompt (uses service account)
   ✓ Check resources visible (backend service account permissions)
   ```

3. **Cluster Switching**
   ```
   ✓ Switch between clusters
   ✓ Verify authentication method changes correctly
   ✓ Check no authentication errors
   ```

#### 4.4 Error Scenarios

**Test Cases:**

1. **OIDC Token Expired**
   ```
   ✓ Wait for token expiration (or manually expire)
   ✓ Access Kubernetes resources
   ✓ Verify automatic re-authentication prompt
   ```

2. **RBAC Forbidden**
   ```
   ✓ User tries to access forbidden resource
   ✓ Verify graceful error handling (not crash)
   ✓ Check error message clarity
   ```

3. **Cluster Unreachable**
   ```
   ✓ Configure unreachable cluster
   ✓ Verify timeout handling
   ✓ Check error messages
   ```

### Phase 5: Documentation

#### 5.1 Configuration Documentation

**Create:** `docs/backstage/kubernetes-authentication.md`

Topics:
- Overview of authentication architecture
- Per-cluster authentication configuration
- OIDC provider setup guide
- Identity resolver options and configuration
- Service account setup for backend
- Troubleshooting common issues

#### 5.2 Update Existing Documentation

**Update:** `app-portal/CLAUDE.md`
- Add OIDC authentication to Prerequisites
- Update Development Commands with OIDC env vars
- Add troubleshooting section for OIDC

**Update:** `CLAUDE.md` (workspace root)
- Document OIDC authentication in Integration Points
- Add to Development Guidelines
- Update Environment Variables section

#### 5.3 Create Runbooks

**Create:** `docs/runbooks/setup-oidc-cluster.md`
```markdown
# Setup OIDC Authentication for Kubernetes Cluster

## Prerequisites
- Kubernetes cluster with OIDC authentication configured
- OIDC provider details (issuer URL, client ID, client secret)
- Cluster CA certificate

## Steps
1. Configure cluster OIDC authentication
2. Create ingestor service account
3. Update app-config files
4. Test authentication flow

## Validation
- [ ] User can login with OIDC
- [ ] Resources filtered by RBAC
- [ ] Ingestor discovers XRDs
```

**Create:** `docs/troubleshooting/oidc-authentication.md`

Common issues:
- OIDC token not obtained
- RBAC permission errors
- Identity resolver not matching users
- Certificate validation failures
- Token expiration and refresh

## Security Considerations

### 1. Separation of User and System Authentication

**Principle:** Users authenticate with OIDC for personal access; system components use dedicated service accounts.

**Implementation:**
- User-facing Kubernetes plugin: OIDC with user's identity
- Backend ingestor plugin: Dedicated service account with read-only access
- Clear audit trail: User actions vs system actions

### 2. Least Privilege Access

**Ingestor Service Account:**
- Cluster-wide read permissions (get, list, watch)
- No write permissions (create, update, delete, patch)
- Scoped to specific resource types (XRDs, Compositions, CRDs)

**User RBAC:**
- Enforced by Kubernetes cluster
- Backstage respects cluster RBAC decisions
- No privilege escalation possible through Backstage

### 3. Token Security

**OIDC Tokens:**
- Short-lived (typically 1 hour)
- Automatic refresh when possible
- Stored in browser session storage (not localStorage)
- Never logged or exposed in UI

**Service Account Tokens:**
- Long-lived (Kubernetes secret-based)
- Stored in environment variables
- Encrypted at rest (SOPS)
- Never committed to git

### 4. Certificate Validation

**Production Clusters:**
- Always validate TLS certificates (`skipTLSVerify: false`)
- Use proper CA certificate from kubeconfig
- No self-signed certificates in production

**Local Development:**
- `skipTLSVerify: true` acceptable for local clusters
- Clearly documented as dev-only

## Migration Path

### Step 1: Add OIDC Without Enforcing (Week 1)
- Install OIDC provider
- Configure authentication
- Test with volunteers
- Gather feedback

### Step 2: Deploy Ingestor Service Account (Week 1)
- Create service accounts in all clusters
- Update ingestor configuration
- Verify XRD discovery still works
- No user-facing changes

### Step 3: Enable OIDC for Production Cluster (Week 2)
- Update kubernetes config for openportal cluster
- Communicate to users
- Monitor for issues
- Keep service account fallback available

### Step 4: Monitor and Optimize (Week 3+)
- Monitor authentication patterns
- Optimize token refresh timing
- Fine-tune RBAC permissions
- Document best practices

### Rollback Plan

If issues occur:
1. Revert kubernetes config to `authProvider: serviceAccount`
2. Remove OIDC provider from auth config (users can still use GitHub)
3. Restore previous environment variables
4. Restart Backstage

**Data Impact:** None - authentication is stateless

## Future Enhancements

### 1. Multiple OIDC Providers

Support different OIDC providers per cluster:
```yaml
auth:
  providers:
    oidc:
      rackspace:
        metadataUrl: https://login.spot.rackspace.com/.well-known/openid-configuration
      azure:
        metadataUrl: https://login.microsoftonline.com/tenant-id/v2.0/.well-known/openid-configuration
```

### 2. Custom Identity Resolvers

Implement custom resolver for complex identity mapping:
```typescript
// Map OIDC groups to Backstage user entity
const customResolver = async (oidcClaims, ctx) => {
  const groups = oidcClaims.group || [];
  const entityRef = `user:default/${oidcClaims.email}`;
  return { entity: entityRef, groups };
};
```

### 3. Dynamic Cluster Discovery

Auto-discover clusters from kubeconfig:
```yaml
kubernetes:
  clusterLocatorMethods:
    - type: kubeconfig
      authProvider: oidc  # Default for discovered clusters
```

### 4. Impersonation for Testing

Allow admins to impersonate users for testing RBAC:
```yaml
kubernetes:
  impersonation:
    enabled: true
    allowedGroups: ['backstage-admins']
```

## References

- [Backstage OIDC Authentication](https://backstage.io/docs/auth/oidc/)
- [Backstage Kubernetes Plugin Configuration](https://backstage.io/docs/features/kubernetes/configuration/)
- [Kubernetes Authentication](https://backstage.io/docs/features/kubernetes/authentication/)
- [Auth0 OIDC Documentation](https://auth0.com/docs/authenticate/protocols/openid-connect-protocol)
- [Kubernetes RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [kubectl OIDC Login Plugin](https://github.com/int128/kubelogin)

## Appendix: Configuration Examples

### Example: Email-Based Identity Resolver

```yaml
auth:
  providers:
    oidc:
      development:
        signIn:
          resolver:
            emailMatchingUserEntityProfileEmail: {}
```

**Requires:**
- OIDC claim `email` present
- Backstage user entity with matching `spec.profile.email`

### Example: Username-Based Identity Resolver

```yaml
auth:
  providers:
    oidc:
      development:
        signIn:
          resolver:
            usernameMatchingUserEntityName: {}
```

**Requires:**
- OIDC claim `preferred_username` present
- Backstage user entity name matches username

### Example: Custom Claim Resolver

```yaml
auth:
  providers:
    oidc:
      development:
        signIn:
          resolver:
            customClaim:
              claimName: 'sub'
              mapping: 'user:default/$CLAIM'
```

**Advanced:** Map OIDC `sub` claim to Backstage entity reference.

### Example: Multi-Cluster Configuration

```yaml
kubernetes:
  clusterLocatorMethods:
    - type: 'config'
      clusters:
        # Production - OIDC
        - name: openportal-prod
          url: https://prod.example.com
          authProvider: oidc
          oidcTokenProvider: oidc

        # Staging - OIDC
        - name: openportal-staging
          url: https://staging.example.com
          authProvider: oidc
          oidcTokenProvider: oidc

        # Development - Service Account
        - name: dev-cluster
          url: https://dev.example.com
          authProvider: serviceAccount
          serviceAccountToken: ${DEV_SA_TOKEN}

        # Local - Service Account
        - name: rancher-desktop
          url: https://127.0.0.1:6443
          authProvider: serviceAccount
          serviceAccountToken: ${LOCAL_SA_TOKEN}
          skipTLSVerify: true
```
