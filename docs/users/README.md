# User Management Guide

Comprehensive guide for managing Kubernetes users and RBAC permissions in the Open Service Portal.

## Overview

This directory contains scripts and documentation for managing users and permissions in Kubernetes clusters. All scripts are located in `scripts/users/`.

## Quick Start

```bash
# Grant cluster admin access
./scripts/users/create-user-with-cert.sh alice admin

# Create user with namespace access
./scripts/users/create-user-with-group.sh bob my-namespace

# List all custom RBAC resources
./scripts/users/rbac-list-custom.sh

# List all groups referenced in RoleBindings
./scripts/users/list-groups.sh
```

## Understanding Kubernetes Users and Groups

**Important**: Kubernetes does NOT store users or groups as cluster resources.

### Users
- No User resource exists in Kubernetes
- Users are authenticated via:
  - Client certificates (X.509)
  - OIDC tokens (Auth0, Keycloak, Google Workspace, etc.)
  - Service Account tokens (for pods)

### Groups
- No Group resource exists in Kubernetes
- Groups are virtual identities embedded in authentication:
  - **OIDC**: Groups come from identity provider claims
  - **Certificates**: `O=` field in subject (Organization)
  - **System groups**: `system:authenticated`, `system:masters`, etc.
- Groups only exist as references in RoleBindings/ClusterRoleBindings

## Script Reference

### User Creation Scripts

#### `create-user-with-cert.sh`
Creates a Kubernetes user with client certificate authentication.

```bash
./scripts/users/create-user-with-cert.sh <username> [role]
```

**Arguments:**
- `username`: Username for the new user
- `role`: Kubernetes role (default: `admin`)
  - `cluster-admin`: Full cluster access
  - `admin`: Full access within namespace
  - `edit`: Read/write access
  - `view`: Read-only access

**What it does:**
1. Generates a private key and CSR (Certificate Signing Request)
2. Creates CertificateSigningRequest resource in cluster
3. Approves and retrieves the certificate
4. Creates kubeconfig file for the user
5. Creates RoleBinding for namespace access

**Output:**
- Kubeconfig file: `~/.kube/config-<username>`
- Certificate and key stored in cluster

**Example:**
```bash
# Create admin user with full cluster access
./scripts/users/create-user-with-cert.sh alice cluster-admin

# Create developer with namespace access
./scripts/users/create-user-with-cert.sh bob edit
```

---

#### `create-user-with-group.sh`
Creates a user with certificate-based group membership.

```bash
./scripts/users/create-user-with-group.sh <username> <namespace> [group-role]
```

**Arguments:**
- `username`: Username for the new user
- `namespace`: Target namespace for access
- `group-role`: Role for the group (default: `edit`)

**What it does:**
1. Creates a group based on namespace: `<namespace>-users`
2. Generates certificate with group in O= field
3. Creates RoleBinding that grants access to the group
4. Generates kubeconfig for the user

**Key Feature:** Users belong to groups, and permissions are granted to groups (not individual users).

**Example:**
```bash
# Create user bob in dev namespace with edit access
./scripts/users/create-user-with-group.sh bob dev edit

# Create user alice in prod namespace with admin access
./scripts/users/create-user-with-group.sh alice prod admin
```

---

### Group Management Scripts

#### `rbac-create-group.sh`
Creates a virtual group by creating RoleBindings that reference the group.

```bash
./scripts/users/rbac-create-group.sh <group-name> <namespace> [role]
```

**Important**: This doesn't create a Group resource (none exists in K8s). It creates the RBAC structure that references a group.

**What it does:**
1. Creates namespace if it doesn't exist
2. Creates RoleBinding with group as subject
3. Adds labels and annotations for tracking

**Example:**
```bash
# Create developers group with edit access in dev namespace
./scripts/users/rbac-create-group.sh developers dev edit

# Create admins group with admin access in prod namespace
./scripts/users/rbac-create-group.sh admins prod admin
```

---

#### `rbac-add-user-to-group.sh`
Adds a user to an existing group by creating a certificate with the group in O= field.

```bash
./scripts/users/rbac-add-user-to-group.sh <username> <group-name>
```

**What it does:**
1. Generates certificate with group in Organization field
2. Creates kubeconfig for the user
3. User inherits all permissions of the group

**Example:**
```bash
# Add alice to developers group
./scripts/users/rbac-add-user-to-group.sh alice developers

# Add bob to admins group
./scripts/users/rbac-add-user-to-group.sh bob admins
```

---

### Listing and Discovery Scripts

#### `list-groups.sh`
Lists all groups referenced in RoleBindings and ClusterRoleBindings across the cluster.

```bash
./scripts/users/list-groups.sh
```

**Output:**
- All unique group names
- Namespaces where each group is referenced
- Count of bindings per group

**Example output:**
```
Group: developers
  Namespace: dev (2 bindings)
  Namespace: staging (1 binding)

Group: admins
  Cluster-wide (1 ClusterRoleBinding)
  Namespace: prod (1 binding)
```

---

#### `rbac-list-custom.sh`
Lists all custom RBAC resources created by our scripts (filtered by labels/annotations).

```bash
./scripts/users/rbac-list-custom.sh
```

**Shows:**
- RoleBindings with `rbac.openportal.dev/managed-by` annotation
- ClusterRoleBindings with OpenPortal labels
- Grouping by namespace and type

**Useful for:**
- Auditing permissions
- Finding resources to clean up
- Understanding current access setup

---

## RBAC Templates

