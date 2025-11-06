# RBAC Management Scripts Overview

This document provides an overview of all RBAC management scripts available in the portal-workspace.

## Understanding Kubernetes Groups

**Key Concept**: Kubernetes does NOT have a Group resource. Groups are virtual identities provided by:
- **OIDC Providers** (Auth0, Keycloak, Google Workspace, etc.)
- **Client Certificates** (O field in certificate subject)
- **Built-in System Groups** (`system:authenticated`, `system:masters`, etc.)

Groups only exist as references in RoleBindings and ClusterRoleBindings.

## Script Categories

### 1. User Management Scripts

#### `rbac-add-admin.sh`
**Purpose**: Grant cluster-admin access to an OIDC user

```bash
./scripts/rbac-add-admin.sh user@example.com
```

**Creates**:
- ClusterRoleBinding with `cluster-admin` role
- Annotations: `rbac.openportal.dev/managed-by=rbac-add-admin`
- Labels: `rbac.openportal.dev/type=explicit-admin`

**Use Case**: Grant full cluster access to platform administrators

---

#### `rbac-add-namespace-access.sh`
**Purpose**: Grant namespace-scoped access to an OIDC user

```bash
./scripts/rbac-add-namespace-access.sh user@example.com my-namespace edit
```

**Arguments**:
- User email (OIDC)
- Namespace name
- Role: `view`, `edit`, or `admin` (default: `edit`)

