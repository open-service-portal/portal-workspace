# Ingestor Plugin

## Overview

The ingestor plugin is a standalone Backstage plugin that provides:

1. **Runtime Discovery** - Automatically discovers and imports Kubernetes resources into the Backstage catalog
2. **CLI Tools** - Command-line utilities for processing resources outside of Backstage
3. **Unified Engine** - Same transformation logic shared between runtime and CLI

## Plugin Architecture

```
ingestor/
├── src/
│   ├── plugin.ts           # Backstage plugin registration
│   ├── module.ts           # New backend system module
│   ├── lib/
│   │   ├── IngestionEngine.ts      # Core processing engine
│   │   ├── ResourceValidator.ts    # Resource validation
│   │   ├── EntityBuilder.ts        # Entity transformation
│   │   └── adapters/                # Environment adapters
│   │       ├── BackstageAdapter.ts # Runtime adapter
│   │       └── CLIAdapter.ts       # CLI adapter
│   └── cli/
│       ├── ingestor-cli.ts         # Resource ingestion CLI
│       └── backstage-export-cli.ts # Entity export CLI
├── docs/                   # Detailed specifications
└── README.md              # Plugin documentation
```

## Key Features

### Runtime Features
- Discovers Kubernetes resources (XRDs, ConfigMaps, Services, etc.)
- Transforms resources into Backstage entities (Templates, APIs, Components)
- Supports multiple Kubernetes clusters
- Configurable discovery rules and filters
- Automatic refresh on resource changes

### CLI Features
- Process resources without running Backstage
- Export entities from running Backstage instances
- Preview and validation modes
- CI/CD pipeline integration
- Development mode with ts-node (no build required)

## Quick Start

### Using the CLI Tools

```bash
# Transform an XRD into a Backstage template
./scripts/template-ingest.sh ./xrd.yaml

# Export templates from Backstage
./scripts/template-export.sh --kind Template

# See all options
./scripts/template-ingest.sh --help
./scripts/template-export.sh --help
```

For detailed CLI documentation, see [CLI Tools Documentation](./cli-tools.md).

### Plugin Installation

```bash
# Clone the plugin into your Backstage app
cd app-portal/plugins
git clone https://github.com/open-service-portal/ingestor.git

# Install dependencies
cd ingestor
yarn install

# Register in Backstage backend
# (See app-portal/packages/backend/src/index.ts)
```

## Resource Processing

### Supported Resources

The ingestor currently supports:
- **Crossplane XRDs** → Backstage Templates + APIs
- **ConfigMaps** (with annotations) → Various entity types
- **Kubernetes Services** → Component entities
- **Custom Resources** → Configurable mappings

### Transformation Rules

Resources are transformed based on:
1. Resource type and API version
2. Labels and annotations (e.g., `backstage.io/kind`)
3. Custom configuration rules
4. Resource content analysis

Example XRD annotations that control transformation:
```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xdnsrecords.platform.io
  labels:
    openportal.dev/tags: "dns,infrastructure"
  annotations:
    openportal.dev/publish-phase: "gitops-repo: catalog-orders"
    openportal.dev/description: "DNS record management"
```

## Configuration

### Runtime Configuration

Configure in `app-config.yaml`:

```yaml
kubernetes:
  serviceLocatorMethod:
    type: multiTenant
  clusterLocatorMethods:
    - type: config
      clusters:
        - name: production
          url: https://k8s.example.com
          authProvider: serviceAccount

ingestor:
  kubernetes:
    enabled: true
    clusters:
      - production
  processors:
    - type: xrd
      enabled: true
    - type: configmap
      enabled: true
      filters:
        - namespace: backstage
```

### CLI Configuration

Create `.ingestor.yaml` for custom rules:

```yaml
apiVersion: ingestor.backstage.io/v1alpha1
kind: Config
spec:
  transformations:
    - resourceType: XRD
      outputKind: Template
  validation:
    strict: true
```

## Development

### Running in Development Mode

The CLI tools run directly from TypeScript source:

```bash
# No build needed - changes take effect immediately
cd app-portal/plugins/ingestor
npx ts-node src/cli/ingestor-cli.ts ./test.yaml
```

### Testing

```bash
cd app-portal/plugins/ingestor

# Run unit tests
yarn test

# Test CLI directly
npx ts-node src/cli/ingestor-cli.ts --validate ./test-data/
```

### Building for Production

```bash
# Build the plugin
yarn build

# Build CLI tools (optional, not required for development)
yarn build:cli
```

## Documentation

- **[CLI Tools Guide](./cli-tools.md)** - Comprehensive CLI documentation
- **[Plugin README](../app-portal/plugins/ingestor/README.md)** - Installation and configuration
- **[CLI Specifications](../app-portal/plugins/ingestor/docs/CLI-INGESTOR-SPEC.md)** - Technical specifications
- **[Implementation Guide](../app-portal/plugins/ingestor/docs/CLI-IMPLEMENTATION.md)** - Architecture details
- **[Export Tool Spec](../app-portal/plugins/ingestor/docs/BACKSTAGE-EXPORT-SPEC.md)** - Export tool details

## Migration from kubernetes-ingestor

If migrating from the old kubernetes-ingestor plugin:

1. The new plugin is a drop-in replacement with the same core functionality
2. Configuration format is largely compatible
3. The new plugin adds CLI capabilities not present in the old version
4. Module registration follows Backstage's new backend system

Key differences:
- Renamed from `kubernetes-ingestor` to `ingestor`
- Added CLI tools for standalone usage
- Unified ingestion engine architecture
- Better TypeScript types and error handling

## Support

For issues or questions:
- Check the [troubleshooting section](./cli-tools.md#troubleshooting)
- Open an issue at [GitHub Issues](https://github.com/open-service-portal/ingestor/issues)
- Review the plugin source code for implementation details