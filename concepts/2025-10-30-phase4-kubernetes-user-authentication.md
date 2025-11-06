# Phase 4: Kubernetes User Authentication Integration

**Date:** 2025-10-30
**Status:** Planning
**Related:** Phase 1-2 (Cluster Authentication) - Complete

## Overview

This document outlines the strategy for integrating user-specific OIDC tokens with Kubernetes operations in Backstage. The goal is to replace service account tokens with user tokens where appropriate, ensuring proper RBAC enforcement and audit attribution.

## Problem Statement

### Current State

Currently, ALL Kubernetes operations in Backstage use a single service account token (`backstage-sa`):

- **Catalog Discovery:** Ingestor plugin discovers all K8s resources the service account can see
- **Resource Viewing:** Users see catalog entries for resources they may not have access to
- **Resource Creation:** Scaffolder creates resources using service account credentials
- **Audit Logs:** All operations attributed to `system:serviceaccount:backstage:backstage-sa`

### Issues

1. **No RBAC Enforcement:** Users can create resources in namespaces they shouldn't access
2. **Poor Audit Trail:** Cannot determine who actually performed an operation
3. **Security Risk:** Single compromised account affects all users
4. **Visibility Leakage:** Users see catalog entries for restricted resources
5. **Compliance Problems:** No attribution for regulatory requirements

## User Journeys

### Current Experience (Service Account Auth)

**Alice's Story:**
```
1. Alice logs into Backstage with GitHub
   → Authenticated as "user:default/alice"

2. Alice browses /catalog
   → Sees "team-b-production-api" even though she only has team-a access
   → Sees "finance-database" even though she's in engineering
   → Confusing: Why can she see these if she can't use them?

3. Alice creates "my-test-app" via scaffolder
   → Uses template to create Crossplane XR
   → Scaffolder applies with backstage-sa token
   → Success! Resource created in team-b namespace
   → Problem: Alice shouldn't have access to team-b!

4. Platform team reviews audit logs
   → See: "system:serviceaccount:backstage:backstage-sa created my-test-app"
   → Cannot determine which user actually created it
   → Compliance nightmare for regulated industries
```

### Desired Experience (User Token Auth)

**Alice's Story:**
```
1. Alice logs into Backstage with GitHub
   → Authenticated as "user:default/alice"

2. Alice authenticates with K8s cluster (one-time)
   → Settings → Auth Providers → K8s Cluster → Sign In
   → Gets OIDC tokens (valid 3 days)
   → Tokens stored securely in database

3. Alice browses /catalog
   → Only sees resources in namespaces she has access to
   → "team-a-api" (visible - she has access)
   → "team-b-production-api" (not shown - no access)
   → Clean, focused view of HER resources

4. Alice creates "my-test-app" via scaffolder
   → Uses template to create Crossplane XR
   → Scaffolder uses Alice's OIDC token
   → K8s enforces Alice's RBAC permissions
   → If Alice tries to create in team-b: DENIED
   → Can only create in team-a (her namespace)

5. Platform team reviews audit logs
   → See: "alice@example.com created my-test-app in team-a"
   → Clear attribution, perfect for compliance
   → Can track exactly who did what, when
```

## Components Analysis

### Read Operations (Query Kubernetes)

#### 1. Ingestor Plugin
**Location:** Backend (`@open-service-portal/backstage-plugin-ingestor`)
**Purpose:** Background job that discovers K8s resources every 60 seconds

**What It Does:**
- Scans clusters for XRDs, XRs, Deployments, Services, Pods
- Creates Backstage catalog entities for discovered resources
- Runs continuously in background (no user context)

**Current Auth:** Service Account
**K8s Operations:** List/Get resources across all namespaces
**User Visibility:** Catalog entries appear at `/catalog`

**Challenge:** No user context (background task)

---

#### 2. Kubernetes Plugin
**Location:** Backend (`@backstage/plugin-kubernetes-backend`)
**Purpose:** Show K8s resources linked to catalog entities

**What It Does:**
- When user views entity → Shows related Pods, Deployments, Services
- Real-time resource status
- Pod logs and events

**Current Auth:** Service Account
**K8s Operations:** List/Get resources for specific entities
**User Visibility:** Entity page → "Kubernetes" tab

