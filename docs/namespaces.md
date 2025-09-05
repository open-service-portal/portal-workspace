# Namespace Architecture

This document describes the namespace strategy used in the Open Service Portal platform, particularly for Crossplane resources and GitOps workflows.

## Overview

The platform uses a hierarchical namespace structure to separate infrastructure resources from application workloads, providing clear boundaries for multi-tenancy and resource management.

## Namespace Types

### 1. System Namespace (`system`)

**Purpose**: Dedicated namespace for infrastructure-level Crossplane Composite Resources (XRs)

**Created by**: `scripts/cluster-config.sh`

**Label**: `purpose=infrastructure-xrs`

**Contains**:
- ManagedNamespace XRs (creates other namespaces)
- Cluster-wide infrastructure XRs
- Resources that affect multiple namespaces

**Example**:
```yaml
apiVersion: openportal.dev/v1alpha1
kind: ManagedNamespace
metadata:
  name: team-frontend
  namespace: system  # Always in system namespace
spec:
  name: team-frontend
```

### 2. Platform Namespaces

These namespaces contain platform components:

- **`crossplane-system`**: Crossplane control plane and providers
- **`flux-system`**: Flux GitOps controllers
- **`external-dns`**: DNS management via External-DNS
- **`ingress-nginx`**: Ingress controller
- **`default`**: Backstage service account and basic resources

### 3. Application Namespaces

Created dynamically via ManagedNamespace XRs, these contain:
- Application deployments
- Service-specific XRs
- ConfigMaps and Secrets
- Application-level resources

**Naming Convention**: 
- Team-based: `team-<name>` (e.g., `team-frontend`, `team-backend`)
- Environment-based: `<app>-<env>` (e.g., `api-staging`, `api-production`)
- Service-based: `svc-<name>` (e.g., `svc-auth`, `svc-payments`)

### 4. Demo Namespace (`demo`)

**Purpose**: Testing and demonstration of platform capabilities

**Created by**: `scripts/cluster-config.sh`

**Contains**:
- Example applications (WhoAmI service)
- Test XRs for validation
- Development experiments

## Crossplane v2 Architecture

### Why Namespaced XRs?

In Crossplane v2, we moved from cluster-scoped to namespaced XRs for several reasons:

1. **API Server Cache Consistency**: Eliminates cache inconsistencies between XRD definitions and API server expectations
2. **Better RBAC**: Namespace-scoped resources allow finer-grained access control
3. **Multi-tenancy**: Teams can manage their own XRs without cluster-wide permissions
4. **GitOps Compatibility**: Flux handles namespaced resources more reliably with server-side apply

### XR Placement Strategy

```
catalog-orders/
├── <cluster>/
│   ├── system/                    # Infrastructure XRs
│   │   └── ManagedNamespace/       # Namespace management
│   │       └── *.yaml
│   └── <namespace>/                # Application XRs
│       └── <Kind>/
│           └── *.yaml
```

**Rules**:
1. Infrastructure XRs → `system` namespace
2. Application XRs → Their respective application namespace
3. No XRs in platform namespaces (crossplane-system, flux-system, etc.)

## ManagedNamespace Pattern

The ManagedNamespace XRD provides controlled namespace creation with:

### Features
- Automatic namespace creation
- Standardized labels and annotations
- Network policies (optional)
- Resource quotas (optional)
- RBAC setup (optional)

### Usage
```yaml
apiVersion: openportal.dev/v1alpha1
kind: ManagedNamespace
metadata:
  name: team-frontend
  namespace: system  # Always in system namespace
spec:
  name: team-frontend
  labels:
    team: frontend
    environment: development
  resourceQuota:
    enabled: true
    limits:
      cpu: "10"
      memory: "20Gi"
```

### Composition Details
The ManagedNamespace composition creates:
1. The actual Kubernetes namespace
2. Default network policies (if configured)
3. Resource quotas (if specified)
4. RBAC roles and bindings (if needed)

## GitOps Workflow

### Flux Configuration

Flux watches two repositories with different namespace strategies:

