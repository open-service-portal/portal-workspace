# Crossplane Ingestor Plugin

The Crossplane Ingestor is an advanced Backstage plugin that automatically discovers, transforms, and manages Crossplane Composite Resource Definitions (XRDs) as Backstage entities. It's a complete rewrite of the kubernetes-ingestor with enhanced capabilities specifically designed for Crossplane workflows.

## Overview

The Crossplane Ingestor provides deep integration between Crossplane and Backstage by:

- **Discovering XRDs** from multiple Kubernetes clusters
- **Generating Template entities** for self-service infrastructure provisioning
- **Creating API entities** to document infrastructure APIs
- **Tracking resource relationships** between XRDs, Compositions, and XRs
- **Providing CLI tools** for testing and debugging

## Architecture

```
┌─────────────────────────────────────┐
│         Kubernetes Clusters          │
│  ┌──────────────────────────────┐   │
│  │ XRDs, Compositions, XRs      │   │
│  └──────────────────────────────┘   │
└────────────┬───────────────────────┘
             │ Discovery
             ▼
┌─────────────────────────────────────┐
│     Crossplane Ingestor Plugin      │
│  ┌──────────────────────────────┐   │
│  │   KubernetesDataProvider     │   │ ← Fetches resources
│  ├──────────────────────────────┤   │
│  │   CrossplaneDetector         │   │ ← Identifies Crossplane
│  ├──────────────────────────────┤   │
│  │   XRDTransformer             │   │ ← Transforms XRDs
│  ├──────────────────────────────┤   │
│  │   TemplateBuilder            │   │ ← Creates templates
│  ├──────────────────────────────┤   │
│  │   ApiEntityBuilder           │   │ ← Creates API docs
│  └──────────────────────────────┘   │
└────────────┬───────────────────────┘
             │ Entities
             ▼
┌─────────────────────────────────────┐
│       Backstage Catalog              │
│  ┌──────────────────────────────┐   │
│  │ Templates, APIs, Resources   │   │
│  └──────────────────────────────┘   │
└─────────────────────────────────────┘
```

## Key Features

### 1. Intelligent XRD Discovery

The plugin automatically discovers XRDs based on configurable criteria:

```yaml
crossplaneIngestor:
  xrdFilters:
    # Label-based filtering
    labelSelector: "openportal.dev/ingest=true"
    
    # Annotation-based filtering
    annotationSelector: "backstage.io/managed=true"
    
    # Group filtering
    groups:
      - platform.io
      - infrastructure.io
    
    # Exclude specific XRDs
    exclude:
      - testing.platform.io
      - deprecated.platform.io
```

### 2. Advanced Template Generation

Generates rich Backstage templates from XRD schemas:

```yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: database-xr
  title: Database (PostgreSQL)
  description: Provision a managed PostgreSQL database
  tags:
    - crossplane
    - database
    - postgresql
    - source:crossplane-ingestor
spec:
  type: infrastructure
  owner: platform-team
  
  # Generated from XRD schema
  parameters:
    required: [name, size, version]
    properties:
      name:
        title: Database Name
        type: string
        pattern: '^[a-z][a-z0-9-]*$'
      size:
        title: Instance Size
        type: string
        enum: [small, medium, large]
        default: small
      version:
        title: PostgreSQL Version
        type: string
        enum: ['13', '14', '15']
        default: '14'
  
  # Actions to create XR
  steps:
    - id: create-xr
      name: Create Database XR
      action: kubernetes:apply
      input:
        manifest:
          apiVersion: platform.io/v1alpha1
          kind: Database
          metadata:
            name: ${{ parameters.name }}
            namespace: ${{ parameters.namespace }}
          spec:
            size: ${{ parameters.size }}
            version: ${{ parameters.version }}
```

### 3. API Documentation Generation

Creates API entities documenting infrastructure capabilities:

