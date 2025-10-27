# Kubernetes Ingestor Plugin

> **Note**: For advanced Crossplane integration, consider using the new [Crossplane Ingestor Plugin](./crossplane-ingestor.md) which provides enhanced features specifically designed for Crossplane workflows.

The Kubernetes Ingestor is a custom Backstage plugin that automatically discovers Crossplane Composite Resource Definitions (XRDs) from Kubernetes clusters and transforms them into Backstage template entities.

## Overview

The Kubernetes Ingestor plugin bridges the gap between Crossplane infrastructure templates and the Backstage developer portal by:

- **Discovering XRDs** from connected Kubernetes clusters
- **Generating template entities** automatically in the Backstage catalog
- **Extracting form schemas** from XRD OpenAPI specifications
- **Managing template versions** from XRD labels
- **Enabling self-service** infrastructure provisioning

## Architecture

```
┌─────────────────────────┐
│  Kubernetes Cluster     │
│  ┌──────────────────┐   │
│  │ Crossplane XRDs  │   │ ◄── Flux deploys from catalog repo
│  └──────────────────┘   │
└────────────┬───────────┘
             │ Poll (60s interval)
             ▼
┌─────────────────────────┐
│  Kubernetes Ingestor    │
│  (Backstage Plugin)     │
│  ┌──────────────────┐   │
│  │ XRD Discovery    │   │
│  │ Template Gen     │   │
│  │ Schema Extract   │   │
│  └──────────────────┘   │
└────────────┬───────────┘
             │ Create entities
             ▼
┌─────────────────────────┐
│  Backstage Catalog      │
│  ┌──────────────────┐   │
│  │ Template Entities│   │ ◄── Displayed in /create
│  └──────────────────┘   │
└─────────────────────────┘
```

## How It Works

### 1. XRD Discovery

The ingestor polls the Kubernetes API every 60 seconds to discover XRDs with specific labels:

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: cloudflareDNSRecords.openportal.dev
  labels:
    openportal.dev/tags: "dns,networking,cloudflare"  # Required for discovery
    openportal.dev/version: "1.0.2"                   # Version displayed in UI
spec:
  group: openportal.dev
  names:
    kind: CloudflareDNSRecord
  versions:
  - name: v1alpha1
    schema:
      openAPIV3Schema:  # Forms generated from this schema
        type: object
        properties:
          spec:
            type: object
            properties:
              name: 
                type: string
                description: DNS record name
```

### 2. Template Entity Generation

For each discovered XRD, the ingestor creates a Backstage template entity:

```yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: cloudflare-dns-record
  title: CloudflareDNSRecord v1.0.2
  description: DNS management via External-DNS
  tags:
    - dns
    - networking
    - cloudflare
    - source:kubernetes  # Identifies ingestor-created templates
spec:
  type: infrastructure
  parameters:
    # Generated from XRD schema
    required:
      - name
      - type
      - value
    properties:
      name:
        title: Name
        type: string
        description: DNS record name
      type:
        title: Type
        type: string
        enum: ['A', 'AAAA', 'CNAME', 'TXT', 'MX']
      value:
        title: Value
        type: string
        description: IP address or target
```

### 3. Form Schema Processing

The ingestor extracts and processes the OpenAPI schema from XRDs to:

- Generate form fields with proper types
- Add validation rules (required, patterns, min/max)
- Include descriptions and help text
- Set default values where specified
- Create enum dropdowns for constrained fields

### 4. Catalog Integration

Generated templates are added to the Backstage catalog with:

- **Unique identifiers** based on XRD name
- **Version labels** from XRD metadata
- **Tags** for filtering and discovery
- **source:kubernetes** tag for identification
- **Descriptions** from XRD annotations

## Configuration

### Plugin Installation

The plugin is included in the app-portal repository:

```typescript
// packages/backend/src/plugins/catalog.ts
import { KubernetesIngestorProvider } from '@internal/plugin-kubernetes-ingestor-backend';

export default async function createPlugin(env: PluginEnvironment): Promise<Router> {
  const builder = await CatalogBuilder.create(env);
  
  // Add Kubernetes Ingestor provider
  builder.addEntityProvider(
    KubernetesIngestorProvider.fromConfig(env.config, {
      logger: env.logger,
      scheduler: env.scheduler,
    }),
  );
  
  const { processingEngine, router } = await builder.build();
  await processingEngine.start();
  
  return router;
}
```

### App Configuration

Configure the ingestor in `app-config.yaml`:

```yaml
kubernetesIngestor:
  enabled: true
  pollInterval: 60000  # Polling interval in milliseconds
  clusters:
    - name: production
      url: ${KUBERNETES_API_URL}
      authProvider: serviceAccount
      serviceAccountToken: ${KUBERNETES_SA_TOKEN}
      skipTLSVerify: false
  
  # XRD discovery filters
  filters:
    labelSelector: "openportal.dev/tags"  # Only XRDs with this label
    namespaces: []  # Empty = all namespaces
    
  # Template generation settings
  templates:
    defaultType: infrastructure
    defaultOwner: platform-team
    publishPhase:  # How to structure catalog-orders
      path: /clusters/${cluster}/${namespace}/${kind}
