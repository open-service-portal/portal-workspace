# User Creation Methods - Comparison Guide

## Overview

There are two ways to create test users in this system:

1. **`create-user.sh`** - Individual ServiceAccount with individual permissions
2. **`create-user-with-group.sh`** ⭐ - ServiceAccount in a shared namespace for group-based permissions

## Quick Comparison

| Feature | create-user.sh | create-user-with-group.sh |
|---------|---------------|---------------------------|
| **Group support** | ❌ None | ✅ Via namespace |
| **Namespace** | Per-user or shared | Shared (the "group") |
| **Permissions** | Individual bindings | Group bindings |
| **Scalability** | One binding per user | One binding per group |
| **Best for** | Individual testing | Team-based testing |
| **Group membership** | N/A | Automatic via namespace |

## Method 1: create-user.sh (Individual Users)

### Usage
```bash
./scripts/create-user.sh <username> [permission] [namespace]
```

### How It Works
```
1. Create ServiceAccount in specified namespace
2. Create individual RoleBinding/ClusterRoleBinding for this user
3. Generate kubeconfig

Result: User has direct permissions, no group concept
```

### Example
```bash
# Create alice with edit access in myapp namespace
./scripts/create-user.sh alice edit myapp

# This creates:
# - ServiceAccount: myapp/alice
# - RoleBinding: myapp/alice-edit (alice → edit role)
# - Groups: system:serviceaccounts:myapp (automatic)
```

### Groups
ServiceAccount automatically gets these groups:
- `system:serviceaccounts` (all service accounts)
- `system:serviceaccounts:myapp` (all SAs in myapp namespace)
- `system:authenticated` (all authenticated)

**But**: These groups are tied to the namespace where the SA was created, not a "team" concept.

### Use Cases
✅ Quick single-user testing
✅ CI/CD pipelines (one SA per pipeline)
✅ Individual permissions needed
✅ Different users need different namespaces

❌ Team-based testing (hard to manage)
❌ Multiple users with same permissions (lots of bindings)
❌ Group-based access control

## Method 2: create-user-with-group.sh (Group-Based) ⭐

### Usage
```bash
./scripts/create-user-with-group.sh <username> <group-namespace> [permission]
```

### How It Works
```
1. Ensure "group namespace" exists (e.g., "developers")
2. Create ServiceAccount in the group namespace
3. Optionally create individual permissions
4. Generate kubeconfig

Result: User belongs to group via namespace membership
```

### Example
```bash
# Create alice in developers group
./scripts/create-user-with-group.sh alice developers none

# Create bob in developers group
./scripts/create-user-with-group.sh bob developers none

# Both are now in group: system:serviceaccounts:developers

# Grant permissions to the ENTIRE group once:
kubectl create rolebinding developers-edit \
  --clusterrole=edit \
  --group=system:serviceaccounts:developers \
  -n developers

# Now BOTH alice and bob have edit access!
```

### Groups
ServiceAccount automatically gets:
- `system:serviceaccounts` (all service accounts)
- `system:serviceaccounts:developers` ⭐ (this is the "group"!)
- `system:authenticated` (all authenticated)

**Key**: The `system:serviceaccounts:developers` group represents ALL users in the "developers" namespace.

### Use Cases
✅ Team-based testing (multiple users, one binding)
✅ Simulating organizational groups
✅ Scalable permission management
✅ Cross-namespace access for teams

❌ Users need different namespaces (namespace = group)
❌ Complex multi-group membership

## Detailed Comparison

### Scenario 1: Three Developers Need Same Access

#### Using create-user.sh
```bash
# Create three users
./scripts/create-user.sh alice edit myapp
./scripts/create-user.sh bob edit myapp
./scripts/create-user.sh charlie edit myapp

# Result: 3 ServiceAccounts + 3 RoleBindings
# - ServiceAccount: myapp/alice
# - RoleBinding: myapp/alice-edit
# - ServiceAccount: myapp/bob
# - RoleBinding: myapp/bob-edit
# - ServiceAccount: myapp/charlie
# - RoleBinding: myapp/charlie-edit
```

