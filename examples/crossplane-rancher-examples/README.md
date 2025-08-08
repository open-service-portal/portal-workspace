# Crossplane Examples for Rancher Desktop

This directory contains example Crossplane resources specifically tested with Rancher Desktop.

## Prerequisites

Ensure you have completed the Rancher Desktop setup:
```bash
# Run the setup script from the workspace root
../../scripts/setup-rancher-k8s.sh
```

## Files

### Core Setup
- **provider-kubernetes.yaml** - Installs and configures the Kubernetes provider for Crossplane
- **smoke-test-configmap.yaml** - Simple smoke test to verify Crossplane installation

### Backstage Examples
- **backstage-namespace.yaml** - Creates a dedicated namespace for Backstage
- **postgres-secret.yaml** - Creates database credentials for Backstage (demo only)
- **service-configmap.yaml** - Service catalog configuration for Backstage

## Usage

### 1. Verify Crossplane is Running

```bash
# Check Crossplane pods
kubectl get pods -n crossplane-system

# All pods should be in "Running" state
```

### 2. Install Provider (if not already installed)

```bash
kubectl apply -f provider-kubernetes.yaml

# Wait for provider to be healthy
kubectl wait --for=condition=Healthy provider/provider-kubernetes --timeout=300s

# Verify provider status
kubectl get providers
```

### 3. Run Smoke Test

```bash
# Create test namespace
kubectl create namespace crossplane-test --dry-run=client -o yaml | kubectl apply -f -

# Apply the smoke test
kubectl apply -f smoke-test-configmap.yaml

# Verify the ConfigMap was created
kubectl get configmap -n crossplane-test crossplane-smoke-test

# Check the content
kubectl describe configmap -n crossplane-test crossplane-smoke-test
```

### 4. Deploy Backstage Resources (Optional)

```bash
# Create Backstage namespace
kubectl apply -f backstage-namespace.yaml

# Wait for namespace to be ready
sleep 5

# Create secrets and configmaps
kubectl apply -f postgres-secret.yaml
kubectl apply -f service-configmap.yaml

# Verify resources
kubectl get objects
kubectl get namespace backstage
kubectl get secret,configmap -n backstage
```

### 5. Cleanup

```bash
# Delete the smoke test resources
kubectl delete -f smoke-test-configmap.yaml

# Delete Backstage resources if created
kubectl delete -f service-configmap.yaml
kubectl delete -f postgres-secret.yaml
kubectl delete -f backstage-namespace.yaml

# Delete the test namespace
kubectl delete namespace crossplane-test
```

## Advanced Examples

### Creating a Deployment via Crossplane

```yaml
apiVersion: kubernetes.crossplane.io/v1alpha1
kind: Object
metadata:
  name: nginx-deployment
spec:
  forProvider:
    manifest:
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: nginx
        namespace: default
      spec:
        replicas: 2
        selector:
          matchLabels:
            app: nginx
        template:
          metadata:
            labels:
              app: nginx
          spec:
            containers:
            - name: nginx
              image: nginx:alpine
              ports:
              - containerPort: 80
  providerConfigRef:
    name: kubernetes-provider
```

### Creating a Service via Crossplane

```yaml
apiVersion: kubernetes.crossplane.io/v1alpha1
kind: Object
metadata:
  name: nginx-service
spec:
  forProvider:
    manifest:
      apiVersion: v1
      kind: Service
      metadata:
        name: nginx
        namespace: default
      spec:
        selector:
          app: nginx
        ports:
        - port: 80
          targetPort: 80
        type: ClusterIP
  providerConfigRef:
    name: kubernetes-provider
```

## Troubleshooting

### Provider Not Healthy

```bash
# Check provider pods
kubectl get pods -n crossplane-system -l pkg.crossplane.io/provider=provider-kubernetes

# Check provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-kubernetes
```

### Object Not Created

```bash
# Check the Object status
kubectl describe object smoke-test-configmap

# Check Crossplane logs
kubectl logs -n crossplane-system -l app=crossplane
```

### Rancher Desktop Specific Issues

1. **Context Issues**: Ensure you're using the correct context
   ```bash
   kubectl config current-context
   # Should show: rancher-desktop
   ```

2. **Permission Issues**: The provider uses InjectedIdentity which requires proper RBAC
   ```bash
   # Check service account permissions
   kubectl auth can-i create configmaps --as=system:serviceaccount:crossplane-system:crossplane
   ```

## Next Steps

1. Explore the main Crossplane examples in the sibling `crossplane-examples/` directory
2. Create custom Compositions for your applications
3. Install additional providers (AWS, Azure, GCP, etc.)
4. Set up continuous deployment with GitOps