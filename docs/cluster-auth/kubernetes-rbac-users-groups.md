# Kubernetes RBAC - Users and Groups Inventory

This document focuses exclusively on User and Group RBAC bindings in the Kubernetes cluster.

## Understanding Kubernetes Users and Groups

### How Groups Work in Kubernetes

**Important**: Kubernetes does NOT have a built-in Group resource type. Groups are **virtual** and exist only as:

1. **Authentication Provider Claims**: Groups are provided by your authentication system (OIDC, certificates, webhooks)
2. **Subject References**: Groups are referenced in RoleBindings/ClusterRoleBindings as subjects with `kind: Group`
3. **No CRUD Operations**: You cannot create, read, update, or delete groups using `kubectl`

### Common Group Sources

#### 1. Built-in System Groups
Kubernetes automatically creates these groups:
- `system:masters` - Superuser group (cluster-admin access)
- `system:authenticated` - All authenticated users
- `system:unauthenticated` - All unauthenticated users
- `system:serviceaccounts` - All service accounts cluster-wide
- `system:serviceaccounts:<namespace>` - Service accounts in specific namespace
- `system:nodes` - All kubelet nodes
- `system:bootstrappers:*` - Bootstrap token groups
- `system:monitoring` - Monitoring components

#### 2. Certificate-based Groups
Groups embedded in client certificate subject:
```
Subject: O=system:masters, CN=kubernetes-admin
```
The `O` (Organization) field becomes the group.

#### 3. OIDC Provider Groups
Your OIDC provider (Auth0, Keycloak, Google, etc.) includes groups in the ID token:
```json
{
  "sub": "user@example.com",
  "groups": ["org_zOuCBHiyF1yG8d1D", "developers", "admins"]
}
```

Kubernetes API server is configured to map these claims:
```yaml
--oidc-issuer-url=https://your-oidc-provider.com
--oidc-client-id=kubernetes
--oidc-username-claim=email
--oidc-username-prefix=oidc:
--oidc-groups-claim=groups
--oidc-groups-prefix=oidc:
```

### How Users Work in Kubernetes

**Important**: Like groups, Kubernetes does NOT have a User resource. Users are:

1. **External Identity**: Managed outside Kubernetes (OIDC, certificates, tokens)
2. **String Identifier**: Just a string in the subject field
3. **Authentication Method Determines Format**:
   - Certificates: `CN` field → `system:kube-controller-manager`
   - OIDC: Claim field → `oidc:user@example.com`
   - Service Account: `system:serviceaccount:<namespace>:<name>`

## Cluster-Wide Access (ClusterRoleBindings)

### Cluster Administrators

#### OIDC Users with cluster-admin
```yaml
# Individual users from OIDC provider
User: oidc:fboehm.ext@cloudpunks.de
  → ClusterRole: cluster-admin
  Binding: admin-fboehm-ext
  Annotations:
    rbac.openportal.dev/created-at: "2025-10-27T14:16:05Z"
    rbac.openportal.dev/description: "Cluster admin access for fboehm.ext@cloudpunks.de"
    rbac.openportal.dev/managed-by: rbac-add-admin

User: oidc:mbrueckner@cloudpunks.de
  → ClusterRole: cluster-admin
  Binding: admin-mbrueckner
  Annotations:
    rbac.openportal.dev/created-at: "2025-10-27T14:15:07Z"
    rbac.openportal.dev/description: "Cluster admin access for mbrueckner@cloudpunks.de"
    rbac.openportal.dev/managed-by: rbac-add-admin
```

#### OIDC Groups with cluster-admin
```yaml
# Organization-wide access via OIDC group
Group: oidc:org_zOuCBHiyF1yG8d1D
  → ClusterRole: cluster-admin
  Binding: cloudspace-admin-role
  Created: 2025-10-27T21:18:02Z

# This group is managed by your OIDC provider (Auth0/Keycloak/etc.)
# All members of organization "org_zOuCBHiyF1yG8d1D" get cluster-admin access
```

#### Built-in System Groups
```yaml
# Certificate-based superuser access
Group: system:masters
  → ClusterRole: cluster-admin
  Binding: cluster-admin
  Type: Bootstrap (Kubernetes default)

# Kubeadm cluster admins (if using kubeadm)
Group: kubeadm:cluster-admins
  → ClusterRole: cluster-admin
  Binding: kubeadm:cluster-admins
```