```

### Required XRD Labels

XRDs must have specific labels to be discovered:

```yaml
metadata:
  labels:
    openportal.dev/tags: "tag1,tag2,tag3"     # Required: comma-separated tags
    openportal.dev/version: "1.0.0"           # Optional: version to display
    openportal.dev/icon: "dns"                # Optional: icon name
    openportal.dev/owner: "platform-team"     # Optional: template owner
```

### XRD Annotations for Enhanced Templates

Use annotations to provide additional template metadata:

```yaml
metadata:
  annotations:
    openportal.dev/description: "Create and manage DNS records via Cloudflare"
    openportal.dev/documentation: "https://docs.example.com/dns"
    openportal.dev/support: "platform-team@example.com"
    openportal.dev/publishPhase: |
      path: /clusters/infra/${namespace}/dns-records
      autoMerge: true
```

## Usage Workflow

### 1. Template Development

Create an XRD with proper labels and schema:

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: databases.platform.io
  labels:
    openportal.dev/tags: "database,postgresql,storage"
    openportal.dev/version: "2.1.0"
spec:
  group: platform.io
  names:
    kind: Database
    plural: databases
  versions:
  - name: v1alpha1
    served: true
    referenceable: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            required: ["size", "version"]
            properties:
              size:
                type: string
                enum: ["small", "medium", "large"]
                default: "small"
                description: "Database instance size"
              version:
                type: string
                pattern: "^[0-9]+\\.[0-9]+$"
                default: "14.0"
                description: "PostgreSQL version"
              backup:
                type: boolean
                default: true
                description: "Enable automated backups"
```

### 2. Deploy to Cluster

Deploy the XRD via GitOps (Flux):

```bash
# XRD is in catalog repository
catalog/
└── templates/
    └── database/
        ├── xrd.yaml        # The XRD above
        └── composition.yaml

# Flux syncs it to cluster
flux get sources git catalog
flux get kustomizations catalog-sync
```

### 3. Discovery in Backstage

The ingestor automatically discovers the XRD:

1. **Polls cluster** every 60 seconds
2. **Finds XRD** with `openportal.dev/tags` label
3. **Extracts schema** from OpenAPI specification
4. **Generates template** entity
5. **Adds to catalog** with `source:kubernetes` tag

### 4. Use in Developer Portal

Developers can now use the template:

1. Navigate to https://backstage.example.com/create
2. Filter templates by tags (database, postgresql)
3. Select "Database v2.1.0" template
4. Fill out the generated form
5. Submit to create XR in catalog-orders

## Template Features

### Dynamic Form Generation

Forms are generated from XRD schemas with:

- **Field types**: string, number, boolean, array, object
- **Validation**: required, patterns, min/max, enums
- **UI hints**: descriptions, placeholders, defaults
- **Grouping**: nested objects become form sections
- **Arrays**: dynamic add/remove for list fields

### Version Management

Templates display versions from XRD labels:

```yaml
labels:
  openportal.dev/version: "1.2.3"
```

Displayed as: "TemplateName v1.2.3"

### Tag-based Discovery

Tags enable filtering and categorization:

```yaml
labels:
  openportal.dev/tags: "networking,security,firewall"
```

Users can filter by any tag in the /create catalog.

## Monitoring and Debugging

### Check Ingestor Status

```bash
# View ingestor logs
kubectl logs -n backstage deployment/backstage-backend | grep -i ingestor

# Check discovered XRDs
kubectl get xrd -A -l openportal.dev/tags

# Verify template generation in Backstage
curl http://localhost:7007/api/catalog/entities?filter=kind=Template,metadata.tags=source:kubernetes
```

### Common Issues

#### Templates Not Appearing

1. **Check XRD labels**:
   ```bash
   kubectl get xrd your-xrd -o yaml | grep -A5 labels
   ```

2. **Verify ingestor is running**:
   ```bash
   kubectl logs -n backstage deployment/backstage-backend | grep "KubernetesIngestor"
   ```

3. **Check Backstage catalog**:
   - Navigate to /catalog
   - Filter by kind=Template
   - Look for source:kubernetes tag

#### Form Fields Missing

1. **Verify XRD schema**:
   ```bash
   kubectl get xrd your-xrd -o yaml | grep -A50 openAPIV3Schema
   ```

