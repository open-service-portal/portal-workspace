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


## Auto-Switch Node Version with direnv (Recommended)

### macOS with Homebrew Example

1. Install direnv:
```bash
brew install direnv
```

2. Add to `~/.zshrc`:
```bash
eval "$(direnv hook zsh)"
```

3. Reload shell:
```bash
source ~/.zshrc
```

### Other Platforms

```bash
# Ubuntu/Debian
sudo apt install direnv
# Add to ~/.bashrc: eval "$(direnv hook bash)"

# Manual installation
# Download from https://direnv.net
```

### Setup in Project

1. Copy `.envrc.example` to `.envrc`:
```bash
cp .envrc.example .envrc
# Edit .envrc with your credentials
# Note: .nvmrc is already in the repository with Node.js 20
```

2. Allow direnv:
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

## Troubleshooting Native Module Build Errors

### NODE_MODULE_VERSION Mismatch
If you see errors like:
```
The module was compiled against a different Node.js version using
NODE_MODULE_VERSION 137. This version of Node.js requires
NODE_MODULE_VERSION 115.
```

This means native modules were built with a different Node version.

**Solution:**
```bash
# 1. Clean everything
rm -rf node_modules .yarn/unplugged .yarn/install-state.gz
rm -rf ~/.cache/node-gyp
rm -rf ~/Library/Caches/node-gyp

# 2. Ensure correct Node version
nvm use  # Uses .nvmrc
node --version  # Should show v20.x.x

# 3. Reinstall
yarn install
```

**Important:** Always run `yarn install` in the same terminal where you ran `nvm use` to ensure the correct Node version is used throughout the build process.

## Resources

- [Node.js Release Schedule](https://nodejs.org/en/about/previous-releases)
- [Backstage Versioning Policy](https://backstage.io/docs/overview/versioning-policy/)
- [nvm Documentation](https://github.com/nvm-sh/nvm)