### Crossplane Infrastructure

```yaml
Group: crossplane:masters
  → ClusterRole: crossplane-admin
  Binding: crossplane-admin
  Purpose: Administrative access to Crossplane resources

Group: system:serviceaccounts:crossplane-system
  → ClusterRole: provider-kubernetes-admin
  Binding: provider-kubernetes-admin
  Purpose: Crossplane providers can manage Kubernetes resources
```

### Node and Bootstrap Access

```yaml
# Node cluster membership
Group: system:nodes
  → ClusterRole: system:certificates.k8s.io:certificatesigningrequests:selfnodeclient
  Binding: kubeadm:node-autoapprove-certificate-rotation
  Purpose: Nodes can rotate their own certificates

# Bootstrap token groups (for joining new nodes)
Group: system:bootstrappers:kubeadm:default-node-token
  → ClusterRole: kubeadm:get-nodes
  Binding: kubeadm:get-nodes
  Purpose: Bootstrap tokens can list nodes

Group: system:bootstrappers:kubeadm:default-node-token
  → ClusterRole: system:node-bootstrapper
  Binding: kubeadm:kubelet-bootstrap
  Purpose: Bootstrap new nodes

Group: system:bootstrappers:kubeadm:default-node-token
  → ClusterRole: system:certificates.k8s.io:certificatesigningrequests:nodeclient
  Binding: kubeadm:node-autoapprove-bootstrap
  Purpose: Auto-approve node client certificates
```

### Authenticated User Access

```yaml
# All authenticated users (any user successfully logged in)
Group: system:authenticated
  → ClusterRole: system:basic-user
  Binding: system:basic-user
  Permissions: Basic user capabilities (SelfSubjectAccessReview, SelfSubjectRulesReview)

Group: system:authenticated
  → ClusterRole: system:discovery
  Binding: system:discovery
  Permissions: Read API discovery information

Group: system:authenticated
  → ClusterRole: system:public-info-viewer
  Binding: system:public-info-viewer
  Permissions: Read public cluster info

# All unauthenticated requests
Group: system:unauthenticated
  → ClusterRole: system:public-info-viewer
  Binding: system:public-info-viewer
  Permissions: Read public cluster info (version, health)
```

### Service Account Groups

```yaml
# ALL service accounts cluster-wide
Group: system:serviceaccounts
  → ClusterRole: system:service-account-issuer-discovery
  Binding: system:service-account-issuer-discovery
  Purpose: Service accounts can discover token issuer
```

### System Component Users

```yaml
# Kube-controller-manager
User: system:kube-controller-manager
  → ClusterRole: system:kube-controller-manager
  Binding: system:kube-controller-manager
  Purpose: Controller manager operations

# Kube-scheduler
User: system:kube-scheduler
  → ClusterRole: system:kube-scheduler
  Binding: system:kube-scheduler
  Purpose: Pod scheduling

User: system:kube-scheduler
  → ClusterRole: system:volume-scheduler
  Binding: system:volume-scheduler
  Purpose: Volume scheduling

# Kube-proxy
User: system:kube-proxy
  → ClusterRole: system:node-proxier
  Binding: system:node-proxier
  Purpose: Network proxy on nodes

User: system:kube-proxy
  → ClusterRole: system:node-proxier:pf9
  Binding: system:node-proxier:pf9
  Purpose: Platform9-specific proxy configuration

# Konnectivity server (API server → node communication)
User: system:konnectivity-server
  → ClusterRole: system:auth-delegator
  Binding: system:konnectivity-server
  Purpose: Authentication delegation
```

### Monitoring

```yaml
Group: system:monitoring
  → ClusterRole: system:monitoring
  Binding: system:monitoring
  Purpose: Prometheus and monitoring tools
```

## Namespace-Scoped Access (RoleBindings)

### OIDC User Access

```yaml
# User in demo namespace
User: oidc:test@felixboehm.it
  → ClusterRole: edit (namespace-scoped)
  Namespace: demo
  Bindings:
    - test-at-felixboehm-it-edit-binding (created: 2025-10-27T14:46:47Z)
    - test-edit-binding (created: 2025-10-27T14:31:05Z)
  Annotations:
    rbac.openportal.dev/created-at: "2025-10-27T14:46:45Z"
    rbac.openportal.dev/description: "edit access for test@felixboehm.it in demo namespace"
    rbac.openportal.dev/managed-by: rbac-add-namespace-access

# User in team-felix namespace
User: oidc:test@felixboehm.it
  → ClusterRole: edit (namespace-scoped)
  Namespace: team-felix
  Binding: test-at-felixboehm-it-edit-binding
  Created: 2025-10-27T14:46:27Z
```

