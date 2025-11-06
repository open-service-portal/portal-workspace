# ServiceAccount "Groups" - Workarounds and Solutions

## The Problem

When you create users via `create-user.sh`, they are **ServiceAccounts**, not OIDC users.

ServiceAccounts automatically belong to these groups:
- `system:serviceaccounts` (all service accounts cluster-wide)
- `system:serviceaccounts:<namespace>` (all service accounts in that namespace)
- `system:authenticated` (all authenticated identities)

**You CANNOT add ServiceAccounts to custom groups** because:
1. Groups are not Kubernetes resources
2. ServiceAccount group membership is hardcoded by Kubernetes
3. Custom groups only work with OIDC/certificate-based authentication

## Built-in ServiceAccount Groups

```bash
# Create a test user
./scripts/create-user.sh testuser none myapp

# Check what groups this user has
kubectl --as=system:serviceaccount:myapp:testuser auth whoami
```

Output shows:
```yaml
username: system:serviceaccount:myapp:testuser
groups:
- system:serviceaccounts           # All SAs
- system:serviceaccounts:myapp     # All SAs in 'myapp' namespace
- system:authenticated             # All authenticated users
```

These groups are **automatic and cannot be changed**.

## Workarounds for Group-Like Behavior

### Solution 1: Use Built-in ServiceAccount Groups (Recommended)

Grant permissions to **all ServiceAccounts in a namespace**:

```bash
# Grant edit permissions to ALL service accounts in 'developers' namespace
kubectl create rolebinding developers-group-access \
  --clusterrole=edit \
  --group=system:serviceaccounts:developers \
  -n developers
```

**Use Case**: Create a namespace per team, and all ServiceAccounts in that namespace automatically get team permissions.

```bash
# Create namespace for backend team
kubectl create namespace team-backend

# Grant all SAs in team-backend namespace edit access to their namespace
kubectl create rolebinding team-backend-edit \
  --clusterrole=edit \
  --group=system:serviceaccounts:team-backend \
  -n team-backend

# Create test users for backend team members
./scripts/create-user.sh alice none team-backend
./scripts/create-user.sh bob none team-backend

# Both alice and bob automatically get edit access via the group binding!
```

### Solution 2: Use Labels as "Virtual Groups"

Add labels to ServiceAccounts and bind to them:

```bash
# Create ServiceAccount with "group" label
kubectl create serviceaccount alice -n default
kubectl label serviceaccount alice -n default team=backend

# Create another SA with same label
kubectl create serviceaccount bob -n default
kubectl label serviceaccount bob -n default team=backend

# Create RoleBinding using label selector...
# Wait, this doesn't work! RoleBindings don't support label selectors!
```

**Problem**: RoleBindings require explicit subjects - no label selectors.

**Alternative**: Use a controller or script to maintain bindings:

```bash
# Script to sync labeled ServiceAccounts to bindings
#!/bin/bash
TEAM="backend"
NAMESPACE="default"

# Get all ServiceAccounts with team=backend label
SAs=$(kubectl get sa -n $NAMESPACE -l team=$TEAM -o jsonpath='{.items[*].metadata.name}')

for SA in $SAs; do
  # Create individual RoleBinding for each SA
  kubectl create rolebinding "${SA}-${TEAM}-access" \
    --clusterrole=edit \
    --serviceaccount="${NAMESPACE}:${SA}" \
    -n $NAMESPACE \
    --dry-run=client -o yaml | kubectl apply -f -
done
```

### Solution 3: Modify create-user.sh to Support "Group-like" Behavior

Add a `--group` option that creates bindings based on a group convention:

```bash
# Modified create-user.sh usage
./scripts/create-user.sh alice edit myapp --group=backend-team
```

This would:
1. Create the ServiceAccount
2. Add label `group=backend-team`
3. Create RoleBinding with a group-based name
4. Store group info in annotation

Let me create this enhanced version:

```bash
#!/usr/bin/env bash
#
# Enhanced create-user.sh with "group" support
#
# Usage:
#   ./scripts/create-user-with-group.sh <username> [permission] [namespace] [group]
#
# Examples:
#   ./scripts/create-user-with-group.sh alice edit myapp backend-team
#   ./scripts/create-user-with-group.sh bob view myapp backend-team
#
# ServiceAccounts in same "group" share common bindings

set -euo pipefail

USERNAME="${1:-}"
PERMISSION="${2:-none}"
NAMESPACE="${3:-default}"
GROUP="${4:-}"

# If group is specified, create a shared group binding
if [[ -n "$GROUP" ]]; then
  # Create shared RoleBinding for this "group"
  kubectl create rolebinding "group-${GROUP}" \
    --clusterrole="${PERMISSION}" \
    --group="custom:group:${GROUP}" \
    -n "${NAMESPACE}" \
    2>/dev/null || true

  # Add ServiceAccount to this virtual group by:
  # 1. Label the SA
  kubectl label serviceaccount "${USERNAME}" \
    group="${GROUP}" \
    -n "${NAMESPACE}"

  # 2. Create individual binding that references the SA
  #    (since we can't actually add SA to a Group resource)
  kubectl create rolebinding "${USERNAME}-${GROUP}-member" \
    --clusterrole="${PERMISSION}" \
    --serviceaccount="${NAMESPACE}:${USERNAME}" \
    -n "${NAMESPACE}" \
    2>/dev/null || true
fi
```

**Problem**: This still creates individual bindings per SA - not a true group!

### Solution 4: Use a Custom Namespace Convention (Best for ServiceAccounts)

Structure:
```
namespaces:
  team-backend/          # All SAs here are "backend team members"
  team-frontend/         # All SAs here are "frontend team members"
  team-platform/         # All SAs here are "platform team members"

# Grant permissions based on namespace group
kubectl create rolebinding team-backend-access \
  --clusterrole=edit \
  --group=system:serviceaccounts:team-backend \
  -n team-backend

# Grant cross-namespace access
kubectl create rolebinding backend-can-access-staging \
  --clusterrole=view \
  --group=system:serviceaccounts:team-backend \
  -n staging
```

**Advantages**:
- Uses real Kubernetes groups (ServiceAccount namespace groups)
- No custom tooling needed
- Clear organizational structure
- Easy to audit

**Disadvantages**:
- Requires namespace per group
- Cannot have users in multiple groups easily

### Solution 5: Use Multiple ServiceAccounts per User

Create multiple ServiceAccounts for different roles:

```bash
# Alice is in both backend and frontend teams
./scripts/create-user.sh alice-backend edit team-backend
./scripts/create-user.sh alice-frontend edit team-frontend

# Bob is only in backend team
./scripts/create-user.sh bob-backend edit team-backend
```

**Advantages**:
- Multiple "group" memberships via multiple SAs
- Uses built-in Kubernetes features

**Disadvantages**:
- Multiple kubeconfigs per person
- Confusing identity management

## Recommended Approach

**For ServiceAccount-based test users**: Use **Solution 4 (Namespace Convention)**

```bash
# 1. Create namespace per team/group
kubectl create namespace developers
kubectl create namespace qa-team
kubectl create namespace platform-team

# 2. Grant permissions to the ServiceAccount group
kubectl create rolebinding developers-edit \
  --clusterrole=edit \
  --group=system:serviceaccounts:developers \
  -n developers

# Allow developers to view staging
kubectl create rolebinding developers-view-staging \
  --clusterrole=view \
  --group=system:serviceaccounts:developers \
  -n staging

# 3. Create test users in appropriate namespace
./scripts/create-user.sh alice none developers
./scripts/create-user.sh bob none developers

# Alice and Bob automatically get:
# - edit access in developers namespace
# - view access in staging namespace
# All via the system:serviceaccounts:developers group!
```

## Enhanced create-user.sh Script

Let me create an enhanced version that embraces the namespace-as-group pattern:

```bash
#!/usr/bin/env bash
#
# create-user-with-group.sh
# Creates ServiceAccount in a "group namespace" for automatic group membership
#
# Usage:
#   ./scripts/create-user-with-group.sh <username> <group-namespace>
#
# Examples:
#   ./scripts/create-user-with-group.sh alice developers
#   ./scripts/create-user-with-group.sh bob platform-team

set -euo pipefail

USERNAME="${1:-}"
GROUP_NAMESPACE="${2:-}"

if [[ -z "$USERNAME" ]] || [[ -z "$GROUP_NAMESPACE" ]]; then
  echo "Usage: $0 <username> <group-namespace>"
  exit 1
fi

# Ensure namespace exists
kubectl create namespace "${GROUP_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# Create ServiceAccount in the group namespace
kubectl create serviceaccount "${USERNAME}" -n "${GROUP_NAMESPACE}"

# Create token secret
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${USERNAME}-token
  namespace: ${GROUP_NAMESPACE}
  annotations:
    kubernetes.io/service-account.name: ${USERNAME}
type: kubernetes.io/service-account-token
EOF

echo "✓ User ${USERNAME} created in group namespace: ${GROUP_NAMESPACE}"
echo ""
echo "This user automatically belongs to group:"
echo "  system:serviceaccounts:${GROUP_NAMESPACE}"
echo ""
echo "To grant permissions to ALL users in this group:"
echo "  kubectl create rolebinding ${GROUP_NAMESPACE}-access \\"
echo "    --clusterrole=edit \\"
echo "    --group=system:serviceaccounts:${GROUP_NAMESPACE} \\"
echo "    -n ${GROUP_NAMESPACE}"
```

