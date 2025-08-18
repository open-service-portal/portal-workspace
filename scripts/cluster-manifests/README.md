# Cluster Setup Manifests

This directory contains Kubernetes manifests used by the `setup-cluster.sh` script for setting up Crossplane and other cluster components.

## Files

### provider-kubernetes.yaml
Installs the Crossplane Kubernetes provider which allows Crossplane to manage Kubernetes resources.
- Version: v0.14.0
- Provider: crossplane-contrib/provider-kubernetes

### provider-config.yaml
Configures the Kubernetes provider to use injected identity for authentication.

### crossplane-functions.yaml
Installs common Crossplane composition functions for advanced compositions:
- function-go-templating: Go templating for flexible resource generation
- function-patch-and-transform: Traditional patching and transformation
- function-auto-ready: Automatically mark resources as ready
- function-environment-configs: Load shared environment configurations

### flux-catalog.yaml
Configures Flux to watch the catalog repository for Crossplane templates.

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

## Notes

- These manifests are required by `setup-cluster.sh`
- The script will fail if these files are not present
- Works with any Kubernetes cluster (Kind, Rancher Desktop, EKS, GKE, etc.)