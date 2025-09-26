# Ingestor Script

## Overview

The `template-ingest.sh` script is a wrapper for the ingestor plugin's CLI tool that transforms Crossplane XRDs into Backstage Software Templates using a unified ingestion engine.

## Location

- **Wrapper Script**: `scripts/template-ingest.sh`
- **Plugin CLI**: `app-portal/plugins/ingestor/dist/cli/ingestor-cli.js`
- **Documentation**: `app-portal/plugins/ingestor/docs/`

## Usage

```bash
# Transform a single XRD file
./scripts/template-ingest.sh ./xrd.yaml

# Transform all XRDs in a directory
./scripts/template-ingest.sh ./xrds/ --output ./templates

# Read from stdin
cat xrd.yaml | ./scripts/template-ingest.sh -

# Preview what would be generated
./scripts/template-ingest.sh ./xrd.yaml --preview

# Validate XRDs without generating templates
./scripts/template-ingest.sh ./xrds/ --validate
```

## Features

- **Preview Mode** (`--preview`): Shows what templates would be generated
- **Validate Mode** (`--validate`): Validates XRD structure without generating
- **Multiple Formats** (`--format`): Output as YAML or JSON
- **Configuration File** (`--config`): Customize transformation behavior
- **Cluster Integration**: Fetch XRDs directly from Kubernetes

## Architecture

The script uses the new ingestor plugin's unified ingestion engine with a clean architecture:

1. **IngestionEngine** - Core engine shared between CLI and runtime
2. **ResourceValidator** - Validates XRD structure and requirements
3. **XRDEntityBuilder** - Transforms XRDs to Template and API entities
4. **CLIAdapter** - Handles file I/O and console output
5. **Unified Processing** - Same transformation logic for CLI and Backstage runtime

## Key Benefits

✅ **Same Logic as Plugin** - Uses the actual plugin code, not a reimplementation
✅ **Standalone Usage** - Works without Backstage running
✅ **CI/CD Ready** - Can be integrated into pipelines
✅ **Full Feature Parity** - All plugin transformation features available

## Documentation

For detailed documentation, see:

- [CLI Specifications](../app-portal/plugins/ingestor/docs/CLI-INGESTOR-SPEC.md)
- [CLI Implementation Guide](../app-portal/plugins/ingestor/docs/CLI-IMPLEMENTATION.md)
- [Export Tool Specification](../app-portal/plugins/ingestor/docs/BACKSTAGE-EXPORT-SPEC.md)
- [Plugin README](../app-portal/plugins/ingestor/README.md)

## Troubleshooting

To build the plugin and CLI tools:

```bash
cd app-portal/plugins/ingestor
yarn build
yarn build:cli
```

## Maintenance

The wrapper script is a thin layer that:
1. Checks if the plugin is built
2. Builds if necessary
3. Passes all arguments to the plugin's CLI

Any updates to transformation logic should be made in the plugin itself, not the wrapper.