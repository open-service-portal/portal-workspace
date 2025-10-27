# RBAC Testing Guide

This guide explains how to test RBAC configurations using a test user with zero access.

## Overview

Testing RBAC requires a user that:
- Has NO permissions by default (not affected by `cloudspace-admin-role`)
- Uses ServiceAccount token authentication (NOT OIDC)
- Can be easily granted and revoked permissions

## Create Test User

```bash
# Create a test user with zero access
./scripts/create-user.sh testuser
```

This creates:
- ServiceAccount-based user (bypasses OIDC)
- Username: `system:serviceaccount:default:testuser`
- Permissions: **NONE** by default
- Kubeconfig: `~/.kube/test-users/testuser-kubeconfig.yaml`

## Test Zero Access (Before Migration)

```bash
# Use the test user's kubeconfig
export KUBECONFIG=~/.kube/test-users/testuser-kubeconfig.yaml

# Verify user identity
kubectl auth whoami
# Output: Username: testuser

# Try to list resources (should succeed if org-wide admin exists)
kubectl get pods --all-namespaces
# If cloudspace-admin-role exists: Lists pods (BAD - proves everyone has admin)
# If cloudspace-admin-role removed: Error: Forbidden (GOOD - proper isolation)
```

## Test Namespace-Scoped Access

### Grant namespace access
```bash
# Switch back to admin
unset KUBECONFIG

# Grant edit access to test-namespace (use kubectl for ServiceAccounts)
kubectl create rolebinding testuser-edit \
  --clusterrole=edit \
  --serviceaccount=default:testuser \
  -n test-namespace
```

### Test as the user
```bash
# Use test user kubeconfig
export KUBECONFIG=~/.kube/test-users/testuser-kubeconfig.yaml

# Should succeed - has access to test-namespace
kubectl get pods -n test-namespace
kubectl create deployment nginx --image=nginx -n test-namespace

# Should fail - no access to other namespaces
kubectl get pods -n default
kubectl get pods -n kube-system

# Should fail - no cluster-wide permissions
kubectl get nodes
kubectl get namespaces
```

## Test Cluster Admin Access

### Grant cluster-admin
```bash
# Switch to admin
unset KUBECONFIG

# Grant cluster-admin to test user
kubectl create clusterrolebinding testuser-admin \
  --clusterrole=cluster-admin \
  --user=testuser
```

### Test as admin user
```bash
# Use test user kubeconfig
export KUBECONFIG=~/.kube/test-users/testuser-kubeconfig.yaml

# Should all succeed - has cluster-admin
kubectl get nodes
kubectl get pods --all-namespaces
kubectl get secrets --all-namespaces
```

## Testing RBAC Migration

### Pre-Migration Test
```bash
# 1. Create test user
./scripts/create-user.sh testuser

# 2. Test with org-wide admin binding (should have full access)
export KUBECONFIG=~/.kube/test-users/testuser-kubeconfig.yaml
kubectl get pods --all-namespaces  # Should succeed (proves org-wide admin works)
```

### Run Migration
```bash
# Switch back to admin
unset KUBECONFIG

# Run migration (add your admin emails)
./scripts/rbac-migration.sh admin1@company.com admin2@company.com
```

### Post-Migration Test
```bash
# Test user should now have ZERO access
export KUBECONFIG=~/.kube/test-users/testuser-kubeconfig.yaml

kubectl get pods --all-namespaces
# Output: Error from server (Forbidden) - GOOD!

kubectl auth can-i get pods
# Output: no - GOOD!

kubectl auth can-i get pods --all-namespaces
# Output: no - GOOD!
```

### Grant Specific Access
```bash
# Switch to admin
unset KUBECONFIG

# Grant namespace access only
kubectl create rolebinding testuser-edit \
  --clusterrole=edit \
  --serviceaccount=default:testuser \
  -n myapp

# Test again
export KUBECONFIG=~/.kube/test-users/testuser-kubeconfig.yaml
kubectl get pods -n myapp  # Should succeed
kubectl get pods -n default  # Should fail
```

## Cleanup

### Remove test user access
```bash
# Remove namespace access
kubectl delete rolebinding testuser-edit-binding -n test-namespace

# Remove cluster-admin access (if granted)
kubectl delete clusterrolebinding testuser-admin
```

