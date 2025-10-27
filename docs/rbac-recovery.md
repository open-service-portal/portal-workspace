# RBAC Recovery Guide

## Overview

This guide explains how to recover the `cloudspace-admin-role` ClusterRoleBinding if it gets accidentally removed during RBAC streamlining or troubleshooting.

## Background

The `cloudspace-admin-role` ClusterRoleBinding grants cluster-admin privileges to the OIDC group `oidc:org_zOuCBHiyF1yG8d1D`. This is the primary administrative access for your organization's users.

When streamlining RBAC to use fine-grained permissions, this binding may be removed. If you lose access, the recovery script can restore it using the `backstage-k8s-sa` service account, which has permanent cluster-admin access.

## Quick Recovery

```bash
# Run the recovery script
./scripts/recover-rbac.sh
```

The script will:
1. Check if the ClusterRoleBinding already exists
2. Attempt to use your current kubectl context
3. Fall back to the `backstage-k8s-sa` service account token if needed
4. Recreate the `cloudspace-admin-role` ClusterRoleBinding
5. Verify the recovery was successful

## Prerequisites

### Required
- `kubectl` installed and in PATH
- Kubernetes cluster access

### At least one of the following
- Current kubectl context has cluster-admin permissions, **OR**
- Token file exists at: `backstage-k8s-sa-token.local.txt`

## What Gets Recovered

The script recreates this ClusterRoleBinding:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cloudspace-admin-role
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: oidc:org_zOuCBHiyF1yG8d1D
```

## Authentication Methods

### Method 1: Current kubectl Context (Preferred)
If your current kubectl context still has permissions, the script will use it automatically.

```bash
# Check if you have permissions
kubectl auth can-i create clusterrolebindings

# Run recovery
./scripts/recover-rbac.sh
```

### Method 2: Service Account Token (Fallback)
If you've lost access, use the `backstage-k8s-sa` service account token:

```bash
# Ensure token file exists
ls -la backstage-k8s-sa-token.local.txt

# Run recovery
./scripts/recover-rbac.sh
```

The token file should already exist in the workspace root if you've run `./scripts/cluster-config.sh`.

## Recovery Scenarios

### Scenario 1: ClusterRoleBinding Accidentally Deleted
```bash
# You have kubectl access but deleted the binding
./scripts/recover-rbac.sh
# Script uses current context to recreate
```

### Scenario 2: Complete Loss of Access
```bash
# You removed the binding and now can't authenticate
# Use the service account token fallback
./scripts/recover-rbac.sh
# Script uses backstage-k8s-sa token to recreate
```

### Scenario 3: ClusterRoleBinding Already Exists
```bash
# Script detects existing binding
./scripts/recover-rbac.sh
# Prompts: "Do you want to recreate it? (y/N)"
# Select 'N' to abort or 'y' to replace
```

## Troubleshooting

### Error: "kubectl is not installed or not in PATH"
**Solution:** Install kubectl or add it to your PATH

```bash
# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

### Error: "Failed to establish authentication"
**Solution:** Ensure you have either:

1. **kubectl context access:**
   ```bash
   kubectl config current-context
   kubectl get nodes
   ```

2. **Service account token file:**
   ```bash
   # Generate token if missing
   ./scripts/cluster-config.sh
   ```

### Error: "Service account token found but doesn't have required permissions"
**Solution:** The `backstage-k8s-sa` service account needs cluster-admin permissions:

```bash
# Verify ClusterRoleBinding exists
kubectl get clusterrolebinding backstage-k8s-sa-binding

# If missing, recreate it
kubectl create clusterrolebinding backstage-k8s-sa-binding \
  --clusterrole=cluster-admin \
  --serviceaccount=default:backstage-k8s-sa
```

### Error: "Could not determine API server URL from kubectl config"
**Solution:** Check your kubectl configuration:

```bash
# View current context
kubectl config view --minify

# Ensure cluster server is set
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'
```

## Security Considerations

### Service Account Token Storage
The `backstage-k8s-sa-token.local.txt` file contains a powerful credential:
- ✅ **DO:** Keep it in `.gitignore` (already configured)
- ✅ **DO:** Restrict file permissions: `chmod 600 backstage-k8s-sa-token.local.txt`
- ✅ **DO:** Store securely, treat like a root password
- ❌ **DON'T:** Commit to version control
- ❌ **DON'T:** Share via insecure channels
- ❌ **DON'T:** Use in automated systems without additional security

### Recovery Script Permissions
The script requires cluster-admin level permissions to recreate ClusterRoleBindings:
- Only run when necessary
- Review the ClusterRoleBinding manifest before confirming
- Consider using fine-grained RBAC for day-to-day operations

## Related Documentation

- [Kubernetes RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [cluster-config.sh](../scripts/cluster-config.sh) - Initial cluster configuration
- [cluster-setup.sh](../scripts/cluster-setup.sh) - Cluster setup script

## Backup Strategy

Before removing the `cloudspace-admin-role` ClusterRoleBinding:

```bash
# 1. Export current binding as backup
kubectl get clusterrolebinding cloudspace-admin-role -o yaml > rbac-backup-$(date +%Y%m%d).yaml

# 2. Verify service account access works
kubectl --token="$(cat backstage-k8s-sa-token.local.txt)" \
  --server="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')" \
  --insecure-skip-tls-verify \
  get nodes

# 3. Test recovery script
./scripts/recover-rbac.sh

# 4. Only then proceed with RBAC changes
kubectl delete clusterrolebinding cloudspace-admin-role
```

## Next Steps

After successful recovery:

1. **Verify access:**
   ```bash
   kubectl auth can-i '*' '*'  # Should return 'yes'
   ```

2. **Implement fine-grained RBAC:**
   - Create namespace-specific RoleBindings
   - Use least-privilege principle
   - Document new RBAC structure

3. **Test new RBAC:**
   - Ensure all necessary operations work
   - Keep recovery script ready as fallback
   - Monitor for permission errors

4. **Update documentation:**
   - Document new RBAC structure
   - Update team on access changes
   - Schedule RBAC review