### Public Access (Unauthenticated)

```yaml
# Cluster info discovery for bootstrap
User: system:anonymous
  → Role: kubeadm:bootstrap-signer-clusterinfo
  Namespace: kube-public
  Binding: kubeadm:bootstrap-signer-clusterinfo
  Purpose: Allow unauthenticated access to cluster-info ConfigMap
```

### Node Configuration Access

```yaml
# Nodes and bootstrap tokens can read kubelet config
Group: system:nodes
  → Role: kubeadm:kubelet-config
  Namespace: kube-system
  Binding: kubeadm:kubelet-config

Group: system:bootstrappers:kubeadm:default-node-token
  → Role: kubeadm:kubelet-config
  Namespace: kube-system
  Binding: kubeadm:kubelet-config

# Nodes and bootstrap tokens can read kubeadm config
Group: system:nodes
  → Role: kubeadm:nodes-kubeadm-config
  Namespace: kube-system
  Binding: kubeadm:nodes-kubeadm-config

Group: system:bootstrappers:kubeadm:default-node-token
  → Role: kubeadm:nodes-kubeadm-config
  Namespace: kube-system
  Binding: kubeadm:nodes-kubeadm-config

# Bootstrap tokens can read kube-proxy config
Group: system:bootstrappers:kubeadm:default-node-token
  → Role: rxt-kube-proxy
  Namespace: kube-system
  Binding: rxt-kube-proxy
```

### System Component Leader Election

```yaml
# Controller manager extension apiserver authentication
User: system:kube-controller-manager
  → Role: extension-apiserver-authentication-reader
  Namespace: kube-system
  Binding: system::extension-apiserver-authentication-reader

# Scheduler extension apiserver authentication
User: system:kube-scheduler
  → Role: extension-apiserver-authentication-reader
  Namespace: kube-system
  Binding: system::extension-apiserver-authentication-reader

# Controller manager leader election
User: system:kube-controller-manager
  → Role: system::leader-locking-kube-controller-manager
  Namespace: kube-system
  Binding: system::leader-locking-kube-controller-manager

# Scheduler leader election
User: system:kube-scheduler
  → Role: system::leader-locking-kube-scheduler
  Namespace: kube-system
  Binding: system::leader-locking-kube-scheduler
```

## Summary Statistics

### Users
- **OIDC Users**: 3 unique users
  - `oidc:fboehm.ext@cloudpunks.de` (cluster-admin)
  - `oidc:mbrueckner@cloudpunks.de` (cluster-admin)
  - `oidc:test@felixboehm.it` (namespace edit access in demo, team-felix)

- **System Users**: 4 unique system accounts
  - `system:kube-controller-manager`
  - `system:kube-scheduler`
  - `system:kube-proxy`
  - `system:konnectivity-server`
  - `system:anonymous` (public access)

### Groups
- **OIDC Groups**: 1 organization group
  - `oidc:org_zOuCBHiyF1yG8d1D` (cluster-admin)

- **System Groups**: 12 built-in groups
  - `system:masters` (superuser)
  - `system:authenticated` (all logged-in users)
  - `system:unauthenticated` (anonymous access)
  - `system:nodes` (all kubelets)
  - `system:bootstrappers:kubeadm:default-node-token` (node bootstrap)
  - `system:serviceaccounts` (all service accounts)
  - `system:serviceaccounts:crossplane-system` (Crossplane SAs)
  - `system:monitoring` (monitoring tools)
  - `kubeadm:cluster-admins` (kubeadm admins)
  - `crossplane:masters` (Crossplane admins)

## How to Manage Users and Groups

### Adding Users

Users are NOT created in Kubernetes. They come from:

1. **OIDC Provider** (recommended for production):
   ```bash
   # Users exist in your Auth0/Keycloak/Google/etc.
   # Just grant them access via RoleBindings
   ./scripts/rbac-add-admin.sh user@example.com
   ./scripts/rbac-add-namespace-access.sh user@example.com namespace-name edit
   ```

