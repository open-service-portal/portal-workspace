# Cluster Manifests

This directory contains Kubernetes manifests used by `setup-cluster.sh` to configure the Open Service Portal platform.

## Documentation

See [Cluster Manifests Documentation](../../docs/cluster/manifests.md) for detailed information about:
- Each manifest file and its purpose
- How providers and functions work together
- Best practices and examples

## Quick Reference

- **Providers**: kubernetes, helm
- **Functions**: go-templating, patch-and-transform, auto-ready, environment-configs
- **DNS Management**: External-DNS for multi-provider DNS support
- **Configs**: Environment configurations with local defaults
- **GitOps**: Flux catalog watcher configuration

These manifests are automatically applied by `./scripts/setup-cluster.sh`.