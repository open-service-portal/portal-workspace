# Local Kubernetes Setup for Backstage

This guide walks through setting up a local Kubernetes environment with Crossplane and Flux for Backstage development.

## Prerequisites

- **Kubernetes cluster** - Any local Kubernetes cluster (Rancher Desktop, Kind, Docker Desktop, Minikube, etc.)
- **kubectl** - Configured to access your cluster
- **Helm** - For installing Crossplane

## Verify Prerequisites

```bash
# Check kubectl access
kubectl cluster-info
kubectl get nodes

# Check Helm
helm version

# Wait for cluster to be ready
kubectl wait --for=condition=Ready nodes --all --timeout=300s
```

## Automated Setup

We provide a script that automates the entire setup process:

```bash
# Run from the portal-workspace directory
./scripts/setup-cluster.sh
```

This script will:
1. Verify kubectl access to your cluster
2. Install Flux for GitOps
3. Install Crossplane v1.17.0
4. Install provider-kubernetes
5. Configure SOPS for secret management
6. Create a service account for Backstage

The script works with any Kubernetes cluster and uses manifests from `scripts/cluster-manifests/`.

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
  --version 1.17.0 \
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

### 3. Install Flux (Optional, for GitOps)

```bash
# Check prerequisites
flux check --pre

# Install Flux
flux install

# Verify installation
kubectl get pods -n flux-system
```

### 4. Create Service Account for Backstage

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

### 1. Configure Kubernetes Plugin

Add to your `app-config.local.yaml`:

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
          serviceAccountToken: ${K8S_SERVICE_ACCOUNT_TOKEN}
```

### 2. Set Environment Variable

```bash
# Add to your .envrc file
export K8S_SERVICE_ACCOUNT_TOKEN='<your-token-here>'

# If using direnv
direnv allow
```

## Verification

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

1. Install additional Crossplane providers as needed
2. Set up SOPS for secret management (see `docs/sops-secret-management.md`)
3. Configure monitoring with Prometheus
4. Integrate with your Backstage plugins
5. Explore GitOps workflows with Flux

## Additional Resources

- [Crossplane Documentation](https://docs.crossplane.io/)
- [Flux Documentation](https://fluxcd.io/docs/)
- [Backstage Kubernetes Plugin](https://backstage.io/docs/features/kubernetes/)
- [SOPS Secret Management](./sops-secret-management.md)