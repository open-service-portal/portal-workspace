# Authentication Methods Summary - Quick Reference

## The Problem You Had

**ServiceAccounts cannot be added to custom groups.** They only get automatic namespace-based groups like `system:serviceaccounts:namespace`.

## The Solution

**Switch to Client Certificate authentication** for test users with custom groups.

---

## Available Scripts

### 1. ServiceAccount Authentication (Original)

```bash
./scripts/create-user.sh <username> [permission] [namespace]
```

**Groups**: ❌ No custom groups (only automatic namespace groups)

**Use for**: CI/CD, simple testing

---

### 2. ServiceAccount with Namespace Groups

```bash
./scripts/create-user-with-group.sh <username> <group-namespace> [permission]
```

**Groups**: ⚠️ Limited (namespace = group)

**Use for**: Team-based testing with namespace isolation

---

### 3. Client Certificate Authentication ⭐ **RECOMMENDED**

```bash
./scripts/create-user-with-cert.sh <username> <group1> [group2] [group3]
```

**Groups**: ✅ Full custom groups (multiple groups per user)

**Use for**: Local testing with flexible group management

---

## Quick Comparison

| Script | Groups | Flexibility | Best For |
|--------|--------|-------------|----------|
| `create-user.sh` | ❌ None | Low | Quick testing |
| `create-user-with-group.sh` | ⚠️ One (namespace) | Medium | Team namespaces |
| `create-user-with-cert.sh` | ✅ Multiple custom | High | **Local dev** |
| OIDC (Auth0/Keycloak) | ✅ Full | Very High | **Production** |

---

## Examples

### Create User with Multiple Groups

```bash
# Alice is in developers AND backend-team groups
./scripts/create-user-with-cert.sh alice developers backend-team

# Test
export KUBECONFIG=~/.kube/test-users/alice-cert-kubeconfig.yaml
kubectl auth whoami
# Shows: username: alice
#        groups: [developers, backend-team, system:authenticated]
```

### Grant Permissions to Group

```bash
# Create group binding
kubectl create clusterrolebinding developers-edit \
  --clusterrole=edit \
  --group=developers

# Now ALL users in "developers" group get edit permissions
# Including:
# - alice (from certificate above)
# - bob (if created with: create-user-with-cert.sh bob developers)
# - Any other user with "developers" in their certificate
```

### Create Multiple Users in Same Group

```bash
# Backend team
./scripts/create-user-with-cert.sh alice developers backend-team
./scripts/create-user-with-cert.sh bob developers backend-team

# Grant permissions ONCE for the group
kubectl create rolebinding backend-team-edit \
  --clusterrole=edit \
  --group=backend-team \
  -n backend-services

# Both alice and bob now have edit access in backend-services namespace!
```

---

## How Client Certificates Work

```
Certificate Subject:
  CN=alice              ← Username
  O=developers          ← Group 1
  O=backend-team        ← Group 2

When alice authenticates:
  Kubernetes reads certificate
  Username: alice
  Groups: [developers, backend-team]

Kubernetes checks RBAC:
  Is alice or any of her groups in a binding?
  → Group "developers" has ClusterRoleBinding → edit role
  → Grant edit permissions ✓
```

---

## Migration Path

### From ServiceAccount to Certificate

**Old** (ServiceAccount):
```bash
./scripts/create-user.sh alice edit myapp
# Limited to namespace-based groups
```

**New** (Certificate) ⭐:
```bash
./scripts/create-user-with-cert.sh alice developers backend-team
# Custom groups!

kubectl create rolebinding developers-edit \
  --clusterrole=edit \
  --group=developers \
  -n myapp
```

---

## When to Use What

### Local Development Testing
✅ **Use**: `create-user-with-cert.sh`
- Full custom group support
- No external dependencies
- Easy to manage 5-10 test users

### Team/Integration Testing
✅ **Use**: Local OIDC (Dex) - see `docs/alternative-auth-methods.md`
- Realistic auth flow
- Easy to add users
- Web-based login

### Production
✅ **Use**: Cloud OIDC (Auth0, Keycloak, Google, Azure AD)
- Proper user management
- MFA, SSO
- Audit logs
- Integration with corporate directory

---

## Complete Example: Setting Up Development Team

```bash
# 1. Create users with custom groups
./scripts/create-user-with-cert.sh alice developers backend-team
./scripts/create-user-with-cert.sh bob developers backend-team
./scripts/create-user-with-cert.sh charlie developers frontend-team

# 2. Grant group permissions
# Backend team gets edit in backend namespace
kubectl create rolebinding backend-team-edit \
  --clusterrole=edit \
  --group=backend-team \
  -n backend-services

# Frontend team gets edit in frontend namespace
kubectl create rolebinding frontend-team-edit \
  --clusterrole=edit \
  --group=frontend-team \
  -n frontend-services

# All developers can view staging
kubectl create rolebinding developers-view-staging \
  --clusterrole=view \
  --group=developers \
  -n staging

# 3. Test access
export KUBECONFIG=~/.kube/test-users/alice-cert-kubeconfig.yaml
kubectl get pods -n backend-services  # ✓ Can edit (backend-team)
kubectl get pods -n staging           # ✓ Can view (developers)
kubectl get pods -n frontend-services # ✗ Forbidden (not in frontend-team)

# 4. Add more users easily
./scripts/create-user-with-cert.sh dave developers backend-team
# Dave automatically gets same access as alice and bob!
```

---

## Key Advantages of Certificate Auth

| Feature | ServiceAccount | Client Certificate |
|---------|---------------|-------------------|
| Custom groups | ❌ | ✅ |
| Multiple groups per user | ❌ | ✅ |
| Group-based RBAC | Limited | Full |
| External dependencies | None | None |
| Setup complexity | Low | Low |
| Change groups | N/A | Recreate cert |

---

## Quick Commands

```bash
# Create user with groups
./scripts/create-user-with-cert.sh <username> <group1> [group2] ...

# Grant permissions to group
kubectl create clusterrolebinding <group>-edit \
  --clusterrole=edit \
  --group=<group>

# Test user identity
export KUBECONFIG=~/.kube/test-users/<username>-cert-kubeconfig.yaml
kubectl auth whoami

# List custom RBAC (OIDC + Cert users)
./scripts/rbac-list-custom.sh

# Clean up
kubectl delete csr <username>-csr
rm ~/.kube/test-users/certs/<username>.*
rm ~/.kube/test-users/<username>-cert-kubeconfig.yaml
```

---

## Documentation

- **`docs/alternative-auth-methods.md`** - Complete comparison of all auth methods
- **`docs/kubernetes-users-groups-explained.md`** - How groups work in Kubernetes
- **`docs/serviceaccount-groups-workaround.md`** - ServiceAccount limitations
- **`docs/user-creation-comparison.md`** - Script comparison guide

---

## Summary

**Problem**: ServiceAccounts can't be in custom groups

**Solution**: Use client certificates for test users

**Command**: `./scripts/create-user-with-cert.sh alice developers backend-team`

**Result**: User with multiple custom groups, just like OIDC users!

---

**Generated**: 2025-10-31
**Recommended**: `create-user-with-cert.sh` for local testing with custom groups
