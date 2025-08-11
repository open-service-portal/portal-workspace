# Rancher K8s Setup Manifests

This directory contains Kubernetes manifests used by the `setup-rancher-k8s.sh` script.

## Files

### provider-kubernetes.yaml
Installs the Crossplane Kubernetes provider which allows Crossplane to manage Kubernetes resources.

### provider-config.yaml
Configures the Kubernetes provider to use injected identity for authentication.

## Usage

These manifests are automatically applied by the setup script. You can also apply them manually:

```bash
# Install provider
kubectl apply -f provider-kubernetes.yaml

# Wait for provider to be ready
kubectl wait --for=condition=Healthy provider/provider-kubernetes --timeout=300s

# Configure provider
kubectl apply -f provider-config.yaml
```

## Testing

For smoke tests and example Crossplane resources, see:
- `../../examples/crossplane-rancher-examples/` - Contains smoke tests and Backstage-specific examples