2. **Client Certificates**:
   ```bash
   # Create certificate with CN=username, O=groupname
   openssl req -new -key user.key -out user.csr -subj "/CN=john/O=developers"
   # Sign with Kubernetes CA
   ```

3. **Service Account Tokens** (for automation):
   ```bash
   kubectl create serviceaccount my-app
   kubectl create token my-app
   ```

### Managing Groups

Groups are defined by your authentication provider:

#### OIDC Groups
Configure in your OIDC provider (Auth0, Keycloak, etc.):
```yaml
# In OIDC provider, add users to groups
# Groups appear in ID token automatically

# In Kubernetes API server config:
--oidc-groups-claim=groups
--oidc-groups-prefix=oidc:
```

Then reference in bindings:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: developers-access
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: edit
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: oidc:developers  # Matches group from OIDC provider
```

#### Certificate Groups
Embedded in certificate O (Organization) field:
```bash
openssl req -new -key user.key -out user.csr \
  -subj "/CN=john/O=developers/O=team-frontend"
# This user will be in groups: developers, team-frontend
```

#### System Groups
Built-in, cannot be modified. Use them in bindings:
```yaml
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: system:authenticated  # All logged-in users
```

## OpenPortal RBAC Management Scripts

Your cluster uses custom scripts with annotations:

### User Management

#### Adding Cluster Admin
```bash
./scripts/rbac-add-admin.sh user@example.com
```
Creates ClusterRoleBinding with:
- Annotations: `rbac.openportal.dev/managed-by=rbac-add-admin`
- Labels: `rbac.openportal.dev/type=explicit-admin`

#### Adding Namespace Access
```bash
./scripts/rbac-add-namespace-access.sh user@example.com namespace-name edit
```
Creates RoleBinding with:
- Annotations: `rbac.openportal.dev/managed-by=rbac-add-namespace-access`
- Labels: `rbac.openportal.dev/type=namespace-scoped`

#### Creating Test Users (Service Account Based)
```bash
./scripts/create-user.sh testuser edit myapp
```
Creates a ServiceAccount with token authentication for testing.

### Group Management

#### Creating OIDC Groups
```bash
# Cluster-wide access
./scripts/rbac-create-group.sh developers cluster-admin

# Namespace-scoped access
./scripts/rbac-create-group.sh backend-team edit backend-ns
```
Creates ClusterRoleBinding or RoleBinding with:
- Annotations: `rbac.openportal.dev/managed-by=rbac-create-group`
- Labels: `rbac.openportal.dev/type=group-access` or `group-namespace-access`

**Important**: This only creates the Kubernetes RBAC binding. You must manage group membership in your OIDC provider (Auth0, Keycloak, etc.).

#### Adding Users to Groups
```bash
./scripts/rbac-add-user-to-group.sh user@example.com developers
```
This is a **documentation helper** that:
- Verifies the group has Kubernetes RBAC bindings
- Provides instructions for adding users in your OIDC provider
- Shows test commands to verify access

**Note**: Users are added to groups in your OIDC provider, NOT in Kubernetes.

### Listing RBAC

#### List All Custom Bindings (OIDC Only)
```bash
# Human-readable table
./scripts/rbac-list-custom.sh

# JSON output
./scripts/rbac-list-custom.sh json

# CSV export
./scripts/rbac-list-custom.sh csv > rbac-export.csv

# YAML format
./scripts/rbac-list-custom.sh yaml
```

Shows only OIDC users and groups (excludes system accounts).

### Removing Access
```bash
./scripts/rbac-remove-access.sh user@example.com
```

## Key Takeaways

1. **Groups are Virtual**: No Group resource in Kubernetes, only references in bindings
2. **Authentication Provides Identity**: OIDC, certificates, tokens define users and groups
3. **RBAC Links Identity to Permissions**: RoleBindings connect users/groups to roles
4. **OIDC is Recommended**: Centralized user/group management, easier to audit
5. **System Groups are Built-in**: Use them for common patterns (all users, nodes, etc.)
6. **Prefix Conventions Matter**: `oidc:`, `system:`, custom prefixes help identify source

---

**Generated**: 2025-10-31
**Total User Bindings**: 8 (5 OIDC users/groups, 3 system users)
**Total Group Bindings**: 15 (1 OIDC group, 14 system groups)
**Authentication**: OIDC-based with prefix `oidc:`