1. **catalog/** - Template definitions
   ```yaml
   apiVersion: kustomize.toolkit.fluxcd.io/v1
   kind: Kustomization
   metadata:
     name: catalog
     namespace: flux-system
   spec:
     path: ./templates
     targetNamespace: crossplane-system  # Templates go to Crossplane
   ```

2. **catalog-orders/** - XR instances
   ```yaml
   apiVersion: kustomize.toolkit.fluxcd.io/v1
   kind: Kustomization
   metadata:
     name: catalog-orders
     namespace: flux-system
   spec:
     path: ./<cluster>
     prune: true  # Clean up removed XRs
     # No targetNamespace - uses namespace from each XR's metadata
   ```

### Server-Side Apply

Flux uses server-side apply for XRs, which requires:
- Correct namespace in metadata
- Proper scope in XRD (Namespaced vs Cluster)
- Valid API group and version

## Best Practices

### 1. Namespace Naming
- Use descriptive, hierarchical names
- Include purpose in the name (team-, svc-, env-)
- Avoid generic names like "test" or "temp"

### 2. Resource Isolation
- Keep platform components in dedicated namespaces
- Don't mix infrastructure and application resources
- Use network policies for inter-namespace communication

### 3. Label Standards
All namespaces should have:
```yaml
labels:
  managed-by: crossplane
  purpose: <infrastructure|application|demo>
  team: <team-name>
  environment: <dev|staging|prod>
```

### 4. Quota Management
Set appropriate resource quotas:
- Development: Lower limits
- Staging: Production-like limits
- Production: Monitored limits with alerts

### 5. RBAC Strategy
- Platform team: Access to system and platform namespaces
- Development teams: Access to their team namespaces
- CI/CD: Limited access for deployments
- Backstage: Service account with XR creation permissions

## Migration Guide

### From Cluster-Scoped to Namespaced XRs

If you have existing cluster-scoped XRs:

1. **Backup existing XRs**:
   ```bash
   kubectl get managednamespaces.openportal.dev -o yaml > backup.yaml
   ```

2. **Delete old XRs**:
   ```bash
   kubectl delete managednamespaces.openportal.dev --all
   ```

3. **Update template to v2.1.0+**:
   ```yaml
   # catalog/templates/template-namespace.yaml
   spec:
     package: ghcr.io/open-service-portal/configuration-namespace:v2.1.0
   ```

4. **Recreate XRs in system namespace**:
   ```yaml
   apiVersion: openportal.dev/v1alpha1
   kind: ManagedNamespace
   metadata:
     name: my-namespace
     namespace: system  # Add namespace
   spec:
     name: my-namespace
   ```

## Troubleshooting

### Common Issues

1. **"namespace not specified" error from Flux**
   - Ensure XR has `namespace: system` in metadata
   - Verify XRD scope is `Namespaced`

2. **XR not created after Git push**
   - Check Flux logs: `kubectl logs -n flux-system deploy/kustomize-controller`
   - Verify path in Kustomization matches cluster name
   - Ensure proper directory structure in catalog-orders

3. **Cannot delete namespace**
   - Check for finalizers on the ManagedNamespace XR
   - Ensure all resources in namespace are deleted
   - Verify Crossplane provider has permissions

### Debugging Commands

```bash
# Check system namespace
kubectl get ns system -o yaml

# List all ManagedNamespace XRs
kubectl get managednamespaces.openportal.dev -n system

# Check Flux reconciliation
flux get kustomizations

# View Crossplane composition status
kubectl get compositions managednamespaces -o wide

# Check XRD scope
kubectl get xrd managednamespaces.openportal.dev -o jsonpath='{.spec.scope}'
```

## Future Enhancements

### Planned Features
1. **Namespace Templates**: Pre-configured namespace types (web-app, api-service, database)
2. **Automatic Cleanup**: TTL for demo/development namespaces
3. **Cost Attribution**: Namespace-level cost tracking
4. **Security Policies**: OPA/Gatekeeper policies per namespace type
5. **Observability**: Automatic Prometheus/Grafana dashboard creation

### Under Consideration
- Hierarchical namespaces (HNC) for sub-namespace management
- Virtual clusters (vcluster) for stronger isolation
- Namespace-as-a-Service API for self-service provisioning

## References

- [Kubernetes Namespaces Documentation](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)
- [Crossplane v2 Namespaced Resources](https://docs.crossplane.io/latest/concepts/composite-resources/#namespaced-composite-resources)
- [Flux Server-Side Apply](https://fluxcd.io/flux/components/kustomize/kustomizations/#server-side-apply)
- [ManagedNamespace Template Source](https://github.com/open-service-portal/template-namespace)