Located in `scripts/users/`, these templates are used by the scripts to create RBAC resources:

- `rbac-group.template.yaml` - ClusterRoleBinding template for group access
- `rbac-group-namespace.template.yaml` - RoleBinding template for namespace-scoped group access

## Authentication Methods Comparison

| Method | Pros | Cons | Use Case |
|--------|------|------|----------|
| **Client Certificates** | Simple, no external deps | Manual rotation, no groups | Development, testing |
| **OIDC** | Centralized, automatic expiry, groups | Requires identity provider | Production, teams |
| **Service Accounts** | Built-in, namespace-scoped | Limited to pods | Application workloads |

## Common Workflows

### Onboarding a New Developer

```bash
# Option 1: Direct namespace access
./scripts/users/create-user-with-cert.sh alice edit

# Option 2: Group-based access (recommended)
./scripts/users/rbac-create-group.sh developers dev edit
./scripts/users/rbac-add-user-to-group.sh alice developers
```

### Creating a Team with Shared Access

```bash
# 1. Create the group and bind permissions
./scripts/users/rbac-create-group.sh frontend-team frontend-ns admin

# 2. Add team members
./scripts/users/rbac-add-user-to-group.sh alice frontend-team
./scripts/users/rbac-add-user-to-group.sh bob frontend-team
./scripts/users/rbac-add-user-to-group.sh charlie frontend-team
```

### Auditing Current Access

```bash
# See all groups
./scripts/users/list-groups.sh

# See all custom RBAC resources
./scripts/users/rbac-list-custom.sh

# Check specific user's access
kubectl auth can-i --list --as=alice
```

### Removing Access

```bash
# Find the RoleBinding
kubectl get rolebinding -A | grep alice

# Delete the RoleBinding
kubectl delete rolebinding alice-binding -n dev

# Revoke certificate (prevents kubectl access)
kubectl delete certificatesigningrequest alice
```

## Best Practices

### 1. Use Groups, Not Individual Users
- Create groups for teams/roles
- Add users to groups
- Easier to manage permissions at scale

### 2. Principle of Least Privilege
- Start with minimal permissions (`view`)
- Grant additional access as needed
- Avoid `cluster-admin` except for platform admins

### 3. Namespace Isolation
- Use namespace-scoped RoleBindings when possible
- Only use ClusterRoleBindings for platform-wide access
- Create namespaces per team/project

### 4. Label and Annotate
- All scripts add `rbac.openportal.dev/managed-by` annotations
- Use labels for filtering: `rbac.openportal.dev/type=explicit-admin`
- Makes auditing and cleanup easier

### 5. Documentation
- Document why permissions were granted
- Use descriptive group names
- Keep track of who has cluster-admin

## Troubleshooting

### User Can't Access Cluster

```bash
# Check if certificate exists
kubectl get csr | grep username

# Check if RoleBinding exists
kubectl get rolebinding -A | grep username

# Test user's permissions
kubectl auth can-i --list --as=username
```

### Group Not Working

```bash
# Verify group exists in RoleBindings
./scripts/users/list-groups.sh | grep group-name

# Check certificate has correct group
openssl x509 -in cert.pem -noout -subject

# Verify group in kubeconfig
kubectl config view --minify
```

### Permission Denied Errors

```bash
# Check what user CAN do
kubectl auth can-i --list --as=username --namespace=dev

# Check specific permission
kubectl auth can-i get pods --as=username --namespace=dev

# View RoleBinding details
kubectl describe rolebinding binding-name -n namespace
```

## Migration to OIDC

For production environments, consider migrating from client certificates to OIDC:

1. Set up OIDC provider (Auth0, Keycloak, Google Workspace)
2. Configure kubectl for OIDC authentication
3. Create RoleBindings using OIDC user emails and groups
4. Phase out client certificates

See the [OIDC Authentication Guide](../../concepts/2025-10-23-oidc-kubernetes-authentication.md) for details.

## Related Documentation

- [OIDC Authentication Concept](../../concepts/2025-10-23-oidc-kubernetes-authentication.md) - Understanding OIDC auth
- [Cluster Authentication](../cluster-auth/) - Detailed authentication docs
- [RBAC Scripts Overview](../cluster-auth/rbac-scripts-overview.md) - Technical script details

## Script Annotations and Labels

All scripts use consistent annotations and labels for tracking:

**Annotations:**
- `rbac.openportal.dev/managed-by` - Which script created the resource
- `rbac.openportal.dev/created-at` - Timestamp
- `rbac.openportal.dev/namespace` - Target namespace (if applicable)

**Labels:**
- `rbac.openportal.dev/type` - Type of access (e.g., `explicit-admin`, `namespace-scoped`)
- `rbac.openportal.dev/group` - Group name (if group-based)

These make it easy to query and manage resources:

```bash
# Find all resources created by our scripts
kubectl get rolebindings -A -l rbac.openportal.dev/type

# Find resources created by specific script
kubectl get clusterrolebindings -o yaml | grep "managed-by: rbac-add-admin"
```

## Manifest Templates

All RBAC templates used by the user management scripts are located in `scripts/manifests/users/`:

- `rbac-admin.template.yaml` - ClusterRoleBinding for cluster-admin access
- `rbac-namespace-access.template.yaml` - RoleBinding for namespace-scoped access  
- `rbac-group.template.yaml` - ClusterRoleBinding for group-based access
- `rbac-group-namespace.template.yaml` - RoleBinding for group-based namespace access

These templates use environment variable substitution (`envsubst`) and are processed by the scripts before applying to the cluster.