```yaml
apiVersion: backstage.io/v1alpha1
kind: API
metadata:
  name: database-api
  description: Database provisioning API via Crossplane
spec:
  type: openapi
  lifecycle: production
  owner: platform-team
  system: crossplane
  definition: |
    openapi: 3.0.0
    info:
      title: Database API
      version: v1alpha1
    paths:
      /databases:
        post:
          summary: Create a new database
          requestBody:
            content:
              application/yaml:
                schema:
                  $ref: '#/components/schemas/Database'
```

### 4. Composition Tracking

Maps relationships between XRDs and their Compositions:

```yaml
apiVersion: backstage.io/v1alpha1
kind: Resource
metadata:
  name: database-composition
  description: PostgreSQL RDS implementation
spec:
  type: crossplane-composition
  owner: platform-team
  system: crossplane
  dependsOn:
    - resource:default/database-xrd
  implementsApi:
    - api:default/database-api
```

### 5. Multi-Cluster Support

Discovers resources from multiple clusters simultaneously:

```yaml
crossplaneIngestor:
  clusters:
    - name: production
      url: https://prod.k8s.example.com
      authProvider: serviceAccount
      
    - name: staging
      url: https://staging.k8s.example.com
      authProvider: oidc
      
    - name: development
      url: https://dev.k8s.example.com
      authProvider: token
```

## Installation

### 1. Install the Plugin

```bash
# From app-portal root
cd plugins/crossplane-ingestor
yarn install
yarn build
```

### 2. Register with Backend

```typescript
// packages/backend/src/index.ts
import { CrossplaneIngestorModule } from '@internal/plugin-crossplane-ingestor-backend';

const backend = createBackend();

// Add the module
backend.add(CrossplaneIngestorModule);

await backend.start();
```

### 3. Configure in app-config

```yaml
# app-config/ingestor.yaml
crossplaneIngestor:
  enabled: true
  
  # Default metadata for generated entities
  defaultOwner: platform-team
  defaultSystem: crossplane
  
  # Processing schedule
  schedule:
    frequency: { minutes: 5 }
    timeout: { minutes: 2 }
  
  # Cluster configuration
  clusters:
    - name: local
      url: ${KUBERNETES_API_URL}
      authProvider: serviceAccount
      serviceAccountToken: ${KUBERNETES_SA_TOKEN}
  
  # XRD discovery filters
  xrdFilters:
    labelSelector: "openportal.dev/ingest=true"
    namespaces: []  # Empty = all namespaces
  
  # Template generation settings
  templateGeneration:
    generateApiEntities: true
    includeCompositionDetails: true
    addGitOpsActions: true
    defaultNamespace: default
  
  # Caching for performance
  caching:
    enabled: true
    ttl: 300  # seconds
    maxSize: 100  # entries
```

## CLI Tools

The plugin includes powerful CLI tools for testing and debugging:

### Discovery Tool

Discover XRDs from a cluster:

```bash
yarn crossplane-ingestor discover \
  --cluster production \
  --output json
```

Output:
```json
{
  "discovered": [
    {
      "apiVersion": "apiextensions.crossplane.io/v1",
      "kind": "CompositeResourceDefinition",
      "metadata": {
        "name": "databases.platform.io"
      },
      "spec": {
        "group": "platform.io",
        "versions": ["v1alpha1", "v1beta1"]
      }
    }
  ],
  "count": 1
}
```

### Transform Tool

Transform an XRD to Backstage entities:

```bash
yarn crossplane-ingestor transform \
  --xrd ./database-xrd.yaml \
  --output ./generated/
```

Creates:
- `generated/template-database.yaml`
- `generated/api-database.yaml`
- `generated/resource-database.yaml`

### Export Tool

Export all discovered entities:

```bash
yarn crossplane-ingestor export \
  --cluster production \
  --format catalog \
  --output ./catalog/
```

### Validate Tool

Validate XRD compatibility:

```bash
yarn crossplane-ingestor validate \
  --xrd ./my-xrd.yaml
```