**Challenge:** Shows resources user might not have K8s access to

---

#### 3. TeraSky Crossplane Plugin
**Location:** Frontend (`@terasky/backstage-plugin-crossplane-resources-frontend`)
**Purpose:** Display Crossplane-specific resource details

**What It Does:**
- Shows Crossplane XRs and their composition hierarchy
- Displays resource dependency graphs
- Real-time status of managed resources

**Current Auth:** Piggybacks on Kubernetes plugin (Service Account)
**K8s Operations:** List/Get XRs, Compositions, managed resources
**User Visibility:** Entity page → "Infrastructure" and "Dependencies" tabs

**Challenge:** Shows infrastructure user shouldn't see

---

#### 4. Catalog Backend
**Location:** Backend (`@backstage/plugin-catalog-backend`)
**Purpose:** Store and serve catalog entities

**What It Does:**
- Query catalog database (NOT Kubernetes directly)
- Filter, search, paginate entities
- Serve results to frontend

**Current Auth:** N/A (database operations)
**K8s Operations:** None
**User Visibility:** `/catalog` page

**Note:** Could use Permission Plugin to filter results based on user

---

### Write Operations (Mutate Kubernetes)

#### 5. Scaffolder Plugin
**Location:** Backend (`@backstage/plugin-scaffolder-backend`)
**Purpose:** Execute software templates

**What It Does:**
- User fills template form at `/create`
- Executes template steps (fetch, render, publish)
- Most templates use `kube:apply` action to create K8s resources

**Current Auth:** Service Account
**K8s Operations:** Create/Update resources via template actions
**User Visibility:** `/create` page, template execution logs

**CRITICAL:** This is where user attribution matters most

---

#### 6. Kubernetes Scaffolder Actions
**Location:** External package (`@devangelista/backstage-scaffolder-kubernetes`)
**Purpose:** Provide low-level K8s operations for templates

**Available Actions:**
- `kube:apply` - Create or update resources
- `kube:delete` - Delete resources
- `kube:job:wait` - Wait for job completion
- `kube:patch` - Patch existing resources

**Current Auth:** Service Account from kubernetes config
**K8s Operations:** Direct resource manipulation
**User Visibility:** Used in template steps

**PROBLEM:** All creates/deletes attributed to service account

---

## Authentication Strategy

### Decision Matrix: Service Account vs User Token

| Criteria | Service Account | User Token |
|----------|----------------|------------|
| **Cluster-wide metadata gathering** | ✅ Best | ❌ Incomplete view |
| **User-specific resource listing** | ❌ Shows everything | ✅ Shows user's access |
| **Resource creation** | ❌ No attribution | ✅ Clear attribution |
| **Resource updates** | ❌ No attribution | ✅ Clear attribution |
| **Audit requirements** | ❌ Poor audit trail | ✅ Full audit trail |
| **RBAC enforcement** | ❌ Bypasses user RBAC | ✅ Enforces user RBAC |
| **Template definition discovery** | ✅ Templates are public | ❌ Unnecessary complexity |
| **Background tasks** | ✅ No user context needed | ❌ Requires user context |

### Recommended Strategy

| Operation Type | Component | Auth Method | Justification |
|---------------|-----------|-------------|---------------|
| **Template Discovery** | Ingestor XRD scanning | Service Account | Templates define WHAT CAN be created (public info) |
| **Resource Discovery** | Ingestor resource scanning | Service Account | Discover everything, filter at catalog level |
| **Catalog Display** | Catalog Backend | Permission Plugin | Filter based on user's K8s permissions |
| **View K8s Resources** | Kubernetes Plugin | User Token | Only show pods/deployments user can access |
| **View Crossplane** | TeraSky Plugin | User Token | Only show XRs user manages |
| **Create Resources** | Scaffolder Actions | User Token | Enforce RBAC, enable audit |
| **Update Resources** | Scaffolder Actions | User Token | Enforce RBAC, enable audit |
| **Delete Resources** | Scaffolder Actions | User Token | Enforce RBAC, enable audit |

### Key Principles

