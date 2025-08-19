# Provider-Helm Usage Guide

## Overview
Provider-helm enables Crossplane to deploy Helm charts as managed resources. Think of it as the **supplier** that provides pre-packaged ingredients (Helm charts) like Bitnami PostgreSQL, Redis, or any other Helm chart.

## Installation
Provider-helm is automatically installed by our setup script:
```bash
./scripts/setup-cluster.sh
```

## Basic Usage Pattern

### 1. Create a Release Resource
```yaml
apiVersion: helm.crossplane.io/v1beta1
kind: Release
metadata:
  name: my-postgresql
spec:
  forProvider:
    chart:
      name: postgresql
      repository: https://charts.bitnami.com/bitnami
      version: "13.2.24"
    namespace: databases
    values:
      auth:
        database: myapp
        username: myuser
  providerConfigRef:
    name: helm-provider
```

### 2. Use in a Composition
```yaml
apiVersion: apiextensions.crossplane.io/v2
kind: Composition
metadata:
  name: database-helm
spec:
  compositeTypeRef:
    apiVersion: platform.io/v1alpha1
    kind: XDatabase
  mode: Pipeline
  pipeline:
    - step: deploy-postgresql
      functionRef:
        name: function-patch-and-transform
      input:
        apiVersion: pt.crossplane.io/v1
        kind: Resources
        resources:
          - name: postgresql
            base:
              apiVersion: helm.crossplane.io/v1beta1
              kind: Release
              spec:
                forProvider:
                  chart:
                    name: postgresql
                    repository: https://charts.bitnami.com/bitnami
                  namespace: databases
                providerConfigRef:
                  name: helm-provider
            patches:
              - type: FromCompositeFieldPath
                fromFieldPath: spec.size
                toFieldPath: spec.forProvider.values.primary.persistence.size
```

## Common Helm Charts

### Bitnami PostgreSQL
```yaml
chart:
  name: postgresql
  repository: https://charts.bitnami.com/bitnami
```

### Redis
```yaml
chart:
  name: redis
  repository: https://charts.bitnami.com/bitnami
```

### NGINX
```yaml
chart:
  name: nginx
  repository: https://charts.bitnami.com/bitnami
```

## Testing Provider-Helm

### Simple Test Deployment
```bash
# Create a test namespace
kubectl create namespace helm-test

# Deploy a simple nginx chart
kubectl apply -f - <<EOF
apiVersion: helm.crossplane.io/v1beta1
kind: Release
metadata:
  name: test-nginx
spec:
  forProvider:
    chart:
      name: nginx
      repository: https://charts.bitnami.com/bitnami
      version: "15.14.0"
    namespace: helm-test
    values:
      service:
        type: ClusterIP
  providerConfigRef:
    name: helm-provider
EOF

# Check the release
kubectl get releases.helm.crossplane.io
kubectl get pods -n helm-test

# Clean up
kubectl delete release test-nginx
kubectl delete namespace helm-test
```

## Troubleshooting

### Check Provider Status
```bash
kubectl get providers.pkg.crossplane.io provider-helm
kubectl describe providerconfig.helm.crossplane.io helm-provider
```

### View Provider Logs
```bash
kubectl logs -l pkg.crossplane.io/provider=provider-helm -n crossplane-system
```

### Common Issues

1. **Release Stuck in Creating**: Check namespace exists and chart values are valid
2. **Authentication Errors**: Verify ProviderConfig uses correct credentials
3. **Chart Not Found**: Ensure repository URL is correct and accessible

## Restaurant Analogy
- **Supplier** = Provider-helm
- **Pre-packaged Ingredients** = Helm charts (PostgreSQL, Redis, etc.)
- **Delivery Instructions** = Release resource with values
- **Kitchen** = Composition that uses the Release
- **Final Dish** = Deployed application with all dependencies