Output:
```
✓ XRD structure valid
✓ OpenAPI schema present
✓ Required labels found
✓ Compatible with template generation
⚠ Warning: No description in spec.versions[0].schema
```

## Metadata and Annotations

### XRD Annotations

Control how XRDs are processed:

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: databases.platform.io
  labels:
    # Required for discovery
    openportal.dev/ingest: "true"
    
    # Template categorization
    backstage.io/template-type: "infrastructure"
    
  annotations:
    # Template metadata
    backstage.io/template-title: "PostgreSQL Database"
    backstage.io/template-description: "Provision a managed PostgreSQL database with automatic backups"
    
    # Ownership
    backstage.io/owner: "platform-team"
    backstage.io/system: "data-platform"
    
    # Template hints
    backstage.io/template-tags: "database,postgresql,rds,managed"
    backstage.io/default-namespace: "databases"
    
    # API documentation
    backstage.io/api-version: "v1"
    backstage.io/api-kind: "REST"
    
    # GitOps configuration
    backstage.io/gitops-repo: "github.com/org/catalog-orders"
    backstage.io/gitops-path: "/clusters/prod/databases/"
```

### Generated Entity Annotations

Entities created by the ingestor include:

```yaml
metadata:
  annotations:
    # Source tracking
    crossplane.io/xrd-name: "databases.platform.io"
    crossplane.io/xrd-version: "v1alpha1"
    crossplane.io/composition-ref: "database-aws-rds"
    
    # Discovery metadata
    backstage.io/source-location: "url:https://k8s-cluster/apis/..."
    backstage.io/discovered-at: "2024-01-15T10:30:00Z"
    backstage.io/discovered-from: "production-cluster"
    
    # Template information
    scaffolder.backstage.io/template-origin: "crossplane-ingestor"
    scaffolder.backstage.io/template-version: "auto-generated"
```

## Advanced Configuration

### Custom Transformers

Add custom transformation logic:

```typescript
// custom-transformer.ts
import { XRDTransformer } from '@internal/plugin-crossplane-ingestor-backend';

export class CustomXRDTransformer extends XRDTransformer {
  async transform(xrd: any): Promise<Entity[]> {
    const entities = await super.transform(xrd);
    
    // Add custom logic
    entities.forEach(entity => {
      entity.metadata.annotations['custom.io/processed'] = 'true';
    });
    
    return entities;
  }
}
```

### Processing Hooks

Add pre/post processing hooks:

```typescript
// packages/backend/src/crossplane-config.ts
export const crossplaneConfig = {
  hooks: {
    preProcess: async (xrd) => {
      // Validate or modify XRD before processing
      console.log(`Processing XRD: ${xrd.metadata.name}`);
      return xrd;
    },
    
    postProcess: async (entities) => {
      // Modify generated entities
      entities.forEach(e => {
        e.metadata.labels = {
          ...e.metadata.labels,
          'environment': 'production'
        };
      });
      return entities;
    }
  }
};
```

### Custom Actions

Add scaffolder actions for XR creation:

```typescript
// packages/backend/src/plugins/scaffolder.ts
import { createXRAction } from '@internal/plugin-crossplane-ingestor-backend';

export default async function createPlugin(env: PluginEnvironment) {
  const builder = await createBuilder({
    logger: env.logger,
    config: env.config,
    database: env.database,
  });
  
  // Register custom XR creation action
  builder.addActions([
    createXRAction({
      kubeconfigPath: env.config.getString('kubernetes.kubeconfig'),
      defaultNamespace: 'default',
    })
  ]);
  
  return await builder.build();
}
```

## Performance Optimization

### Caching Strategy

The ingestor implements multi-level caching:

1. **Resource Cache**: Kubernetes resources (5-minute TTL)
2. **Transform Cache**: Generated entities (10-minute TTL)
3. **Template Cache**: Compiled templates (1-hour TTL)

### Batch Processing

Process multiple XRDs efficiently:

```yaml
crossplaneIngestor:
  processing:
    batchSize: 10
    parallelism: 3
    retryAttempts: 2
    retryDelay: 1000  # ms