**Use SERVICE ACCOUNT when:**
- Operation is cluster-wide metadata gathering
- No user context available (background tasks)
- Information is public/non-sensitive (template definitions)
- Need consistent, reliable discovery regardless of user

**Use USER TOKEN when:**
- Operation shows data to specific user
- Operation mutates resources
- Need audit trail of WHO did WHAT
- Need K8s RBAC enforcement

---

## Implementation Phases

### Phase 4.1: Scaffolder Write Operations (Week 1)
**Priority:** CRITICAL
**Goal:** All resource creation uses user tokens

**Approach:**
1. Create custom scaffolder action `portal:kube:apply`
2. Action retrieves user's cluster token from database
3. Action applies manifest with user credentials
4. Update template generator to use new action

**Benefits:**
- User RBAC enforced immediately
- Audit logs show actual user
- Users can't create in unauthorized namespaces
- Quick win with high impact

**Components Modified:**
- New: `packages/backend/src/scaffolder/kubeApplyWithUserToken.ts`
- New: `packages/backend/src/scaffolder/clusterTokenFetcher.ts`
- New: `packages/backend/src/scaffolder/userKubeClient.ts`
- Modified: `packages/backend/src/scaffolder/index.ts` (register action)
- Modified: Ingestor templates to generate `portal:kube:apply` instead of `kube:apply`

**Backward Compatibility:**
- Keep `kube:apply` for platform operations
- Add `portal:kube:apply` for user operations
- Gradual migration via template regeneration

---

### Phase 4.2: Catalog Visibility Filtering (Week 2-3)
**Priority:** HIGH
**Goal:** Users only see catalog entries for accessible resources

**Approach - Option A (Recommended):**
1. Ingestor continues using service account to discover ALL resources
2. During ingestion, tag entities with required K8s permissions
3. Catalog API checks user's permissions before returning entities
4. Cache permission checks to maintain performance

**Approach - Option B (Alternative):**
1. Permission plugin integration
2. Before showing entity, verify user can read corresponding K8s resource
3. Use `kubectl auth can-i` equivalent with user token
4. Return 404 for unauthorized resources

**Benefits:**
- Clean, focused catalog view
- No confusion about inaccessible resources
- Better UX (don't see what you can't use)

**Components Modified:**
- Modified: Catalog permission rules
- New: Permission check before entity display
- Modified: Ingestor to tag entities with permissions

**Trade-offs:**
- Adds latency to catalog queries (mitigated with caching)
- More complex permission logic
- Need to handle edge cases (recently revoked access)

---

### Phase 4.3: Kubernetes Plugin Auth (Future)
**Priority:** MEDIUM
**Goal:** Entity K8s tabs respect user permissions

**Approach:**
1. Kubernetes plugin backend accepts user token
2. Frontend passes user authentication to backend
3. Backend queries K8s with user credentials
4. Shows only pods/deployments user can access

**Benefits:**
- Consistent auth model across all K8s operations
- Entity pages show accurate, accessible data
- Better security posture

**Components Modified:**
- Modified: `@backstage/plugin-kubernetes-backend` integration
- Modified: K8s client configuration per request

**Deferral Reason:**
- Lower priority than write operations
- Current behavior: Shows resources but user can't access them
- Acceptable temporary state while write operations are protected

---

### Phase 4.4: TeraSky Crossplane Plugin (Future)
**Priority:** LOW
**Goal:** Infrastructure tabs respect user permissions

**Dependency:** Requires Phase 4.3 completed first

**Approach:**
- Crossplane plugin uses same user token mechanism as K8s plugin
- Inherits authentication from underlying K8s queries

**Benefits:**
- Complete end-to-end user auth
- All UI components respect permissions

---

## Decision Points

### 1. Ingestor Discovery Strategy

**Question:** How should ingestor handle user-specific discovery?

**Option A: Discover All, Filter at Catalog**
- Ingestor uses service account to see everything
- Tag entities with required permissions during ingestion
- Catalog filters based on user's tokens
- **Pros:** Simple, reliable, complete view for platform team
- **Cons:** Catalog has entries user can't see (but they're filtered)

**Option B: Per-User Ingestion**
- Run ingestor with each user's context
- Only discover resources user can see
- **Pros:** True multi-tenant isolation
- **Cons:** Extremely complex, performance issues, stale data

