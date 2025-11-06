# RBAC Scripts Usage Examples

Comprehensive examples for using the RBAC management and testing scripts.

## Table of Contents

- [Quick Start](#quick-start)
- [Migration Workflow](#migration-workflow)
- [Managing Admins](#managing-admins)
- [Managing Namespace Access](#managing-namespace-access)
- [Testing RBAC](#testing-rbac)
- [Real-World Scenarios](#real-world-scenarios)

---

## Quick Start

### Create your first test user

```bash
# Create a test user with zero access
./scripts/create-user.sh testuser

# Use the test user
export KUBECONFIG=~/.kube/test-users/testuser-kubeconfig.yaml

# Verify zero access
kubectl get pods
# Error from server (Forbidden) ✓

# Switch back to admin
unset KUBECONFIG
```

---

## Migration Workflow

### Complete RBAC migration from scratch

```bash
# 1. Before migration - test current state
./scripts/create-user.sh before-test
export KUBECONFIG=~/.kube/test-users/before-test-kubeconfig.yaml
kubectl get pods --all-namespaces
# Should succeed if org-wide admin exists

unset KUBECONFIG

# 2. Run migration (replace with your admin emails)
./scripts/rbac-migration.sh \
  admin1@company.com \
  admin2@company.com \
  admin3@company.com

# Output:
# ✓ ClusterRoleBinding 'admin-admin1' created for admin1@company.com
# ✓ ClusterRoleBinding 'admin-admin2' created for admin2@company.com
# ✓ ClusterRoleBinding 'admin-admin3' created for admin3@company.com
# clusterrolebinding.rbac.authorization.k8s.io "cloudspace-admin-role" deleted
# ✓ Migration complete

# 3. After migration - verify isolation
./scripts/create-user.sh after-test
export KUBECONFIG=~/.kube/test-users/after-test-kubeconfig.yaml
kubectl get pods --all-namespaces
# Error from server (Forbidden) ✓

unset KUBECONFIG
```

---

## Managing Admins

### Add a new cluster admin

```bash
# Grant full cluster access to a new admin
./scripts/rbac-add-admin.sh newadmin@company.com

# Output:
# ✓ ClusterRoleBinding 'admin-newadmin' created for newadmin@company.com
#
# ℹ To remove access:
#   kubectl delete clusterrolebinding admin-newadmin
```

### Add multiple admins

```bash
# Add several admins at once
for admin in alice@company.com bob@company.com charlie@company.com; do
  ./scripts/rbac-add-admin.sh "$admin"
done
```

### Remove admin access

```bash
# Remove cluster-admin from a user
kubectl delete clusterrolebinding admin-alice
```

### List all admins

```bash
# Show all explicit admin bindings
kubectl get clusterrolebindings -l rbac.openportal.dev/type=explicit-admin

# Show details
kubectl get clusterrolebindings -l rbac.openportal.dev/type=explicit-admin -o yaml
```

---

## Managing Namespace Access

### Grant namespace access to developers

```bash
# Developer gets edit access to dev namespace
./scripts/rbac-add-namespace-access.sh developer@company.com dev

# Output:
# ✓ Namespace 'dev' ready
# ✓ RoleBinding 'developer-edit-binding' created for developer@company.com with role 'edit'
#
# ℹ To remove access:
#   kubectl delete rolebinding developer-edit-binding -n dev
```

### Different permission levels

```bash
# Read-only access (view)
./scripts/rbac-add-namespace-access.sh viewer@company.com prod view

# Read/write access (edit) - default
./scripts/rbac-add-namespace-access.sh dev@company.com staging edit

# Full namespace control (admin)
./scripts/rbac-add-namespace-access.sh lead@company.com prod admin
```

### Grant access to multiple namespaces

```bash
# Give developer access to multiple namespaces
for ns in dev staging qa; do
  ./scripts/rbac-add-namespace-access.sh developer@company.com "$ns"
done
```

### Team namespace setup

```bash
# Setup team namespace with multiple users
TEAM_NS="team-alpha"

# Team lead - full control
./scripts/rbac-add-namespace-access.sh lead@company.com "$TEAM_NS" admin

# Developers - read/write
./scripts/rbac-add-namespace-access.sh dev1@company.com "$TEAM_NS" edit
./scripts/rbac-add-namespace-access.sh dev2@company.com "$TEAM_NS" edit

# Auditor - read-only
./scripts/rbac-add-namespace-access.sh auditor@company.com "$TEAM_NS" view
```

---

## Testing RBAC

### Create test users with different permissions

```bash
# Zero access user (for testing isolation)
./scripts/create-user.sh test-zero none

# Read-only user
./scripts/create-user.sh test-viewer view myapp

# Read/write user
./scripts/create-user.sh test-editor edit myapp

# Full namespace admin
./scripts/create-user.sh test-admin admin myapp

# Cluster admin
./scripts/create-user.sh test-cluster-admin cluster-admin
```

### Test permission boundaries

```bash
# Test edit user permissions
export KUBECONFIG=~/.kube/test-users/test-editor-kubeconfig.yaml

# Should succeed - can create resources
kubectl create deployment nginx --image=nginx -n myapp
kubectl get pods -n myapp
kubectl delete deployment nginx -n myapp

# Should fail - cannot manage RBAC
kubectl create rolebinding test --clusterrole=view --user=someone -n myapp
# Error: cannot create resource "rolebindings"

# Should fail - no access to other namespaces
kubectl get pods -n default
# Error: Forbidden

unset KUBECONFIG
```

### Compare permissions

```bash
# Test view vs edit
export KUBECONFIG=~/.kube/test-users/test-viewer-kubeconfig.yaml

kubectl get pods -n myapp  # ✓ Can view
kubectl get secrets -n myapp  # ✗ Cannot see secrets (view role)
kubectl delete pod xxx -n myapp  # ✗ Cannot delete

unset KUBECONFIG
export KUBECONFIG=~/.kube/test-users/test-editor-kubeconfig.yaml

kubectl get pods -n myapp  # ✓ Can view
kubectl get secrets -n myapp  # ✓ Can see secrets (edit role)
kubectl delete pod xxx -n myapp  # ✓ Can delete

unset KUBECONFIG
```

---

## Real-World Scenarios

### Scenario 1: Onboard a New Developer

```bash
# 1. Create test account for the developer to test access
./scripts/create-user.sh new-dev-test edit team-projects

# 2. Send them instructions to test
echo "Test your access:"
echo "  export KUBECONFIG=~/.kube/test-users/new-dev-test-kubeconfig.yaml"
echo "  kubectl get pods -n team-projects"

# 3. Once confirmed working, grant them real OIDC access
./scripts/rbac-add-namespace-access.sh newdev@company.com team-projects edit

# 4. Cleanup test account
kubectl delete serviceaccount new-dev-test -n default
kubectl delete secret new-dev-test-token -n default
rm ~/.kube/test-users/new-dev-test-kubeconfig.yaml
```

### Scenario 2: Grant Temporary Admin Access

```bash
# Grant temporary cluster-admin for incident response
./scripts/rbac-add-admin.sh oncall@company.com

# After incident resolved, revoke access
kubectl delete clusterrolebinding admin-oncall
```

### Scenario 3: Setup Multi-Environment Access

```bash
# Developer has different access levels across environments
DEVELOPER="jane@company.com"

# Full access to dev
./scripts/rbac-add-namespace-access.sh "$DEVELOPER" dev admin

# Read/write to staging
./scripts/rbac-add-namespace-access.sh "$DEVELOPER" staging edit

# Read-only to production
./scripts/rbac-add-namespace-access.sh "$DEVELOPER" prod view
```

### Scenario 4: Team Rotation (Replace Team Lead)

```bash
# Remove old team lead's namespace admin
kubectl delete rolebinding oldlead-admin-binding -n team-namespace

# Add new team lead
./scripts/rbac-add-namespace-access.sh newlead@company.com team-namespace admin
```

### Scenario 5: Security Audit

```bash
# Create auditor with view-only access to all namespaces
AUDITOR="auditor@company.com"

# Grant view access to all application namespaces
for ns in $(kubectl get namespaces -o name | grep -v kube-system | grep -v kube-public); do
  NS_NAME=${ns#namespace/}
  ./scripts/rbac-add-namespace-access.sh "$AUDITOR" "$NS_NAME" view
done

# Verify
kubectl auth can-i get pods --all-namespaces --as="oidc:$AUDITOR"
kubectl auth can-i delete pods --all-namespaces --as="oidc:$AUDITOR"
```

### Scenario 6: Emergency Access Revocation

```bash
# Quickly revoke all access for a user
USER="compromised@company.com"
USERNAME="${USER%%@*}"
USERNAME_NORMALIZED="${USERNAME//./-}"

# Remove cluster-admin if exists
kubectl delete clusterrolebinding "admin-${USERNAME_NORMALIZED}" 2>/dev/null || true

# Remove all namespace bindings
kubectl get rolebindings --all-namespaces -o json | \
  jq -r ".items[] | select(.subjects[]?.name | contains(\"$USER\")) | \"\(.metadata.namespace)/\(.metadata.name)\"" | \
  while read binding; do
    NAMESPACE="${binding%%/*}"
    BINDING_NAME="${binding#*/}"
    kubectl delete rolebinding "$BINDING_NAME" -n "$NAMESPACE"
  done
```

### Scenario 7: Pre-Production Testing

```bash
# Before deploying RBAC changes to production, test with ServiceAccounts

# 1. Create test users matching production roles
./scripts/create-user.sh prod-viewer-test view production
./scripts/create-user.sh prod-editor-test edit production
./scripts/create-user.sh prod-admin-test admin production

# 2. Test each role
for user in prod-viewer-test prod-editor-test prod-admin-test; do
  echo "Testing $user..."
  export KUBECONFIG=~/.kube/test-users/${user}-kubeconfig.yaml
  kubectl auth can-i --list -n production
  unset KUBECONFIG
done

# 3. Once validated, apply to production users
./scripts/rbac-add-namespace-access.sh viewer@company.com production view
./scripts/rbac-add-namespace-access.sh editor@company.com production edit
./scripts/rbac-add-namespace-access.sh admin@company.com production admin
```

---

## Troubleshooting

### Check if user has access

```bash
# As admin, check what a user can do
kubectl auth can-i get pods --as="oidc:user@company.com" -n namespace
kubectl auth can-i delete pods --as="oidc:user@company.com" -n namespace

# List all permissions for a user
kubectl auth can-i --list --as="oidc:user@company.com" -n namespace
```

### Find all bindings for a user

```bash
USER="developer@company.com"

# ClusterRoleBindings
kubectl get clusterrolebindings -o json | \
  jq -r ".items[] | select(.subjects[]?.name | contains(\"$USER\")) | .metadata.name"

# RoleBindings across all namespaces
kubectl get rolebindings --all-namespaces -o json | \
  jq -r ".items[] | select(.subjects[]?.name | contains(\"$USER\")) | \"\(.metadata.namespace)/\(.metadata.name)\""
```

### Verify test user exists

```bash
# List all test users
ls -1 ~/.kube/test-users/*-kubeconfig.yaml 2>/dev/null

# Or use cluster-kubeconfig.sh
./scripts/cluster-kubeconfig.sh 2>&1 | grep "Test user kubeconfigs" -A 20
```

### Test user identity

```bash
export KUBECONFIG=~/.kube/test-users/testuser-kubeconfig.yaml
kubectl auth whoami
# Output: system:serviceaccount:default:testuser

unset KUBECONFIG
```

---

## Tips & Best Practices

### 1. Always test with ServiceAccounts first

```bash
# Before granting OIDC user access, test with ServiceAccount
./scripts/create-user.sh test-role edit myapp
export KUBECONFIG=~/.kube/test-users/test-role-kubeconfig.yaml
# Test thoroughly...
unset KUBECONFIG

# Then grant to real user
./scripts/rbac-add-namespace-access.sh user@company.com myapp edit
```

### 2. Use consistent naming

```bash
# Good - clear purpose
./scripts/rbac-add-namespace-access.sh developer@company.com dev-team edit
./scripts/rbac-add-namespace-access.sh lead@company.com dev-team admin

# Avoid - ambiguous
./scripts/rbac-add-namespace-access.sh user1@company.com ns1 edit
```

### 3. Document access grants

```bash
# Keep a record of access grants
cat >> rbac-changelog.md <<EOF
$(date): Granted edit access to developer@company.com for dev namespace
Reason: New team member onboarding
Approved by: manager@company.com
EOF
```

### 4. Regular access reviews

```bash
# Monthly: Review all admin bindings
kubectl get clusterrolebindings -l rbac.openportal.dev/type=explicit-admin -o yaml

# Quarterly: Review namespace access
kubectl get rolebindings --all-namespaces -l rbac.openportal.dev/type=namespace-scoped
```

### 5. Clean up test users

```bash
# Remove test users after testing
for user in $(ls ~/.kube/test-users/*-kubeconfig.yaml 2>/dev/null); do
  USERNAME=$(basename "$user" -kubeconfig.yaml)
  echo "Remove $USERNAME? (y/N)"
  read response
  if [[ "$response" =~ ^[yY]$ ]]; then
    kubectl delete serviceaccount "$USERNAME" -n default 2>/dev/null || true
    kubectl delete secret "${USERNAME}-token" -n default 2>/dev/null || true
    rm "$user"
  fi
done
```

---

## Quick Reference

```bash
# Migration
./scripts/rbac-migration.sh admin1@co.com admin2@co.com

# Add admin
./scripts/rbac-add-admin.sh user@company.com

# Add namespace access
./scripts/rbac-add-namespace-access.sh user@co.com namespace [view|edit|admin]

# Create test users
./scripts/create-user.sh name [none|view|edit|admin|cluster-admin] [namespace]

# Use test user
export KUBECONFIG=~/.kube/test-users/name-kubeconfig.yaml

# Switch back
unset KUBECONFIG

# Check permissions
kubectl auth can-i <verb> <resource> -n <namespace>
kubectl auth whoami
```