2. **Check schema validation**:
   - Ensure all spec.properties are defined
   - Add descriptions for better UX
   - Set required fields appropriately

#### Version Not Displayed

Add version label to XRD:
```bash
kubectl label xrd your-xrd openportal.dev/version="1.0.0"
```

## Advanced Configuration

### Custom Template Actions

Extend generated templates with custom actions:

```yaml
# In XRD annotation
metadata:
  annotations:
    openportal.dev/scaffolder-actions: |
      - id: publish
        name: github:publish
        action: publish:github
        input:
          repoUrl: github.com?owner=org&repo=catalog-orders
          sourcePath: ./
          targetPath: /clusters/${cluster}/${namespace}/${kind}
```

### Multi-Cluster Support

Configure multiple clusters:

```yaml
kubernetesIngestor:
  clusters:
    - name: dev
      url: https://dev-cluster.example.com
      authProvider: serviceAccount
      
    - name: staging  
      url: https://staging-cluster.example.com
      authProvider: serviceAccount
      
    - name: production
      url: https://prod-cluster.example.com
      authProvider: serviceAccount
```

Templates will be discovered from all configured clusters.

### Filtering and Namespaces

Control which XRDs are discovered:

```yaml
kubernetesIngestor:
  filters:
    labelSelector: "openportal.dev/tags,environment=production"
    namespaces: 
      - crossplane-system
      - platform-templates
    excludeKinds:
      - TestResource
      - DebugResource
```

## Integration with Scaffolder

The ingestor works seamlessly with the Backstage Scaffolder:

1. **Template Discovery**: XRDs become available as templates
2. **Form Rendering**: Scaffolder uses generated schema
3. **Action Execution**: Creates XRs in catalog-orders
4. **GitOps Flow**: Flux deploys XRs to cluster

## Best Practices

### 1. XRD Design

- Include comprehensive OpenAPI schemas
- Add meaningful descriptions to all fields
- Set appropriate defaults
- Use enums for constrained choices
- Group related fields in nested objects

### 2. Labeling Strategy

- Always include `openportal.dev/tags`
- Use semantic versioning in `openportal.dev/version`
- Apply consistent tag taxonomy
- Document tag meanings

### 3. Schema Validation

- Test XRD schemas before deployment
- Validate with sample XRs
- Include example values in descriptions
- Use regex patterns for validation

### 4. Performance

- Keep polling interval reasonable (60s default)
- Limit number of XRDs with labels
- Use namespace filtering if possible
- Monitor ingestor resource usage

## Troubleshooting Guide

### Logs and Metrics

```bash
# Ingestor logs
kubectl logs -n backstage deployment/backstage-backend | grep -i kubernetes-ingestor

# Check processing time
kubectl logs -n backstage deployment/backstage-backend | grep "Processing XRD"

# View discovered templates
curl http://localhost:7007/api/catalog/entities | jq '.items[] | select(.metadata.tags[]? == "source:kubernetes")'
```

### Debug Mode

Enable debug logging:

```yaml
# app-config.yaml
kubernetesIngestor:
  debug: true
  logLevel: debug
```

### Health Checks

```bash
# Check catalog health
curl http://localhost:7007/api/catalog/health

# Verify Kubernetes connectivity
kubectl auth can-i list xrd --as=system:serviceaccount:backstage:backstage
```

## Comparison with Crossplane Ingestor

The newer [Crossplane Ingestor Plugin](./crossplane-ingestor.md) provides enhanced capabilities:

| Feature | Kubernetes Ingestor | Crossplane Ingestor |
|---------|-------------------|-------------------|
| **Focus** | Generic K8s + XRDs | Crossplane-specific |
| **Template Generation** | Basic | Advanced with GitOps |
| **API Documentation** | No | Auto-generated API entities |
| **Composition Tracking** | No | Full relationship mapping |
| **CLI Tools** | No | Comprehensive suite |
| **Caching** | Simple | Multi-level optimization |
| **Transform Pipeline** | Fixed | Extensible with hooks |
| **Metadata Support** | Basic | Rich annotations |

Consider migrating to the Crossplane Ingestor for:
- Better Crossplane-native features
- Advanced template generation
- API documentation generation
- CLI tools for debugging
- Performance optimizations

## Related Documentation

- [Crossplane Ingestor Plugin](./crossplane-ingestor.md) - Advanced Crossplane integration
- [Modular Configuration](./modular-config.md) - New configuration architecture
- [Crossplane v2 Architecture](../crossplane-v2-architecture.md)
- [Template Standards](../template-standards.md)
- [Catalog Setup](../cluster/catalog-setup.md)
- [Workflow Documentation](../workflow.md)