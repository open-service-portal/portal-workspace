# Kubernetes User and Group Management

## Overview

This document describes the user and group management approach for Kubernetes clusters using client certificate-based authentication and RBAC.

## Key Concepts

### Users in Kubernetes

Kubernetes does **not** have User objects. Users are virtual identities that exist only in authentication:

- **Client Certificates**: X.509 certificates with username in CN (Common Name) field
- **OIDC Tokens**: JWT tokens from identity providers (future enhancement)
- **Service Accounts**: For pods and applications (different from human users)

### Groups in Kubernetes

Kubernetes does **not** have Group objects. Groups are virtual identities embedded in authentication:

- **Certificate Groups**: Organization (O=) field in certificate subject
- **OIDC Groups**: Claims from identity provider
- **System Groups**: Built-in groups like `system:authenticated`, `system:masters`

Groups only exist as references in RoleBindings and ClusterRoleBindings.

## User Management Scripts

All user management scripts are located in `scripts/users/`:

### User Creation
- `create-user.sh` - Basic user creation with client certificate
- `create-user-with-cert.sh` - User with client certificate and specified role
- `create-user-with-group.sh` - User with certificate-based group membership

### Group Management
- `rbac-create-group.sh` - Create group-based RBAC structure
- `rbac-add-user-to-group.sh` - Add user to existing group
- `list-groups.sh` - List all groups referenced in cluster

### Permission Management
- `rbac-add-admin.sh` - Grant cluster-admin access to user
- `rbac-add-namespace-access.sh` - Grant namespace-scoped access
- `rbac-list-custom.sh` - List custom RBAC resources

## RBAC Templates

All RBAC templates are stored in `scripts/manifests/users/`:

- `rbac-admin.template.yaml` - ClusterRoleBinding for cluster-admin
- `rbac-namespace-access.template.yaml` - RoleBinding for namespace access
- `rbac-group.template.yaml` - ClusterRoleBinding for groups
- `rbac-group-namespace.template.yaml` - RoleBinding for group namespace access

## Authentication Flow

```
1. User generates private key
2. User creates CSR (Certificate Signing Request)
3. Admin approves CSR in Kubernetes
4. Kubernetes CA signs the certificate
5. User configures kubeconfig with certificate
6. User authenticates to API server with certificate
7. API server extracts user/groups from certificate
8. RBAC checks permissions based on RoleBindings
```

## Certificate-Based Authentication

### Advantages
- No external dependencies
- Simple setup for development/testing
- Fine-grained control via RBAC
- Works offline

### Limitations
- Manual certificate rotation
- No built-in group management UI
- Requires cluster access to create users

## Group-Based Access Control

Best practice is to use groups instead of individual user bindings:

```bash
# Create a group
./scripts/users/rbac-create-group.sh developers dev edit

# Add users to the group
./scripts/users/rbac-add-user-to-group.sh alice developers
./scripts/users/rbac-add-user-to-group.sh bob developers
```

This approach:
- Centralizes permission management
- Makes it easy to onboard/offboard users
- Follows principle of least privilege
- Scales better than per-user bindings

## Common Workflows

### Onboard Developer
```bash
# Create user with namespace access
./scripts/users/create-user-with-group.sh alice dev edit

# User receives kubeconfig and can access dev namespace
```

### Create Team
```bash
# Create group with shared access
./scripts/users/rbac-create-group.sh backend-team backend admin

# Add team members
./scripts/users/rbac-add-user-to-group.sh alice backend-team
./scripts/users/rbac-add-user-to-group.sh bob backend-team
```

### Grant Admin Access
```bash
# Grant cluster-admin to platform admin
./scripts/users/rbac-add-admin.sh admin@example.com
```

## Security Best Practices

1. **Principle of Least Privilege**: Start with minimal permissions
2. **Use Groups**: Manage permissions at group level
3. **Namespace Isolation**: Use namespace-scoped roles when possible
4. **Audit Regularly**: Use `rbac-list-custom.sh` to review permissions
5. **Certificate Rotation**: Plan for certificate expiration and renewal

## Future Enhancements

- **OIDC Integration**: Centralized identity management
- **Automated Certificate Rotation**: Reduce manual overhead
- **Self-Service Portal**: Allow users to request access
- **Audit Logging**: Track permission changes

## Related Documentation

- [User Management Guide](../docs/users/README.md) - Complete usage guide
- [RBAC Scripts Overview](../docs/cluster-auth/rbac-scripts-overview.md) - Technical details
