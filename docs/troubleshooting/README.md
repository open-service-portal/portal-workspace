# Troubleshooting Guide

Common issues and solutions for Open Service Portal development.

## Topics

- [Node.js Version Requirements](./node-version-requirements.md) - Wrong Node version errors and how to fix them
- [Port Conflicts](./port-conflicts.md) - Port already in use errors and solutions
- [Rancher Desktop Issues](./rancher-desktop-issues.md) - Troubleshooting Rancher Desktop setup and common problems

## Quick Checks

### Is your Node version compatible?
```bash
node --version
# Should be v20.x.x or v22.x.x for Backstage 1.33.0+
```

### Are ports available?
```bash
lsof -i :3000  # Backstage frontend
lsof -i :7007  # Backstage backend
```

### Are environment variables set?
```bash
env | grep GITHUB_TOKEN
env | grep GITLAB_TOKEN
```

## Getting Help

1. Check repository-specific CLAUDE.md files
2. Review Backstage documentation: https://backstage.io/docs
3. Search GitHub issues: https://github.com/backstage/backstage/issues