# Rancher K8s Setup Manifests

This directory contains Kubernetes manifests used by the `setup-rancher-k8s.sh` script.

## Files

### provider-kubernetes.yaml
Installs the Crossplane Kubernetes provider which allows Crossplane to manage Kubernetes resources.

### provider-config.yaml
Configures the Kubernetes provider to use injected identity for authentication.

### smoke-test-configmap.yaml
Creates a test ConfigMap via Crossplane to verify the installation is working correctly.
The `TIMESTAMP_PLACEHOLDER` is replaced with the actual timestamp during script execution.

## Usage

These manifests are automatically applied by the setup script. You can also apply them manually:

```bash
# Install provider
kubectl apply -f provider-kubernetes.yaml

# Wait for provider to be ready
kubectl wait --for=condition=Healthy provider/provider-kubernetes --timeout=300s

# Configure provider
kubectl apply -f provider-config.yaml

# Run smoke test (replace timestamp)
sed "s/TIMESTAMP_PLACEHOLDER/$(date -u +%Y-%m-%dT%H:%M:%SZ)/g" smoke-test-configmap.yaml | kubectl apply -f -
```