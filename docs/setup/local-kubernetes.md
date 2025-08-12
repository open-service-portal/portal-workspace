# Local Kubernetes Setup Guide

This guide walks you through setting up a complete local Kubernetes environment for the Open Service Portal, including Backstage, Crossplane, and Flux GitOps.

## Prerequisites

- macOS, Linux, or Windows with WSL2
- Homebrew (macOS) or appropriate package manager
- GitHub account
- At least 8GB RAM available for Kubernetes

## Quick Start

Run the automated setup script:

```bash
./scripts/setup-rancher-k8s.sh
```

This zero-config script will set up your entire local environment in minutes.

## What Gets Installed

### 1. Rancher Desktop
- **Purpose**: Provides local Kubernetes cluster (K3s)
- **Alternative to**: Docker Desktop (no licensing restrictions)
- **Access**: `kubectl` configured automatically

### 2. Crossplane v1.17
- **Purpose**: Infrastructure as Code using Kubernetes CRDs
- **Provider**: kubernetes-provider for managing K8s resources
- **Use case**: Creating ConfigMaps, Deployments via Backstage templates

### 3. NGINX Ingress Controller
- **Purpose**: Routes traffic to services in the cluster
- **Access**: 
  - HTTP: http://localhost:30080
  - HTTPS: https://localhost:30443

### 4. Backstage Service Account
- **Purpose**: Allows Backstage to interact with Kubernetes cluster
- **Token type**: Permanent (never expires)
- **Permissions**: cluster-admin (full access)

### 5. Flux GitOps (Optional)
- **Purpose**: Automated deployment from Git repositories
- **Auto-discovery**: Monitors repos with `flux-managed` label
- **Skipped if**: No GitHub token available

## GitHub Token Configuration

The setup script automatically detects GitHub tokens from multiple sources (in order):

1. **Environment Variable**
   ```bash
   export GITHUB_TOKEN=ghp_your_token_here
   ```

2. **Flux-specific Variable**
   ```bash
   export FLUX_GITHUB_TOKEN=ghp_your_token_here
   ```

3. **Local Configuration File**
   ```bash
   cp .envrc.example .envrc
   # Edit .envrc and add your token
   ```

4. **GitHub CLI**
   ```bash
   gh auth login
   # The script will use the CLI token automatically
   ```

### Creating a GitHub Token

1. Go to https://github.com/settings/tokens/new
2. Give it a descriptive name (e.g., "Flux GitOps")
3. Select scopes:
   - `repo` (all permissions under repo)
4. Click "Generate token"
5. Copy the token (starts with `ghp_`)

## Manual Installation Steps

If you prefer to install components manually:

### Install Rancher Desktop

```bash
# macOS
brew install --cask rancher

# Linux - Download from https://rancherdesktop.io/
# Windows - Use WSL2 and download from website
```

### Install Flux CLI

```bash
curl -s https://fluxcd.io/install.sh | sh
```

### Bootstrap Flux to Your Account

```bash
flux bootstrap github \
  --owner=YOUR_GITHUB_USERNAME \
  --repository=flux-system \
  --branch=main \
  --path=clusters/local \
  --personal
```

## Verification

After setup, verify all components:

```bash
# Check Kubernetes cluster
kubectl get nodes

# Check Crossplane
kubectl get providers
kubectl get pods -n crossplane-system

# Check Ingress
kubectl get pods -n ingress-nginx

# Check Flux (if installed)
kubectl get pods -n flux-system
flux get sources git
```

## Backstage Configuration

Add the generated service account token to your Backstage configuration:

1. The token is displayed at the end of the setup script
2. Add to `app-portal/app-config.local.yaml`:

```yaml
kubernetes:
  serviceLocatorMethod:
    type: 'multiTenant'
  clusterLocatorMethods:
    - type: 'config'
      clusters:
        - url: https://127.0.0.1:6443
          name: rancher-desktop
          authProvider: 'serviceAccount'
          skipTLSVerify: true
          serviceAccountToken: ${K8S_SERVICE_ACCOUNT_TOKEN}
```

3. Export the token in your shell or `.envrc`:
```bash
export K8S_SERVICE_ACCOUNT_TOKEN='<token-from-setup>'
```

## Troubleshooting

### Rancher Desktop not found
- Ensure Rancher Desktop is installed
- On macOS, check if `~/.rd/bin` is in your PATH

### Flux bootstrap fails
- Verify your GitHub token has `repo` scope
- Check token has access to create repositories
- For org repos, ensure you have appropriate permissions

### Crossplane provider unhealthy
- Wait a few minutes for provider to initialize
- Check logs: `kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-kubernetes`

### Service account token issues
- Token is stored in secret: `backstage-k8s-sa-token`
- Retrieve: `kubectl get secret backstage-k8s-sa-token -n default -o jsonpath='{.data.token}' | base64 -d`

## Next Steps

1. Start Backstage: `cd app-portal && yarn dev`
2. Create your first template repository
3. Deploy services using Backstage templates
4. Monitor deployments with Flux

## Resources

- [Rancher Desktop Documentation](https://docs.rancherdesktop.io/)
- [Crossplane Documentation](https://docs.crossplane.io/)
- [Flux Documentation](https://fluxcd.io/docs/)
- [Backstage Documentation](https://backstage.io/docs/)