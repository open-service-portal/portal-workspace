# Namespace Management Options for Open Service Portal

## Current Situation

We discovered that Crossplane v2 has significant issues with cluster-scoped XRs (Composite Resources):
- kubectl API cannot properly handle cluster-scoped XRs 
- Crossplane cannot add finalizers to cluster-scoped XRs
- The composition cannot create resources because XR management is broken
- GitHub Issue #6736 confirms that changing XRD scope requires manual Crossplane restart

Since Kubernetes namespaces are inherently cluster-scoped resources, this creates a fundamental conflict when trying to manage them through Crossplane XRs.

## Option 1: Provider-Kubernetes Object Resources (Current Attempt)

We tried using provider-kubernetes Object resources to create namespaces indirectly. The composition creates an Object resource that then creates the namespace. However, this approach still suffers from the cluster-scoped XR API issues.

**Status:** Not working due to fundamental cluster-scoped XR limitations

## Option 2: External Namespace Management (Recommended)

### Overview

Remove namespace creation from Crossplane management entirely and handle it through simpler, more reliable mechanisms. Namespaces are fundamental Kubernetes resources that don't need the complexity of Crossplane's abstraction layer.

### Detailed Implementation

#### 1. Namespace Creation via Backstage

**Approach:** When Backstage scaffolds a new service that needs a namespace, it creates the namespace directly.

**Implementation:**
```yaml
# In Backstage template (template.yaml)
steps:
  - id: create-namespace
    name: Create Kubernetes Namespace
    action: kubernetes:apply
    input:
      manifest: |
        apiVersion: v1
        kind: Namespace
        metadata:
          name: ${{ parameters.namespace }}
          labels:
            created-by: backstage
            team: ${{ parameters.team }}
            environment: ${{ parameters.environment }}
```

**Benefits:**
- Direct creation, no intermediate layers
- Immediate feedback in Backstage UI
- Simple and reliable

#### 2. Namespace Creation via Flux GitOps

**Approach:** Store namespace manifests in a Git repository that Flux monitors.

**Implementation:**

Create a dedicated namespace management structure:
```
catalog-namespaces/
├── rancher-desktop/
│   ├── demo.yaml
│   ├── production.yaml
│   └── staging.yaml
└── openportal/
    ├── production.yaml
    └── staging.yaml
```

Example namespace manifest:
```yaml
# catalog-namespaces/rancher-desktop/demo.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: demo
  labels:
    managed-by: flux
    created-by: backstage
    team: platform-team
    environment: dev
  annotations:
    description: "Demo namespace for testing"
```

Flux Kustomization to watch this repository:
```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: catalog-namespaces
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: catalog-namespaces
  path: "./${CLUSTER_NAME}"
  prune: true
```

**Benefits:**
- GitOps workflow for namespace management
- Audit trail through Git commits
- Easy rollback if needed
- Works with existing Flux infrastructure

#### 3. Pre-deployment Script Approach

**Approach:** Create namespaces as part of the deployment pipeline.

**Implementation:**

Add to deployment scripts:
```bash
#!/bin/bash
# ensure-namespace.sh

NAMESPACE=$1
TEAM=${2:-platform-team}
ENVIRONMENT=${3:-dev}

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
  echo "Creating namespace: $NAMESPACE"
  kubectl create namespace "$NAMESPACE"
  kubectl label namespace "$NAMESPACE" \
    team="$TEAM" \
    environment="$ENVIRONMENT" \
    managed-by="deployment-script"
fi
```

Use in catalog-orders workflow:
```yaml
# When applying XRs that need namespaces
- name: ensure-namespace
  run: ./scripts/ensure-namespace.sh demo platform-team dev
- name: apply-xr
  run: kubectl apply -f catalog-orders/rancher-desktop/Namespace/demo-app.yaml
```

**Benefits:**
- Simple bash script
- Can be integrated into CI/CD pipelines
- Ensures namespace exists before XR creation

#### 4. Namespace Operator Approach

**Approach:** Use a lightweight operator that watches for namespace requirements.

**Options:**
- Hierarchical Namespace Controller (HNC)
- Namespace Configuration Operator
- Custom simple operator

**Example with HNC:**
```yaml
apiVersion: hnc.x-k8s.io/v1alpha2
kind: HierarchicalConfiguration
metadata:
  name: platform
  namespace: platform-root
spec:
  children:
  - demo
  - staging
  - production
```

**Benefits:**
- Automated namespace management
- Hierarchy and inheritance support
- Policy enforcement

### Migration Path from Current Setup

1. **Keep the namespace template in place** (but marked as deprecated)
2. **Document that it's not currently working** due to Crossplane limitations
3. **Implement one of the alternatives above**
4. **Update Backstage templates** to use the new approach
5. **Migrate existing namespaces** if needed

### Recommended Solution: Flux GitOps

For Open Service Portal, the **Flux GitOps approach** is recommended because:

1. **Already using Flux** - No new tools needed
2. **GitOps alignment** - Matches existing workflow
3. **Simple and reliable** - Just YAML files in Git
4. **Auditable** - All changes tracked in Git
5. **Cluster-specific** - Can have different namespaces per cluster

### Implementation Steps

1. Create `catalog-namespaces` repository
2. Add namespace YAML files
3. Configure Flux to watch the repository
4. Update Backstage templates to commit namespace files
5. Document the process

### Example Backstage Integration

When Backstage creates a new service:
1. Scaffolder creates namespace YAML in catalog-namespaces repo
2. Commits and pushes to Git
3. Flux automatically creates the namespace
4. Service XRs can then be created in catalog-orders

### Handling Dependencies

For XRs that need namespaces:
- Document the required namespace in the XR comments
- Backstage ensures namespace file exists before creating XR
- Flux creates namespace before XR is applied

### Benefits of External Management

1. **Reliability** - No complex Crossplane XR issues
2. **Simplicity** - Namespaces are just Kubernetes resources
3. **Speed** - Direct creation, no composition processing
4. **Debugging** - Standard kubectl commands work
5. **Flexibility** - Can add custom logic easily

### Drawbacks

1. **Not unified** - Namespaces managed differently than other resources
2. **No Crossplane benefits** - No composition functions, no providers
3. **Manual coordination** - Need to ensure namespace exists before XRs

### Conclusion

While Crossplane is excellent for managing cloud resources and complex compositions, namespace management should be kept simple. The cluster-scoped XR limitations make it impractical to manage namespaces through Crossplane at this time.

**Recommendation:** Implement Flux GitOps-based namespace management for reliability and simplicity.

## References

- [Crossplane Issue #6736](https://github.com/crossplane/crossplane/issues/6736) - Changing scope in XRD requires manual restart
- [Kubernetes Namespace Documentation](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)
- [Flux GitOps Documentation](https://fluxcd.io/flux/)