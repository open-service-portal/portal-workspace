# Kubernetes Users and Groups - The Complete Picture

## The Short Answer

**No, there is NO user-to-group mapping in Kubernetes.**

Kubernetes does NOT:
- ❌ Store users
- ❌ Store groups
- ❌ Map users to groups
- ❌ Manage group membership
- ❌ Have User or Group resources

## What Kubernetes DOES Have

Kubernetes ONLY has:
- ✅ **Authentication** - Verifying WHO you are
- ✅ **Authorization (RBAC)** - What authenticated identities CAN DO

```
┌─────────────────────────────────────────────────────────────┐
│                   External Identity Provider                │
│            (OIDC, LDAP, Certificates, etc.)                 │
│                                                             │
│  • Stores users                                             │
│  • Manages groups                                           │
│  • Maps users to groups                                     │
│  • Issues authentication tokens                             │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  │ Provides identity + groups in token/cert
                  ▼
┌─────────────────────────────────────────────────────────────┐
│              Kubernetes API Server                          │
│                                                             │
│  Authentication: Extracts identity from token/cert          │
│  • Username: "oidc:user@example.com"                        │
│  • Groups: ["oidc:developers", "oidc:admins"]              │
│                                                             │
│  Authorization: Checks RBAC rules                           │
│  • Does RoleBinding exist for this user/group?             │
│  • What permissions does this role grant?                   │
└─────────────────────────────────────────────────────────────┘
```

## How It Actually Works

### Step 1: Authentication (Identity Provider)

When you authenticate to Kubernetes, your identity provider (OIDC, certificates, etc.) tells Kubernetes:
- Who you are (username)
- What groups you belong to

**Example with OIDC (Auth0, Keycloak, Google, etc.)**:

```json
// ID Token from OIDC provider
{
  "sub": "user123",
  "email": "john@example.com",
  "groups": ["developers", "team-backend", "org-admins"]
}
```

Kubernetes API server extracts:
- Username: `oidc:john@example.com` (with prefix)
- Groups: `["oidc:developers", "oidc:team-backend", "oidc:org-admins"]`

### Step 2: Authorization (Kubernetes RBAC)

Kubernetes then checks its RBAC rules:

```yaml
# ClusterRoleBinding in Kubernetes
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: developers-edit-access
subjects:
- kind: Group
  name: oidc:developers  # This is just a STRING reference
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: edit
  apiGroup: rbac.authorization.k8s.io
```

Kubernetes says:
1. User `john@example.com` is in group `developers` (according to OIDC token)
2. Group `developers` has binding to `edit` role (according to this RBAC rule)
3. Therefore, user gets `edit` permissions

## The Key Insight

```
┌──────────────────────────────────────────────────────┐
│  "User john is in group developers"                 │
│                                                      │
│  WHERE IS THIS INFORMATION STORED?                  │
│                                                      │
│  ✗ NOT in Kubernetes                                │
│  ✓ In your OIDC provider (Auth0/Keycloak/etc.)     │
└──────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────┐
│  "Group developers has edit permissions"            │
│                                                      │
│  WHERE IS THIS INFORMATION STORED?                  │
│                                                      │
│  ✓ In Kubernetes (RoleBinding/ClusterRoleBinding)   │
└──────────────────────────────────────────────────────┘
```

## Authentication Methods and Group Sources

### 1. OIDC (Recommended for Production)

**Where user-to-group mapping lives**: OIDC Provider (Auth0, Keycloak, Google, etc.)

```yaml
# Kubernetes API server configuration
--oidc-issuer-url=https://auth.example.com
--oidc-client-id=kubernetes
--oidc-username-claim=email
--oidc-username-prefix=oidc:
--oidc-groups-claim=groups      # ← Extract groups from this claim
--oidc-groups-prefix=oidc:
```

**How to add user to group**:
1. Log in to Auth0/Keycloak/Google admin console
2. Navigate to user management
3. Add user to group
4. User gets new token with updated groups on next login

**Kubernetes never sees or stores this mapping** - it only receives the result in the token.

### 2. X.509 Client Certificates

**Where user-to-group mapping lives**: In the certificate itself

```bash
# Certificate subject
CN=john            # Username
O=developers       # Group 1
O=team-backend     # Group 2
```

The certificate is issued by your Certificate Authority (CA). The groups are embedded in the certificate and cannot be changed without issuing a new certificate.

**How to add user to group**:
1. Generate new certificate with updated O (Organization) fields
2. Sign with Kubernetes CA
3. User uses new certificate

### 3. Service Account Tokens

**Where user-to-group mapping lives**: Hardcoded in Kubernetes