**Creates**:
- Namespace (if doesn't exist)
- RoleBinding in the namespace
- Annotations: `rbac.openportal.dev/managed-by=rbac-add-namespace-access`
- Labels: `rbac.openportal.dev/type=namespace-scoped`

**Use Case**: Grant developers access to their team's namespace

---

#### `create-user.sh`
**Purpose**: Create test users using ServiceAccount tokens (NOT OIDC)

```bash
./scripts/create-user.sh testuser edit myapp
```

**Creates**:
- ServiceAccount in specified namespace
- Secret with token
- RoleBinding or ClusterRoleBinding based on permission
- Kubeconfig file at `~/.kube/test-users/<username>-kubeconfig.yaml`

**Use Case**: Testing RBAC policies without OIDC setup

---

### 2. Group Management Scripts

#### `rbac-create-group.sh` ⭐ NEW
**Purpose**: Create RBAC bindings for an OIDC group

```bash
# Cluster-wide access
./scripts/rbac-create-group.sh developers cluster-admin

# Namespace-scoped access
./scripts/rbac-create-group.sh backend-team edit backend-ns
```

**Arguments**:
- Group name (as defined in OIDC provider)
- Role: `cluster-admin`, `admin`, `edit`, or `view` (default: `cluster-admin`)
- Namespace (required for non-cluster-admin roles)

**Creates**:
- ClusterRoleBinding (cluster-wide) OR RoleBinding (namespace-scoped)
- Annotations: `rbac.openportal.dev/managed-by=rbac-create-group`
- Labels: `rbac.openportal.dev/type=group-access` or `group-namespace-access`

**Important**: This only creates the Kubernetes RBAC binding. Group membership is managed in your OIDC provider.

**Use Case**: Grant permissions to teams/departments managed in your OIDC provider

---

#### `rbac-add-user-to-group.sh` ⭐ NEW
**Purpose**: Documentation helper for adding users to OIDC groups

```bash
./scripts/rbac-add-user-to-group.sh user@example.com developers
```

**What It Does**:
1. Verifies the group has Kubernetes RBAC bindings
2. Shows existing permissions for the group
3. Provides step-by-step instructions for adding users in common OIDC providers
4. Shows test commands to verify access after adding

**Important**: This is a **helper script only**. It does NOT add users to groups (that's done in your OIDC provider).

**Use Case**: Get instructions for adding users to groups in Auth0, Keycloak, Google, etc.

---

### 3. Listing and Reporting Scripts

#### `rbac-list-custom.sh` ⭐ NEW
**Purpose**: List only custom RBAC bindings (OIDC users and groups)

```bash
# Human-readable table
./scripts/rbac-list-custom.sh

# JSON output (for automation)
./scripts/rbac-list-custom.sh json

# CSV export (for spreadsheets)
./scripts/rbac-list-custom.sh csv > rbac-export.csv

# YAML format
./scripts/rbac-list-custom.sh yaml
```

**Filters Out**:
- System service accounts (`system:serviceaccount:*`)
- System users (`system:*`)
- System groups (`system:*`, `kubeadm:*`, `crossplane:*`)
- All Kubernetes built-in bindings

**Shows Only**:
- OIDC users (`oidc:user@example.com`)
- OIDC groups (`oidc:groupname`)

**Output Sections**:
1. OIDC Users (with role and scope)
2. OIDC Groups (with role and scope)

**Use Case**: Audit and report on human access (excluding system components)

---

### 4. Removal Scripts

#### `rbac-remove-access.sh`
**Purpose**: Remove RBAC bindings for a user or group

```bash
./scripts/rbac-remove-access.sh user@example.com
```

**Note**: Check if this script exists, or use kubectl directly:
```bash
kubectl delete clusterrolebinding admin-<username>
kubectl delete rolebinding <username>-edit-binding -n <namespace>
```

---

## Complete Workflow Examples

### Example 1: Onboarding a New Admin

```bash
# 1. Add user as cluster admin
./scripts/rbac-add-admin.sh jane@example.com

# 2. Verify access
./scripts/rbac-list-custom.sh

# 3. User logs in via OIDC and gets cluster-admin access
```

---

### Example 2: Creating a Development Team

```bash
# 1. Create OIDC group binding for cluster access
./scripts/rbac-create-group.sh developers edit

# 2. Grant group access to dev namespace
./scripts/rbac-create-group.sh developers edit dev-namespace

# 3. Add users to the 'developers' group in your OIDC provider
#    (Use Auth0/Keycloak/Google admin console)

# 4. Get instructions for adding a specific user
./scripts/rbac-add-user-to-group.sh john@example.com developers

# 5. Verify bindings
./scripts/rbac-list-custom.sh
```

---

### Example 3: Testing RBAC Without OIDC

```bash
# 1. Create test user with edit access
./scripts/create-user.sh testuser edit myapp

# 2. Test with the generated kubeconfig
export KUBECONFIG=~/.kube/test-users/testuser-kubeconfig.yaml
kubectl get pods -n myapp

# 3. Clean up
unset KUBECONFIG
kubectl delete serviceaccount testuser -n myapp
kubectl delete secret testuser-token -n myapp
kubectl delete rolebinding testuser-edit -n myapp
```

---

### Example 4: Exporting RBAC for Audit

```bash
# Export to CSV for compliance reporting
./scripts/rbac-list-custom.sh csv > rbac-audit-$(date +%Y%m%d).csv

# Get JSON for automation
./scripts/rbac-list-custom.sh json | jq -r '.[] | select(.role == "cluster-admin")'

# Generate YAML backup
./scripts/rbac-list-custom.sh yaml > rbac-backup.yaml
```

---

## File Locations

### Scripts
- `/scripts/rbac-add-admin.sh` - Add cluster admin
- `/scripts/rbac-add-namespace-access.sh` - Add namespace access
- `/scripts/create-user.sh` - Create test users
- `/scripts/rbac-create-group.sh` ⭐ - Create group bindings
- `/scripts/rbac-add-user-to-group.sh` ⭐ - Helper for adding users to groups
- `/scripts/rbac-list-custom.sh` ⭐ - List OIDC users/groups

### Templates
- `/scripts/manifests/setup/rbac-admin.template.yaml` - User admin binding
- `/scripts/manifests/setup/rbac-namespace-access.template.yaml` - Namespace access
- `/scripts/manifests/setup/rbac-group.template.yaml` ⭐ - Group cluster binding
- `/scripts/manifests/setup/rbac-group-namespace.template.yaml` ⭐ - Group namespace binding

### Documentation
- `/docs/kubernetes-rbac-inventory.md` - Complete RBAC inventory (all resources)
- `/docs/kubernetes-rbac-users-groups.md` - Focused on users and groups
- `/docs/rbac-scripts-overview.md` - This file

---

## Best Practices

### 1. Use Groups for Teams
✅ **Do**: Create OIDC groups for teams/departments
```bash
./scripts/rbac-create-group.sh backend-team edit backend-ns
./scripts/rbac-create-group.sh platform-team cluster-admin
```

❌ **Don't**: Grant individual users cluster-admin
```bash
# Avoid this unless necessary
./scripts/rbac-add-admin.sh user@example.com
```

### 2. Principle of Least Privilege
✅ **Do**: Grant only necessary permissions
```bash
# Give developers edit access to their namespace
./scripts/rbac-add-namespace-access.sh dev@example.com dev-team edit
```

❌ **Don't**: Grant cluster-admin by default
```bash
# Avoid unless the user is a platform admin
./scripts/rbac-add-admin.sh dev@example.com
```

### 3. Document Access Changes
✅ **Do**: Use descriptions and annotations
```bash
# Scripts automatically add descriptions
./scripts/rbac-create-group.sh admins cluster-admin
```

✅ **Do**: Export regular audits
```bash
# Weekly audit export
./scripts/rbac-list-custom.sh csv > audits/rbac-$(date +%Y%m%d).csv
```

### 4. Test Before Production
✅ **Do**: Use test users for validation
```bash
# Test RBAC policies without affecting real users
./scripts/create-user.sh testuser edit test-ns
export KUBECONFIG=~/.kube/test-users/testuser-kubeconfig.yaml
kubectl auth can-i list pods -n test-ns  # Should be yes
kubectl auth can-i delete nodes  # Should be no
```

---

## Troubleshooting

### User Can't Access After Adding to Group

**Symptom**: User added to OIDC group but still can't access Kubernetes

**Solutions**:
1. **Verify Kubernetes binding exists**:
   ```bash
   ./scripts/rbac-list-custom.sh | grep groupname
   ```

2. **User must re-login**:
   - Group membership is in the OIDC token
   - Token is issued at login time
   - User needs to log out and log back in

3. **Check OIDC token claims**:
   ```bash
   kubectl auth whoami  # Should show groups
   ```

4. **Verify OIDC provider configuration**:
   - Ensure group claim is included in ID token
   - Check Kubernetes API server OIDC flags:
     ```bash
     kubectl get pod -n kube-system -l component=kube-apiserver -o yaml | grep oidc
     ```

---

### Group Not Found in Kubernetes

**Symptom**: `./scripts/rbac-add-user-to-group.sh` says "No RBAC bindings found"

**Solutions**:
1. **Create the group binding first**:
   ```bash
   ./scripts/rbac-create-group.sh groupname edit namespace
   ```

2. **Verify binding was created**:
   ```bash
   kubectl get clusterrolebinding | grep groupname
   kubectl get rolebinding -A | grep groupname
   ```

---

### OIDC Prefix Issues

**Symptom**: Bindings exist but users can't access

**Problem**: OIDC username/group prefix mismatch

**Check API server configuration**:
```bash
# Username prefix should be "oidc:"
--oidc-username-prefix=oidc:

# Groups prefix should be "oidc:"
--oidc-groups-prefix=oidc:
```

**Verify bindings use correct prefix**:
```bash
kubectl get clusterrolebinding -o yaml | grep "name: oidc:"
```

---

## Security Considerations

1. **Limit cluster-admin access**: Only grant to platform team
2. **Use namespace-scoped roles**: Prefer `edit`/`admin` over `cluster-admin`
3. **Regular audits**: Export and review RBAC monthly
4. **Group over individual**: Manage access via groups, not individual users
5. **Document all admin actions**: Use script annotations automatically

---

## Quick Reference

| Task | Command |
|------|---------|
| Add cluster admin | `./scripts/rbac-add-admin.sh user@example.com` |
| Add namespace access | `./scripts/rbac-add-namespace-access.sh user@example.com ns edit` |
| Create group (cluster) | `./scripts/rbac-create-group.sh groupname cluster-admin` |
| Create group (namespace) | `./scripts/rbac-create-group.sh groupname edit namespace` |
| Add user to group help | `./scripts/rbac-add-user-to-group.sh user@example.com groupname` |
| List all custom RBAC | `./scripts/rbac-list-custom.sh` |
| Export to CSV | `./scripts/rbac-list-custom.sh csv > export.csv` |
| Create test user | `./scripts/create-user.sh testuser edit namespace` |

---

**Generated**: 2025-10-31
**New Scripts**: 3 (rbac-create-group.sh, rbac-add-user-to-group.sh, rbac-list-custom.sh)
**Total Scripts**: 6 RBAC management scripts