**Recommendation:** Option A (discover all, filter at display)

---

### 2. Catalog Filtering Implementation

**Question:** When/how do we check user permissions?

**Option A: On-Query Permission Checks**
- Every catalog query checks K8s access in real-time
- Most accurate, always up-to-date
- **Pros:** Accurate, respects recent permission changes
- **Cons:** Slow, lots of K8s API calls

**Option B: Tag-Based Filtering**
- Tag entities with required roles during ingestion
- Filter catalog by user's roles (from identity)
- **Pros:** Fast, scalable, low K8s API load
- **Cons:** May be stale, requires role mapping

**Option C: Hybrid Caching**
- Check permissions on first access
- Cache results for user+resource
- Expire cache after 5 minutes
- **Pros:** Good balance of accuracy and performance
- **Cons:** Some complexity, cache invalidation

**Recommendation:** Start with Option B, optimize to Option C

---

### 3. Template Migration

**Question:** How do we update templates to use new action?

**Option A: Auto-Update via Ingestor**
- Ingestor generates templates with `portal:kube:apply`
- All templates automatically use user tokens
- Happens during next XRD discovery cycle
- **Pros:** Automatic, consistent, no manual work
- **Cons:** Must ensure backward compatibility

**Option B: Manual Template Updates**
- Platform team manually edits templates
- Gradual rollout, more control
- **Pros:** Control over timing
- **Cons:** Error-prone, slow, requires coordination

**Recommendation:** Option A (templates are auto-generated from XRDs)

---

### 4. Backward Compatibility

**Question:** What about existing templates and workflows?

**Strategy:**
- Keep `kube:apply` action (service account) for platform operations
- Add `portal:kube:apply` action (user token) for user operations
- Maintain both in parallel
- Platform operations (admin tasks) continue using SA
- User operations (self-service) use user tokens