**Bindings**: 3 RoleBindings (one per user)

#### Using create-user-with-group.sh ⭐
```bash
# Create three users in same group
./scripts/create-user-with-group.sh alice developers none
./scripts/create-user-with-group.sh bob developers none
./scripts/create-user-with-group.sh charlie developers none

# Grant permissions to group ONCE
kubectl create rolebinding developers-edit \
  --clusterrole=edit \
  --group=system:serviceaccounts:developers \
  -n myapp

# Result: 3 ServiceAccounts + 1 RoleBinding
```

**Bindings**: 1 RoleBinding (for entire group)

### Scenario 2: Cross-Namespace Access

#### Using create-user.sh
```bash
# Alice needs access to dev, staging, and prod
./scripts/create-user.sh alice edit dev
kubectl create rolebinding alice-staging \
  --clusterrole=view \
  --serviceaccount=dev:alice \
  -n staging
kubectl create rolebinding alice-prod \
  --clusterrole=view \
  --serviceaccount=dev:alice \
  -n prod

# Repeat for bob and charlie
# Total: 9 bindings (3 users × 3 namespaces)
```

#### Using create-user-with-group.sh ⭐
```bash
# Create users in developers group
./scripts/create-user-with-group.sh alice developers none
./scripts/create-user-with-group.sh bob developers none
./scripts/create-user-with-group.sh charlie developers none

# Grant group access to multiple namespaces
kubectl create rolebinding developers-edit-dev \
  --clusterrole=edit \
  --group=system:serviceaccounts:developers \
  -n dev

kubectl create rolebinding developers-view-staging \
  --clusterrole=view \
  --group=system:serviceaccounts:developers \
  -n staging

kubectl create rolebinding developers-view-prod \
  --clusterrole=view \
  --group=system:serviceaccounts:developers \
  -n prod

# Total: 3 bindings (one per namespace for whole group)
```

### Scenario 3: Adding Fourth User

#### Using create-user.sh
```bash
# Create dave with same access as others
./scripts/create-user.sh dave edit myapp

# If dave needs cross-namespace access like others:
kubectl create rolebinding dave-staging --clusterrole=view --serviceaccount=myapp:dave -n staging
kubectl create rolebinding dave-prod --clusterrole=view --serviceaccount=myapp:dave -n prod

# Total new bindings: 3
```

#### Using create-user-with-group.sh ⭐
```bash
# Create dave in developers group
./scripts/create-user-with-group.sh dave developers none

# Done! Dave automatically gets all group permissions
# Total new bindings: 0 (uses existing group bindings)
```

## Practical Example: Setting Up Teams

### Setup Backend and Frontend Teams

```bash
# ============================================
# Backend Team Setup
# ============================================

# Create backend team members
./scripts/create-user-with-group.sh alice-backend team-backend none
./scripts/create-user-with-group.sh bob-backend team-backend none

# Grant team permissions
# Full access to their namespace
kubectl create rolebinding team-backend-edit \
  --clusterrole=edit \
  --group=system:serviceaccounts:team-backend \
  -n team-backend

# View access to staging
kubectl create rolebinding team-backend-view-staging \
  --clusterrole=view \
  --group=system:serviceaccounts:team-backend \
  -n staging

# View access to shared services
kubectl create rolebinding team-backend-view-services \
  --clusterrole=view \
  --group=system:serviceaccounts:team-backend \
  -n shared-services

# ============================================
# Frontend Team Setup
# ============================================

# Create frontend team members
./scripts/create-user-with-group.sh alice-frontend team-frontend none
./scripts/create-user-with-group.sh charlie-frontend team-frontend none

# Grant team permissions
kubectl create rolebinding team-frontend-edit \
  --clusterrole=edit \
  --group=system:serviceaccounts:team-frontend \
  -n team-frontend

kubectl create rolebinding team-frontend-view-staging \
  --clusterrole=view \
  --group=system:serviceaccounts:team-frontend \
  -n staging

kubectl create rolebinding team-frontend-view-services \
  --clusterrole=view \
  --group=system:serviceaccounts:team-frontend \
  -n shared-services

# ============================================
# Platform Team Setup (Admins)
# ============================================

# Create platform team members
./scripts/create-user-with-group.sh admin1 team-platform cluster-admin
./scripts/create-user-with-group.sh admin2 team-platform cluster-admin

# Cluster-admin already granted per-user in script
# Or grant to entire group:
kubectl create clusterrolebinding team-platform-admin \
  --clusterrole=cluster-admin \
  --group=system:serviceaccounts:team-platform
```

