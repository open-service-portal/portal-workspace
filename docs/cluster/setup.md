# Kubernetes Cluster Setup

This guide walks through setting up any Kubernetes cluster (local or cloud) with Crossplane and Flux for the Open Service Portal platform.

## Prerequisites

- **Kubernetes cluster** - Any Kubernetes cluster:
  - Local: Rancher Desktop, Kind, Docker Desktop, Minikube
  - Cloud: EKS, GKE, AKS, or any managed Kubernetes service
- **kubectl** - Configured to access your cluster
- **Helm** - For installing Crossplane
- **yq** - For YAML manipulation

## Install Prerequisites

```bash
# macOS (using Homebrew)
brew install kubectl helm yq

# Linux
# Install kubectl: https://kubernetes.io/docs/tasks/tools/
# Install helm: https://helm.sh/docs/intro/install/
# Install yq: https://github.com/mikefarah/yq

# Verify all tools are installed
kubectl version --client
helm version
yq --version
```

## Automated Setup

We provide a script that automates the entire setup process:

```bash
# Run from the portal-workspace directory
./scripts/setup-cluster.sh
```

After setup, configure your environment using the appropriate config script:
- For local development: `./scripts/config-local.sh`
- For OpenPortal production: `./scripts/config-openportal.sh`

See [Cluster Configuration](./configuration.md) for details on environment-specific configuration.

This script will:
1. Verify all required tools are installed
2. Install NGINX Ingress Controller
3. Install Flux for GitOps
4. Configure Flux to watch the Crossplane template catalog
5. Install Crossplane v2.0.0
6. Install provider-kubernetes
7. Install Crossplane composition functions (go-templating, patch-and-transform, auto-ready, environment-configs)
8. Install platform-wide environment configurations
9. Create a service account for Backstage
10. Automatically update `app-portal/app-config.local.yaml` with cluster credentials (if present)

The script works with any Kubernetes cluster and uses manifests from `scripts/cluster-manifests/`.

**Note**: The setup script installs everything with local development defaults (mock DNS, localhost domain). For production environments, you'll need to run the appropriate configuration script afterward - see [Cluster Configuration](./configuration.md).

## Manual Setup

If you prefer to set up manually:

### 1. Install Crossplane

```bash
# Add Helm repository
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update

# Install Crossplane
helm install crossplane \
  --namespace crossplane-system \
  --create-namespace \
  --version 2.0.0 \
  crossplane-stable/crossplane \
  --wait

# Verify installation
kubectl get pods -n crossplane-system
```

### 2. Install provider-kubernetes

```bash
# Apply provider manifest
kubectl apply -f scripts/cluster-manifests/provider-kubernetes.yaml

# Wait for provider to be healthy
kubectl wait --for=condition=Healthy provider/provider-kubernetes --timeout=300s

# Apply provider config
kubectl apply -f scripts/cluster-manifests/provider-config.yaml
```

### 3. Install Crossplane Functions

```bash
# Apply functions manifest
kubectl apply -f scripts/cluster-manifests/crossplane-functions.yaml

# Verify functions are installed
kubectl get functions
```

### 4. Install Environment Configurations

```bash
# Apply platform-wide environment configs
kubectl apply -f scripts/cluster-manifests/environment-configs.yaml

# Verify environment configs
kubectl get environmentconfig
```

### 5. Install Flux (Optional, for GitOps)

```bash
# Install Flux
kubectl apply -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml

# Configure Flux to watch catalog
kubectl apply -f scripts/cluster-manifests/flux-catalog.yaml

# Verify installation
kubectl get pods -n flux-system
```

### 6. Create Service Account for Backstage

```bash
# Create service account
kubectl create serviceaccount backstage-k8s-sa -n default

# Create cluster role binding
kubectl create clusterrolebinding backstage-k8s-sa-binding \
  --clusterrole=cluster-admin \
  --serviceaccount=default:backstage-k8s-sa

# Generate token (valid for 10 years)
export K8S_SERVICE_ACCOUNT_TOKEN=$(kubectl create token backstage-k8s-sa -n default --duration=87600h)

# Display token
echo "Service Account Token: $K8S_SERVICE_ACCOUNT_TOKEN"
```