**Migration Path:**
1. Deploy new `portal:kube:apply` action (doesn't break existing)
2. Update ingestor templates to generate new action
3. Existing templates continue working
4. New templates use user auth
5. Gradually deprecate SA-based templates for user operations

---

## Security Considerations

### Token Storage
- User OIDC tokens stored encrypted in database
- Tokens expire after 3 days (automatic re-auth required)
- No refresh tokens in database (security decision)

### Token Access
- Only scaffolder actions can access stored tokens
- Tokens retrieved per-request, not cached in memory
- Database queries check user entity ref matches requester

### Failure Modes

**Token Not Found:**
- User hasn't authenticated with cluster yet
- Error message: "Please authenticate at Settings → Auth Providers → K8s Cluster"
- Template execution fails gracefully with clear instructions

**Token Expired:**
- Tokens valid 3 days, no automatic refresh
- Error message: "Cluster token expired. Please re-authenticate."
- User must manually sign in again

**Insufficient RBAC:**
- User authenticated but lacks K8s permissions
- K8s API returns 403 Forbidden
- Error message shows actual K8s RBAC error
- Example: "User alice@example.com cannot create XRs in namespace team-b"

**Network Issues:**
- K8s API unreachable
- Timeout after 30 seconds
- Retry logic with exponential backoff
- Clear error message to user

---

## Performance Considerations

### Catalog Filtering Impact

**Current:**
- Catalog query: ~50ms (database only)

**With Permission Checks:**
- Catalog query: ~200ms (database + K8s API checks)
- At scale: 1000 entities × 5ms per check = 5 seconds 😱

**Mitigation Strategies:**

1. **Batch Permission Checks**
   - Check multiple resources in single K8s API call
   - Use `SelfSubjectAccessReview` with batch requests
   - Reduce 1000 calls to ~10 batch calls

2. **Permission Caching**
   - Cache user's access per namespace
   - Cache TTL: 5 minutes
   - Invalidate on user re-authentication
   - Example: Cache "Alice can read team-a" for 5min

3. **Lazy Loading**
   - Return catalog results immediately
   - Check permissions in background
   - Hide entities asynchronously if unauthorized
   - Better UX: Fast initial load, gradual refinement

4. **Index by Namespace**
   - Tag entities with namespace during ingestion
   - First filter by namespaces user has access to
   - Only check permissions for those entities
   - Reduces permission checks by 80%+

**Recommendation:** Combine strategies 2 + 4 (caching + namespace indexing)

---

## Monitoring & Observability

### Metrics to Track

**Authentication:**
- User cluster authentications per day
- Token expirations requiring re-auth
- Failed authentication attempts

**Authorization:**
- RBAC denials per user
- Most common permission errors
- Resources frequently accessed but unauthorized

**Performance:**
- Catalog query latency (with/without permission checks)
- K8s API call volume from Backstage
- Cache hit rates for permission checks
- Scaffolder action execution time

**Audit:**
- Resources created per user
- Most active users
- Namespace usage patterns
- Compliance report: All creates/updates with user attribution

---

## Rollout Strategy

### Stage 1: Internal Testing (Week 1)
- Deploy Phase 4.1 to development cluster
- Test with platform team accounts
- Verify audit logs show correct users
- Confirm RBAC enforcement works

### Stage 2: Limited Rollout (Week 2)
- Enable for single team (pilot program)
- Monitor error rates
- Gather feedback on UX
- Tune error messages based on user confusion

### Stage 3: Full Production (Week 3-4)
- Enable Phase 4.1 for all users
- Deploy Phase 4.2 catalog filtering
- Monitor performance impact
- Adjust caching strategy if needed

### Stage 4: Future Enhancements
- Phase 4.3: Kubernetes plugin auth
- Phase 4.4: TeraSky plugin auth
- Advanced permission caching
- Multi-cluster improvements

---

## Success Criteria

### Phase 4.1 Complete When:
- ✅ All scaffolder templates use `portal:kube:apply`
- ✅ Resource creation enforces user RBAC
- ✅ Audit logs show user identity (not service account)
- ✅ Clear error messages when RBAC denies operation
- ✅ No regressions in template execution success rate

### Phase 4.2 Complete When:
- ✅ Catalog only shows resources user can access
- ✅ Permission check latency < 100ms per query
- ✅ Cache hit rate > 80%
- ✅ No false positives (hiding accessible resources)
- ✅ No false negatives (showing inaccessible resources)

### Overall Success:
- ✅ Users can only create resources in authorized namespaces
- ✅ Users only see catalog entries for accessible resources
- ✅ Audit logs provide full attribution trail
- ✅ Platform team can track usage per user/team
- ✅ Compliance requirements satisfied

---

## Open Questions

1. **Multi-Cluster Support:**
   - Users may need different tokens per cluster
   - How do we handle cluster selection in scaffolder?
   - Should users authenticate once per cluster?

2. **Service Account Fallback:**
   - What if user hasn't authenticated yet?
   - Should templates fail or fall back to SA?
   - How do we communicate this to users?

3. **Team Tokens:**
   - Some teams share credentials
   - Should we support team-level tokens?
   - How would this impact audit attribution?

4. **Token Rotation:**
   - Current: 3-day expiration, manual re-auth
   - Future: Automatic background refresh?
   - Requires oidc-authenticator daemon changes

5. **Permission Complexity:**
   - Some resources span multiple namespaces
   - How do we handle cross-namespace dependencies?
   - Example: XR in team-a creates Service in team-b

---

## Related Documentation

- Phase 1-2: Cluster Authentication (Complete)
- Phase 3: Token Refresh (Deferred)
- OIDC Authenticator Daemon Integration
- Kubernetes RBAC Setup Guide
- Crossplane v2 Architecture

---

## Appendix: Terminology

**Service Account (SA):** Kubernetes service account used by Backstage backend
**OIDC Token:** OpenID Connect token from Auth0/OIDC provider
**User Token:** User's OIDC access token stored in Backstage
**XR:** Crossplane Composite Resource (v2 style)
**XRD:** Crossplane Composite Resource Definition (the "menu")
**RBAC:** Role-Based Access Control in Kubernetes
**Ingestor:** Backstage plugin that discovers K8s resources
**Scaffolder:** Backstage plugin that executes templates

---

**Status:** Ready for implementation
**Next Step:** Begin Phase 4.1 (Scaffolder Actions)
**Owner:** Platform Team
**Reviewers:** Security Team, DevOps Team