## Comparison: ServiceAccounts vs OIDC Users

| Feature | ServiceAccount (create-user.sh) | OIDC User |
|---------|--------------------------------|-----------|
| **Group support** | Built-in namespace groups only | Full custom group support |
| **Group membership** | Automatic (by namespace) | Managed in OIDC provider |
| **Multiple groups** | One namespace = one primary group | Many groups per user |
| **User-to-group mapping** | Implicit (namespace location) | Explicit (OIDC provider) |
| **Best for** | Testing, automation, CI/CD | Human users, production |
| **Flexibility** | Limited | Very flexible |

## When to Use Which

### Use ServiceAccounts (create-user.sh) When:
- ✅ Testing RBAC policies
- ✅ CI/CD pipelines
- ✅ Automated tools/scripts
- ✅ Internal service authentication
- ✅ Short-lived test users

### Use OIDC Users When:
- ✅ Human users
- ✅ Production access
- ✅ Complex group hierarchies
- ✅ Integration with corporate directory
- ✅ Audit requirements

## Practical Example: Setting Up Team-Based Access

```bash
#!/bin/bash
# Setup team-based access using namespace groups

# 1. Create team namespaces
kubectl create namespace team-backend
kubectl create namespace team-frontend
kubectl create namespace team-platform

# 2. Setup shared namespaces
kubectl create namespace staging
kubectl create namespace production

# 3. Grant team-backend permissions
# - Full access to their own namespace
kubectl create rolebinding team-backend-edit \
  --clusterrole=edit \
  --group=system:serviceaccounts:team-backend \
  -n team-backend

# - View access to staging
kubectl create rolebinding team-backend-view-staging \
  --clusterrole=view \
  --group=system:serviceaccounts:team-backend \
  -n staging

# 4. Grant team-frontend permissions
kubectl create rolebinding team-frontend-edit \
  --clusterrole=edit \
  --group=system:serviceaccounts:team-frontend \
  -n team-frontend

kubectl create rolebinding team-frontend-view-staging \
  --clusterrole=view \
  --group=system:serviceaccounts:team-frontend \
  -n staging

# 5. Grant platform team cluster-admin
kubectl create clusterrolebinding team-platform-admin \
  --clusterrole=cluster-admin \
  --group=system:serviceaccounts:team-platform

# 6. Create test users
./scripts/create-user.sh alice none team-backend
./scripts/create-user.sh bob none team-frontend
./scripts/create-user.sh charlie none team-platform

# Result:
# - alice: edit in team-backend, view in staging
# - bob: edit in team-frontend, view in staging
# - charlie: cluster-admin everywhere
```

## Checking ServiceAccount Group Membership

```bash
# Method 1: Check authentication info
kubectl --as=system:serviceaccount:team-backend:alice auth whoami

# Output:
# username: system:serviceaccount:team-backend:alice
# groups:
# - system:serviceaccounts
# - system:serviceaccounts:team-backend
# - system:authenticated

# Method 2: Test permissions
kubectl --as=system:serviceaccount:team-backend:alice \
  auth can-i create pods -n team-backend
# yes (via system:serviceaccounts:team-backend group binding)

kubectl --as=system:serviceaccount:team-backend:alice \
  auth can-i create pods -n team-frontend
# no (alice's group doesn't have access)
```

## Summary

**You cannot add ServiceAccounts to custom groups**, but you can:

1. ✅ **Use namespace-based groups** (recommended)
   - Create namespace per team
   - Grant permissions to `system:serviceaccounts:<namespace>`
   - All SAs in that namespace inherit permissions

2. ✅ **Use individual bindings per SA**
   - Works but doesn't scale
   - No true "group" concept

3. ❌ **Cannot use OIDC-style groups**
   - Those only work with OIDC authentication
   - ServiceAccounts use token authentication

**Best Practice**:
- For test users: Use namespace-based groups
- For real users: Use OIDC with proper group management

---

**Generated**: 2025-10-31