Service accounts automatically belong to:
- `system:serviceaccounts` (all service accounts)
- `system:serviceaccounts:<namespace>` (namespace-specific)

```bash
# Service account in namespace "myapp"
Username: system:serviceaccount:myapp:myservice
Groups:
  - system:serviceaccounts
  - system:serviceaccounts:myapp
  - system:authenticated
```

This is the ONLY case where Kubernetes manages the user-to-group relationship, and it's automatic/fixed.

## Common Misconceptions

### ❌ Misconception 1: "kubectl can manage groups"

```bash
# This does NOT exist:
kubectl create group developers
kubectl add user john to group developers
```

There are NO such commands because Kubernetes doesn't manage groups.

### ❌ Misconception 2: "I can see my groups in Kubernetes"

```bash
kubectl get groups
# Error: the server doesn't have a resource type "groups"
```

You cannot list groups because they don't exist as resources.

### ✅ What You CAN Do

```bash
# See what groups are REFERENCED in RBAC bindings
kubectl get clusterrolebindings -o json | \
  jq -r '.items[].subjects[]? | select(.kind=="Group") | .name' | sort -u

# See your own identity (including groups from your token)
kubectl auth whoami
# Output shows groups that came from your authentication token
```

## Real-World Example

Let's trace a complete authentication flow:

### Setup in Auth0 (OIDC Provider)

```
Users:
  - john@example.com
    └─ Member of groups: ["developers", "team-backend"]
  - jane@example.com
    └─ Member of groups: ["developers", "team-frontend"]
  - admin@example.com
    └─ Member of groups: ["platform-admins"]
```

### Setup in Kubernetes

```yaml
# ClusterRoleBinding for developers group
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: developers-access
subjects:
- kind: Group
  name: oidc:developers
roleRef:
  kind: ClusterRole
  name: edit

---
# ClusterRoleBinding for platform-admins group
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admins-access
subjects:
- kind: Group
  name: oidc:platform-admins
roleRef:
  kind: ClusterRole
  name: cluster-admin
```

### What Happens When John Logs In

1. **John authenticates with Auth0**:
   ```
   Browser → Auth0: "Username: john@example.com, Password: ***"
   Auth0: "Valid! Here's your ID token"
   ```

2. **Auth0 issues token with groups**:
   ```json
   {
     "email": "john@example.com",
     "groups": ["developers", "team-backend"]
   }
   ```

3. **John uses kubectl**:
   ```bash
   kubectl get pods
   ```

4. **Kubernetes extracts identity from token**:
   ```
   Username: oidc:john@example.com
   Groups: ["oidc:developers", "oidc:team-backend"]
   ```

5. **Kubernetes checks RBAC**:
   ```
   User is in group "oidc:developers"
   Group "oidc:developers" has ClusterRoleBinding to "edit" role
   → Grant "edit" permissions
   ```

6. **John can now perform edit operations** ✓

### What Happens When You Add Jane to team-backend

1. **Admin logs in to Auth0**:
   ```
   Admin → Auth0 Admin Console
   Users → jane@example.com
   Groups → Add to "team-backend"
   ```

2. **Auth0 updates its database**:
   ```
   jane@example.com groups: ["developers", "team-frontend", "team-backend"]
   ```

3. **Jane logs out and logs back in to Kubernetes**:
   ```bash
   # Jane's new token now includes team-backend group
   kubectl auth whoami
   # Shows: oidc:developers, oidc:team-frontend, oidc:team-backend
   ```

4. **Kubernetes never knew about this change until Jane's new token arrived**

**Key Point**: Kubernetes did NOT receive any notification that Jane was added to the group. It only sees the updated group list when Jane uses her new token.

## How to Think About It

Think of Kubernetes RBAC like a **door access system**:

```
┌─────────────────────────────────────────────────────┐
│  Security Badge (OIDC Token)                        │
│                                                     │
│  Name: John Smith                                   │
│  Department: Engineering                            │
│  Groups: Developers, Team-Backend                   │
│                                                     │
│  Issued by: Corporate HR (OIDC Provider)           │
└─────────────────────────────────────────────────────┘
           │
           │ Presents badge at door
           ▼
┌─────────────────────────────────────────────────────┐
│  Door Access System (Kubernetes RBAC)               │
│                                                     │
│  Rules:                                             │
│  • Group "Developers" → Can enter Lab               │
│  • Group "Team-Backend" → Can enter Server Room    │
│  • Individual "John Smith" → No special access     │
│                                                     │
│  Verification:                                      │
│  John is in "Developers" group? YES (from badge)   │
│  Does "Developers" have Lab access? YES (from DB)  │
│  → Open Lab door ✓                                 │
└─────────────────────────────────────────────────────┘
```

