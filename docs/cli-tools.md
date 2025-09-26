# CLI Tools Documentation

## Overview

The ingestor plugin provides two powerful CLI tools for working with Backstage and Kubernetes resources:

1. **template-ingest.sh** - Transforms Crossplane XRDs into Backstage Templates
2. **template-export.sh** - Exports entities from a running Backstage instance

Both tools run directly from TypeScript source using ts-node, providing instant updates without compilation.

## Template Ingestion Tool

### Purpose
Transforms Kubernetes resources (particularly Crossplane XRDs) into Backstage Software Templates and API entities.

### Location
- **Wrapper Script**: `scripts/template-ingest.sh`
- **CLI Source**: `app-portal/plugins/ingestor/src/cli/ingestor-cli.ts`
- **Core Engine**: `app-portal/plugins/ingestor/src/lib/IngestionEngine.ts`

### Usage Examples

```bash
# Transform a single XRD file
./scripts/template-ingest.sh path/to/xrd.yaml

# Process all XRDs in a directory
./scripts/template-ingest.sh ./xrds/ --output ./templates

# Read from stdin (useful for pipelines)
kubectl get xrd myresource.example.com -o yaml | ./scripts/template-ingest.sh -

# Preview mode - see what would be generated
./scripts/template-ingest.sh ./xrd.yaml --preview

# Validate XRDs without generating output
./scripts/template-ingest.sh ./xrds/ --validate

# Specify output format
./scripts/template-ingest.sh ./xrd.yaml --format json

# Use custom configuration
./scripts/template-ingest.sh ./xrd.yaml --config ./ingestor-config.yaml
```

### Features
- **Multi-source Input**: Files, directories, stdin, or Kubernetes cluster
- **Preview Mode**: Dry-run to see what would be generated
- **Validation**: Check XRD structure without generating files
- **Format Support**: Output as YAML or JSON
- **Configuration**: Customize transformation behavior
- **Unified Engine**: Same logic as the Backstage runtime plugin

### Architecture
```
Input (XRD) → Parser → Validator → EntityBuilder → Output (Template/API)
                           ↑
                    IngestionEngine
                    (Shared with Runtime)
```

## Template Export Tool

### Purpose
Exports catalog entities from a running Backstage instance for backup, migration, or analysis.

### Location
- **Wrapper Script**: `scripts/template-export.sh`
- **CLI Source**: `app-portal/plugins/ingestor/src/cli/backstage-export-cli.ts`

### Usage Examples

```bash
# Export all templates
./scripts/template-export.sh --kind Template

# Export multiple entity types
./scripts/template-export.sh --kind Template,API,Component

# Export with filters
./scripts/template-export.sh --kind Template --tags crossplane --namespace default

# Export to specific directory with organization
./scripts/template-export.sh --kind Template --output ./backup --organize

# Preview what would be exported
./scripts/template-export.sh --preview --kind Template

# List entities without exporting
./scripts/template-export.sh --list --kind API

# Export with manifest for tracking
./scripts/template-export.sh --kind Template --manifest

# Filter by owner
./scripts/template-export.sh --kind Component --owner team-platform

# Use wildcards in name patterns
./scripts/template-export.sh --kind Template --name "dns-*"

# Custom Backstage URL and authentication
./scripts/template-export.sh --url https://backstage.example.com --token $API_TOKEN
```

### Features
- **Entity Filtering**: By kind, namespace, owner, tags, name patterns
- **Auto-detection**: Finds API tokens from local config files
- **Organization**: Option to organize exports by entity type
- **Manifest Generation**: Creates inventory of exported entities
- **Preview Mode**: See what would be exported without writing files
- **List Mode**: Quick entity listing without full export

### Authentication
The tool auto-detects API tokens from Backstage config files (`app-config.*.local.yaml`). You can also:

```bash
# Set via environment variable
export BACKSTAGE_TOKEN="your-token"
./scripts/template-export.sh --kind Template

# Pass via command line
./scripts/template-export.sh --token "your-token" --kind Template
```

## Development Mode Execution

Both tools run directly from TypeScript source, enabling rapid development:

```bash
# No build needed - changes take effect immediately
vim app-portal/plugins/ingestor/src/cli/ingestor-cli.ts
./scripts/template-ingest.sh ./test.yaml  # Uses updated code instantly

# Direct execution for debugging
cd app-portal/plugins/ingestor
npx ts-node src/cli/ingestor-cli.ts --help
npx ts-node src/cli/backstage-export-cli.ts --help

# With Node.js debugging
node --inspect-brk -r ts-node/register src/cli/ingestor-cli.ts ./xrd.yaml
```

## Configuration Files

### Ingestor Configuration
Create `.ingestor.yaml` for custom transformation rules:

```yaml
# .ingestor.yaml
apiVersion: ingestor.backstage.io/v1alpha1
kind: Config
spec:
  transformations:
    - resourceType: XRD
      outputKind: Template
      namespace: default
      additionalTags:
        - crossplane
        - infrastructure
  validation:
    requireLabels:
      - openportal.dev/tags
    requireAnnotations:
      - openportal.dev/publish-phase
```

### Export Configuration
The export tool uses Backstage's native configuration:

```yaml
# app-config.local.yaml
backend:
  auth:
    keys:
      - secret: "your-secret-key"
  # API token for programmatic access
  auth:
    providers:
      static:
        type: static
        token: "your-api-token"
```

## CI/CD Integration

### GitLab CI Example
```yaml
# .gitlab-ci.yml
validate-xrds:
  script:
    - ./scripts/template-ingest.sh ./xrds/ --validate
  only:
    changes:
      - xrds/**/*

generate-templates:
  script:
    - ./scripts/template-ingest.sh ./xrds/ --output ./templates
  artifacts:
    paths:
      - templates/
```

### GitHub Actions Example
```yaml
# .github/workflows/templates.yml
name: Process Templates
on:
  push:
    paths:
      - 'xrds/**'

jobs:
  generate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '20'
      - run: |
          cd app-portal/plugins/ingestor
          yarn install
      - run: ./scripts/template-ingest.sh ./xrds/ --output ./templates
      - uses: actions/upload-artifact@v3
        with:
          name: templates
          path: templates/
```

## Troubleshooting

### Common Issues

1. **Dependencies not installed**
   ```bash
   cd app-portal/plugins/ingestor
   yarn install
   ```

2. **TypeScript errors during execution**
   ```bash
   # Check TypeScript configuration
   cd app-portal/plugins/ingestor
   npx tsc --noEmit
   ```

3. **API token issues with export tool**
   ```bash
   # Check token is set
   echo $BACKSTAGE_TOKEN

   # Test API access
   curl -H "Authorization: Bearer $BACKSTAGE_TOKEN" \
     http://localhost:7007/api/catalog/entities
   ```

4. **Path resolution issues**
   ```bash
   # Scripts expect to run from workspace root
   cd /path/to/portal-workspace
   ./scripts/template-ingest.sh ./xrd.yaml
   ```

## Architecture Benefits

### Unified Ingestion Engine
- **Single Source of Truth**: Same transformation logic for CLI and runtime
- **Consistent Results**: CLI output matches what Backstage would generate
- **Easy Testing**: Test transformations locally before deploying

### Development Mode by Default
- **No Build Step**: Changes take effect immediately
- **Rapid Iteration**: Edit and test without compilation
- **Debugging Support**: Full TypeScript debugging capabilities

### Modular Design
- **Adapter Pattern**: Clean separation of I/O from business logic
- **Extensible**: Easy to add new resource types or output formats
- **Testable**: Each component can be tested independently

## Related Documentation

- [Ingestor Plugin README](../app-portal/plugins/ingestor/README.md)
- [CLI Specifications](../app-portal/plugins/ingestor/docs/CLI-INGESTOR-SPEC.md)
- [CLI Implementation Guide](../app-portal/plugins/ingestor/docs/CLI-IMPLEMENTATION.md)
- [Export Tool Specification](../app-portal/plugins/ingestor/docs/BACKSTAGE-EXPORT-SPEC.md)
- [Backstage Catalog API](https://backstage.io/docs/features/software-catalog/software-catalog-api)