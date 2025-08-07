# Node.js Version Requirements for Backstage

## Current Requirements (2025)

According to Backstage documentation:
- **Recommended**: Node.js Active LTS Release
- **Node.js 20** is suggested as a good starting point

### Version Support Status

- **Backstage v1.19.0**: Supports Node.js 18 and 20
- **Backstage v1.33.0**: Mentions "Scaffolder now supports Node.js v22"

**Note:** The v1.33.0 release notes only explicitly mention Node.js 22 support for the Scaffolder component. Full Backstage support for Node.js 22 across all components is not clearly documented.

Sources:
- [Backstage Getting Started](https://backstage.io/docs/getting-started/)
- [Backstage v1.33.0 Release Notes](https://backstage.io/docs/releases/v1.33.0/)


## Quick Fix: Use Correct Node Version

```bash
# Check current version
node --version

# If wrong version, use nvm to switch
nvm use 20
# or
nvm install 20 && nvm use 20
```


## Common Issues

### Error: Unsupported Node version
```
error: Your Node version is not supported
```
**Solution:** Update to Node 20

### Error with NODE_OPTIONS (Node.js 20+)
```
Error: Cannot find module 'node:snapshot'
```
**Solution:** The Scaffolder plugin requires disabling Node snapshots:
```bash
export NODE_OPTIONS="--no-node-snapshot"
```


## Auto-Switch Node Version with direnv

### Quick Setup

1. Install direnv:
```bash
# macOS with Homebrew
brew install direnv

# Ubuntu/Debian
sudo apt install direnv

# Or download binary from https://direnv.net
```

2. Add to `~/.zshrc`:
```bash
eval "$(direnv hook zsh)"
```

3. Copy `.envrc.example` to `.envrc`:
```bash
cp .envrc.example .envrc
# Edit .envrc with your credentials
# Note: .nvmrc is already in the repository with Node.js 20
```

4. Allow direnv:
```bash
direnv allow
```

### How It Works

- Automatically loads `.envrc` when entering directory
- Sets Node version via nvm
- Loads all environment variables
- Unloads everything when leaving directory

### Alternative: .nvmrc only

If you prefer using only `.nvmrc` without direnv:
```bash
# .nvmrc is already in the repository
nvm use  # Manual activation
```

## Resources

- [Node.js Release Schedule](https://nodejs.org/en/about/previous-releases)
- [Backstage Versioning Policy](https://backstage.io/docs/overview/versioning-policy/)
- [nvm Documentation](https://github.com/nvm-sh/nvm)