- **HR System (OIDC Provider)**: Manages who is in which department/group
- **Badge (Token)**: Carries group membership information
- **Door System (Kubernetes)**: Checks badge and enforces access rules
- **Door System does NOT manage groups** - it just reads them from the badge!

## Practical Implications

### 1. Adding Users to Groups

```bash
# ❌ This doesn't work (no such thing):
kubectl add user john@example.com to group developers

# ✓ This is what you do:
# 1. Log in to your OIDC provider (Auth0/Keycloak/etc.)
# 2. Navigate to user management
# 3. Add john@example.com to developers group
# 4. John logs out and back in
# 5. John now has developers group in token
```

### 2. Listing Group Members

```bash
# ❌ This doesn't work (Kubernetes doesn't know):
kubectl get users in group developers

# ✓ This is what you do:
# Log in to your OIDC provider and check group membership there
# OR check your OIDC provider's API
# OR check audit logs to see which users authenticated with that group
```

### 3. Removing Users from Groups

```bash
# ❌ This doesn't work:
kubectl remove user john@example.com from group developers

# ✓ This is what you do:
# 1. Log in to your OIDC provider
# 2. Remove john@example.com from developers group
# 3. John's CURRENT sessions still work (old token still valid)
# 4. When token expires or John logs out/in, new token won't have the group
```

### 4. Auditing Group Access

```bash
# ❌ Can't do this (Kubernetes doesn't know):
kubectl get users with cluster-admin access

# ✓ Can do this (check RBAC rules):
# See which groups have cluster-admin
kubectl get clusterrolebindings -o json | \
  jq -r '.items[] | select(.roleRef.name=="cluster-admin") |
  .subjects[]? | select(.kind=="Group") | .name'

# Then check your OIDC provider to see who's in those groups
```

## Why This Design?

### Advantages

1. **Separation of Concerns**:
   - Identity provider: Manages users and groups (their expertise)
   - Kubernetes: Manages authorization (its expertise)

2. **Flexibility**:
   - Swap OIDC providers without changing Kubernetes config
   - Use existing corporate identity systems (LDAP, AD, SAML)

3. **Scalability**:
   - Kubernetes doesn't store thousands of user records
   - Identity changes happen instantly (in next token)

4. **Security**:
   - Kubernetes doesn't become an identity store
   - No password management in Kubernetes
   - Token-based, time-limited access

### Disadvantages

1. **Confusion**:
   - Users expect user/group management to be in Kubernetes
   - Need to understand external identity providers

2. **Troubleshooting**:
   - Must check OIDC provider AND Kubernetes RBAC
   - Group membership not visible in Kubernetes

3. **Token Expiration**:
   - Removed users still have access until token expires
   - Need short token lifetimes for security

## Summary Table

| Concept | Stored In | Managed By | Visible in Kubernetes |
|---------|-----------|------------|----------------------|
| User identity | OIDC Provider / Certificate | Identity Provider | No (only username string) |
| User password | OIDC Provider | Identity Provider | No |
| Group membership | OIDC Provider / Certificate | Identity Provider | No |
| Group → Role mapping | Kubernetes RBAC | Kubernetes Admin | Yes (RoleBindings) |
| Role → Permissions | Kubernetes RBAC | Kubernetes Admin | Yes (Roles/ClusterRoles) |

## Quick Reference

### What's in Kubernetes?
```yaml
# RBAC Rules (what groups CAN DO)
ClusterRoleBinding:
  subjects:
  - kind: Group
    name: oidc:developers  # Just a string reference!
  roleRef:
    name: edit  # The permissions this group gets
```

### What's in OIDC Provider?
```
# User-to-Group Mapping (WHO is in which groups)
Users:
  john@example.com → groups: [developers, team-backend]
  jane@example.com → groups: [developers, team-frontend]
```

### The Bridge Between Them
```
# OIDC Token (carries group membership to Kubernetes)
{
  "email": "john@example.com",
  "groups": ["developers", "team-backend"]
}
```

---

**Key Takeaway**: Kubernetes is like a bouncer checking IDs. The bouncer doesn't issue IDs or decide who gets which ID. The bouncer only checks: "Does this ID (token) say you're in the VIP group (developers)? Yes? Then you can enter the VIP area (get edit permissions)."

The DMV/government (OIDC provider) issues the IDs and decides what's written on them. The bouncer (Kubernetes) just enforces the rules based on what the ID says.

---

**Generated**: 2025-10-31