### Remove test user completely
```bash
# Remove certificates and kubeconfig
rm -rf ~/.kube/test-users/testuser*
```

## Comparison: ServiceAccount vs OIDC Users

| Aspect | ServiceAccount User (testuser) | OIDC User (you@company.com) |
|--------|-------------------------------|----------------------------|
| **Authentication** | ServiceAccount token | OIDC token from Auth0 |
| **Username format** | `system:serviceaccount:default:testuser` | `oidc:you@company.com` |
| **Groups** | `system:serviceaccounts:default` | `oidc:org_zOuCBHiyF1yG8d1D` |
| **Affected by org-wide admin** | ❌ No (not in OIDC group) | ✅ Yes (in OIDC org group) |
| **Default permissions** | None | Depends on org RBAC |
| **Best for** | Testing RBAC isolation | Production users |

## Why ServiceAccount Users for Testing?

ServiceAccount-based users are perfect for RBAC testing because:

1. **Not in OIDC group** - Won't get `cloudspace-admin-role` permissions
2. **Clean slate** - Zero permissions by default
3. **No external dependencies** - Don't need Auth0 access
4. **Easy cleanup** - Just delete the ServiceAccount
5. **Reproducible** - Can create multiple test users instantly
6. **Token-based** - Simple bearer token authentication

## Example Test Scenarios

### Scenario 1: Verify Zero Access Default
```bash
# Create user
./scripts/create-user.sh zero-user

# Test (should fail everything)
export KUBECONFIG=~/.kube/test-users/zero-user-kubeconfig.yaml
kubectl auth can-i --list
# Should only show: selfsubjectaccessreviews, selfsubjectrulesreviews
```

### Scenario 2: Test View Role
```bash
# Grant view access
kubectl create rolebinding zero-user-view \
  --clusterrole=view \
  --serviceaccount=default:zero-user \
  -n dev

# Test (can read, cannot write)
export KUBECONFIG=~/.kube/test-users/zero-user-kubeconfig.yaml
kubectl get pods -n dev  # ✓ Success
kubectl delete pod xxx -n dev  # ✗ Forbidden
kubectl get secrets -n dev  # ✗ Forbidden (view can't see secrets)
```

### Scenario 3: Test Edit Role
```bash
# Grant edit access
kubectl create rolebinding zero-user-edit \
  --clusterrole=edit \
  --serviceaccount=default:zero-user \
  -n dev

# Test (can read/write, cannot manage RBAC)
export KUBECONFIG=~/.kube/test-users/zero-user-kubeconfig.yaml
kubectl create deployment test --image=nginx -n dev  # ✓ Success
kubectl delete deployment test -n dev  # ✓ Success
kubectl get secrets -n dev  # ✓ Success (edit can see secrets)
kubectl create rolebinding test ... -n dev  # ✗ Forbidden (cannot manage RBAC)
```

### Scenario 4: Test Admin Role
```bash
# Grant admin access
kubectl create rolebinding zero-user-admin \
  --clusterrole=admin \
  --serviceaccount=default:zero-user \
  -n dev

# Test (full namespace control)
export KUBECONFIG=~/.kube/test-users/zero-user-kubeconfig.yaml
kubectl create rolebinding test ... -n dev  # ✓ Success
kubectl create resourcequota test ... -n dev  # ✓ Success
kubectl delete namespace dev  # ✗ Forbidden (cannot delete namespace itself)
```

## Tips

**Always switch contexts explicitly:**
```bash
# Use test user
export KUBECONFIG=~/.kube/test-users/testuser-kubeconfig.yaml

# Switch back to admin
unset KUBECONFIG
# or
export KUBECONFIG=~/.kube/config
```

**Verify current user:**
```bash
kubectl auth whoami
```

**Check permissions:**
```bash
# List all permissions
kubectl auth can-i --list

# Check specific permission
kubectl auth can-i get pods -n namespace
kubectl auth can-i create deployments -n namespace
kubectl auth can-i '*' '*' --all-namespaces  # Check cluster-admin
```

**See effective RBAC for user:**
```bash
# As admin, check what a user can do
kubectl auth can-i get pods --as=testuser -n namespace
```
