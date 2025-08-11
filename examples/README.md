# Examples

This directory contains example configurations and learning resources for the Open Service Portal.

## Directory Structure

### crossplane-examples/
Advanced Crossplane examples showing how to:
- Create Composite Resource Definitions (XRDs)
- Build Compositions for reusable application templates
- Deploy applications using claims

### crossplane-rancher-examples/
Rancher Desktop-specific Crossplane examples including:
- Provider configurations
- Smoke tests
- Troubleshooting guides for Rancher Desktop

## Getting Started

1. First complete the Rancher Desktop setup:
   ```bash
   ./scripts/setup-rancher-k8s.sh
   ```

2. Then explore the examples in each directory based on your needs.

## Note

These examples are for learning and experimentation. The actual setup files used by the setup script are located in `scripts/rancher-k8s-manifests/`.