### Test Team Permissions

```bash
# Test backend team member
export KUBECONFIG=~/.kube/test-users/alice-backend-team-backend-kubeconfig.yaml
kubectl auth whoami
# Shows: system:serviceaccount:team-backend:alice-backend
# Groups: system:serviceaccounts:team-backend

kubectl get pods -n team-backend       # ✓ Can edit
kubectl get pods -n staging            # ✓ Can view
kubectl get pods -n team-frontend      # ✗ Forbidden
kubectl delete pod xxx -n staging      # ✗ Forbidden (only view)

unset KUBECONFIG
```

## Migration Guide

### From create-user.sh to create-user-with-group.sh

If you have existing users and want to move to group-based:

```bash
# Old setup (per-user bindings)
./scripts/create-user.sh alice edit myapp
./scripts/create-user.sh bob edit myapp

# New setup (group-based)
# 1. Create new users in group namespace
./scripts/create-user-with-group.sh alice developers none
./scripts/create-user-with-group.sh bob developers none

# 2. Create group binding
kubectl create rolebinding developers-edit \
  --clusterrole=edit \
  --group=system:serviceaccounts:developers \
  -n myapp

# 3. Update kubeconfig paths (they changed)
# Old: ~/.kube/test-users/alice-kubeconfig.yaml
# New: ~/.kube/test-users/alice-developers-kubeconfig.yaml

# 4. Delete old resources (optional)
kubectl delete serviceaccount alice -n myapp
kubectl delete rolebinding alice-edit -n myapp
```

## When to Use Which

### Use create-user.sh When:
- ✅ Testing individual user permissions
- ✅ Each user needs different permissions
- ✅ Users belong to different namespaces
- ✅ CI/CD pipelines (one SA per pipeline)
- ✅ Quick one-off testing

### Use create-user-with-group.sh When:
- ✅ Simulating team-based access
- ✅ Multiple users need identical permissions
- ✅ Testing group-based RBAC policies
- ✅ Cross-namespace access for teams
- ✅ Scalable user management (many users)

## Limitations

### create-user.sh Limitations
- ❌ No group concept (except automatic namespace group)
- ❌ One binding per user (doesn't scale)
- ❌ Hard to manage team permissions

### create-user-with-group.sh Limitations
- ❌ Namespace = Group (one primary group per user)
- ❌ Cannot have user in multiple groups easily (would need multiple SAs)
- ❌ Not true OIDC groups (these are ServiceAccount groups)

### Neither Support
- ❌ OIDC-style custom groups
- ❌ Dynamic group membership (without recreating SA)
- ❌ Group hierarchy (nested groups)
- ❌ Group-to-group mappings

## Summary

| Aspect | create-user.sh | create-user-with-group.sh |
|--------|---------------|---------------------------|
| **Command** | `./scripts/create-user.sh alice edit myapp` | `./scripts/create-user-with-group.sh alice developers none` |
| **ServiceAccount location** | `myapp/alice` | `developers/alice` |
| **Primary group** | `system:serviceaccounts:myapp` | `system:serviceaccounts:developers` |
| **Binding strategy** | Per-user | Per-group |
| **Scalability** | Low (O(n) bindings) | High (O(1) bindings per namespace) |
| **Team simulation** | Hard | Easy |
| **Multi-group support** | No | Limited (one namespace = one group) |
| **Recommended for** | Individual testing | Team-based testing |

---

**Recommendation**: Use `create-user-with-group.sh` for team-based testing and scenarios where multiple users need the same permissions. Use `create-user.sh` for quick individual user testing.

For production, use OIDC users with proper group management via Auth0/Keycloak/etc.

---

**Generated**: 2025-10-31