```

### Selective Updates

Only process changed resources:

```yaml
crossplaneIngestor:
  changeDetection:
    enabled: true
    method: resourceVersion  # or: hash, timestamp
    storage: memory  # or: database, redis
```

## Monitoring and Observability

### Metrics

The plugin exposes Prometheus metrics:

- `crossplane_ingestor_xrds_discovered_total`
- `crossplane_ingestor_entities_generated_total`
- `crossplane_ingestor_processing_duration_seconds`
- `crossplane_ingestor_errors_total`

### Health Checks

```bash
# Check ingestor health
curl http://localhost:7007/api/crossplane-ingestor/health

# Response
{
  "status": "healthy",
  "clusters": {
    "production": "connected",
    "staging": "connected"
  },
  "lastRun": "2024-01-15T10:30:00Z",
  "entitiesGenerated": 42
}
```

### Debugging

Enable debug logging:

```yaml
crossplaneIngestor:
  logging:
    level: debug
    includeStackTraces: true
    logRequests: true
```

## Troubleshooting

### Common Issues

#### XRDs Not Discovered

1. Check label selector:
```bash
kubectl get xrd -A -l openportal.dev/ingest=true
```

2. Verify cluster connectivity:
```bash
yarn crossplane-ingestor test-connection --cluster production
```

3. Check RBAC permissions:
```bash
kubectl auth can-i list xrd --as=system:serviceaccount:backstage:backstage
```

#### Templates Not Generated

1. Validate XRD schema:
```bash
yarn crossplane-ingestor validate --xrd ./my-xrd.yaml
```

2. Check for required annotations:
```yaml
metadata:
  labels:
    openportal.dev/ingest: "true"
```

3. Review transformation logs:
```bash
yarn backstage-cli backend:dev --log-level=debug | grep crossplane-ingestor
```

#### Performance Issues

1. Enable caching:
```yaml
crossplaneIngestor:
  caching:
    enabled: true
```

2. Reduce discovery frequency:
```yaml
schedule:
  frequency: { minutes: 10 }
```

3. Filter unnecessary resources:
```yaml
xrdFilters:
  groups: [platform.io]  # Only specific groups
```

## Migration from kubernetes-ingestor

### Key Differences

| Feature | kubernetes-ingestor | crossplane-ingestor |
|---------|-------------------|-------------------|
| Focus | Generic K8s resources | Crossplane-specific |
| XRD Support | Basic | Advanced with composition tracking |
| Template Generation | Simple | Rich with GitOps integration |
| API Entities | No | Yes |
| CLI Tools | No | Comprehensive suite |
| Caching | Basic | Multi-level |
| Composition Tracking | No | Yes |

### Migration Steps

1. **Install crossplane-ingestor** alongside existing ingestor
2. **Configure filters** to avoid duplication
3. **Test with subset** of XRDs
4. **Gradually migrate** XRDs with labels
5. **Disable kubernetes-ingestor** when complete

## Best Practices

1. **Use Labels Consistently**: Apply standard labels to all XRDs
2. **Document in Annotations**: Use annotations for descriptions
3. **Version XRDs**: Include version in metadata
4. **Test Templates**: Validate generated templates before use
5. **Monitor Performance**: Track metrics and adjust settings
6. **Cache Appropriately**: Balance freshness with performance
7. **Secure Credentials**: Use service accounts with minimal permissions

## Related Documentation

- [Kubernetes Ingestor](./kubernetes-ingestor.md) - Original ingestor plugin
- [Modular Configuration](./modular-config.md) - Configuration architecture
- [Template Standards](../template-standards.md) - Template best practices
- [Crossplane v2 Architecture](../crossplane-v2-architecture.md) - Platform architecture