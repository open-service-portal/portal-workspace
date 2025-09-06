# Ingestor Script

## Overview

The `ingestor.sh` script is a wrapper for the kubernetes-ingestor plugin's CLI tool that transforms Crossplane XRDs into Backstage Software Templates.

## Location

- **Wrapper Script**: `scripts/ingestor.sh`
- **Plugin CLI**: `app-portal/plugins/kubernetes-ingestor/src/cli/ingestor.js`
- **Documentation**: `app-portal/plugins/kubernetes-ingestor/docs/`

## Usage

```bash
# Transform a single XRD file
./scripts/ingestor.sh ./xrd.yaml

# Transform all XRDs in a directory
./scripts/ingestor.sh ./xrds/ --output ./templates

# Fetch XRDs from current Kubernetes cluster
./scripts/ingestor.sh cluster --preview

# Validate XRDs without generating templates
./scripts/ingestor.sh ./xrds/ --validate
```

## Features

- **Preview Mode** (`--preview`): Shows what templates would be generated
- **Validate Mode** (`--validate`): Validates XRD structure without generating
- **Multiple Formats** (`--format`): Output as YAML or JSON
- **Configuration File** (`--config`): Customize transformation behavior
- **Cluster Integration**: Fetch XRDs directly from Kubernetes

## Architecture

The script uses the actual kubernetes-ingestor plugin code through a modular architecture:

1. **CrossplaneDetector** - Detects Crossplane version (v1/v2)
2. **ParameterExtractor** - Converts OpenAPI schemas to form fields
3. **StepGenerator** - Generates scaffolder steps (v1 or v2 specific)
4. **TemplateBuilder** - Assembles complete Backstage templates
5. **XRDTransformer** - Orchestrates the transformation pipeline

## Key Benefits

✅ **Same Logic as Plugin** - Uses the actual plugin code, not a reimplementation
✅ **Standalone Usage** - Works without Backstage running
✅ **CI/CD Ready** - Can be integrated into pipelines
✅ **Full Feature Parity** - All plugin transformation features available

## Documentation

For detailed documentation, see:

- [CLI Usage Guide](../app-portal/plugins/kubernetes-ingestor/docs/CLI-USAGE.md)
- [Metadata Flow](../app-portal/plugins/kubernetes-ingestor/docs/METADATA-FLOW.md)
- [Developer Guide](../app-portal/plugins/kubernetes-ingestor/docs/DEVELOPER-GUIDE.md)
- [Development History](../app-portal/plugins/kubernetes-ingestor/docs/HISTORY.md)

## Troubleshooting

If the plugin is not built, the wrapper script will automatically build it. To manually build:

```bash
cd app-portal/plugins/kubernetes-ingestor
yarn build
```

## Maintenance

The wrapper script is a thin layer that:
1. Checks if the plugin is built
2. Builds if necessary
3. Passes all arguments to the plugin's CLI

Any updates to transformation logic should be made in the plugin itself, not the wrapper.