## Backstage Configuration

### Automatic Configuration

If you have the `app-portal` directory in your workspace, the setup script will automatically update `app-portal/app-config.local.yaml` with:
- Cluster URL
- Cluster name  
- Service account token

### Manual Configuration

If configuring manually, create or update `app-config.local.yaml`:

```yaml
kubernetes:
  serviceLocatorMethod:
    type: 'multiTenant'
  clusterLocatorMethods:
    - type: 'config'
      clusters:
        - url: <YOUR_CLUSTER_URL>  # Get from: kubectl cluster-info
          name: local-cluster
          authProvider: 'serviceAccount'
          skipTLSVerify: true  # For local development only
          serviceAccountToken: <YOUR_SERVICE_ACCOUNT_TOKEN>  # From setup script output
```

## Verification

### Test Crossplane Functions and Environment Configs

```bash
# Check installed functions
kubectl get functions

# Check environment configs
kubectl get environmentconfig
kubectl describe environmentconfig dns-config
```

### Test Crossplane

```bash
# Create test namespace
kubectl create namespace crossplane-test

# Create a ConfigMap via Crossplane
cat <<EOF | kubectl apply -f -
apiVersion: kubernetes.crossplane.io/v1alpha1
kind: Object
metadata:
  name: smoke-test-configmap
spec:
  forProvider:
    manifest:
      apiVersion: v1
      kind: ConfigMap
      metadata:
        name: crossplane-smoke-test
        namespace: crossplane-test
      data:
        message: "Crossplane is working!"
  providerConfigRef:
    name: kubernetes-provider
EOF

# Verify ConfigMap was created
kubectl get configmap crossplane-smoke-test -n crossplane-test
```

### Test Flux (if installed)

```bash
# Check Flux components
flux check

# View Flux resources
kubectl get all -n flux-system
```

## Kubeconfig Management

### Export Kubeconfig

```bash
# Export current kubeconfig to file
kubectl config view --raw > kubeconfig.yaml

# Use exported kubeconfig
export KUBECONFIG=/path/to/kubeconfig.yaml
```

### Extract Components

```bash
# Get API server URL
kubectl config view -o jsonpath='{.clusters[0].cluster.server}'

# Get CA certificate (base64 encoded)
kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}'

# Get current context
kubectl config current-context
```

## Troubleshooting

### Crossplane Issues

```bash
# Check pod status
kubectl get pods -n crossplane-system

# Check logs
kubectl logs -n crossplane-system -l app=crossplane

# Check provider status
kubectl get providers
kubectl describe provider provider-kubernetes
```

### Flux Issues

```bash
# Check Flux status
flux check

# View logs
flux logs --all-namespaces

# Check events
kubectl get events -n flux-system --sort-by='.lastTimestamp'
```

### Connection Issues

```bash
# Verify cluster access
kubectl cluster-info
kubectl get nodes

# Check context
kubectl config get-contexts
kubectl config current-context
```

## Resource Requirements

| Component | Memory | CPU | Notes |
|-----------|--------|-----|-------|
| Kubernetes | 2GB | 1 core | Minimum for control plane |
| Crossplane | 512MB | 0.5 core | Core functionality |
| Provider-kubernetes | 256MB | 0.25 core | Per provider |
| Flux | 512MB | 0.5 core | If using GitOps |
| **Total Minimum** | **4GB** | **2 cores** | For basic setup |
| **Recommended** | **8GB** | **4 cores** | For comfortable development |

## Next Steps

1. Configure your environment - see [Cluster Configuration](./configuration.md)
2. Create Crossplane templates using namespaced XRs (Crossplane v2)
3. Push templates to GitHub for Flux to discover
4. Configure monitoring with Prometheus
5. Integrate with your Backstage plugins
6. Explore GitOps workflows with Flux and the catalog pattern

## Additional Resources

- [Crossplane Documentation](https://docs.crossplane.io/)
- [Flux Documentation](https://fluxcd.io/docs/)
- [Backstage Kubernetes Plugin](https://backstage.io/docs/features/kubernetes/)
- [Template Catalog Setup](./catalog-setup.md)