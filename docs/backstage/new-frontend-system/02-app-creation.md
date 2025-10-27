# App Creation & Configuration

> **Complete guide to creating and configuring Backstage apps with the new frontend system**

## Table of Contents

- [Overview](#overview)
- [Creating an App](#creating-an-app)
- [Feature Installation](#feature-installation)
- [Feature Discovery](#feature-discovery)
- [App Configuration](#app-configuration)
- [Plugin Info Resolution](#plugin-info-resolution)
- [Common Patterns](#common-patterns)

---

## Overview

In the new frontend system, creating an app is straightforward:

```typescript
import { createApp } from '@backstage/frontend-defaults';

const app = createApp({
  features: [/* plugins and modules */],
});

export default app.createRoot();
```

The app:
- Wires extensions into a tree
- Provides built-in extensions (routing, APIs, themes)
- Handles feature discovery
- Renders the final React application

---

## Creating an App

### Basic App

**File**: `packages/app/src/App.tsx`

```typescript
import { createApp } from '@backstage/frontend-defaults';

const app = createApp({
  features: [],  // Empty to start
});

export default app.createRoot();
```

### With Features

```typescript
import { createApp } from '@backstage/frontend-defaults';
import catalogPlugin from '@backstage/plugin-catalog/alpha';
import scaffolderPlugin from '@backstage/plugin-scaffolder/alpha';

const app = createApp({
  features: [
    catalogPlugin,
    scaffolderPlugin,
  ],
});

export default app.createRoot();
```

### App Entry Point

**File**: `packages/app/src/index.tsx`

```typescript
import '@backstage/cli/asset-types';
import ReactDOM from 'react-dom/client';
import app from './App';

ReactDOM.createRoot(document.getElementById('root')!).render(app);
```

**Key Change**: `app.createRoot()` returns a **React element**, not a component.

---

## Feature Installation

### What Are Features?

Features are plugins or modules that provide extensions:

```typescript
// A plugin is a feature
import catalogPlugin from '@backstage/plugin-catalog/alpha';

// A module is a feature
import customModule from './modules/custom';

const app = createApp({
  features: [
    catalogPlugin,  // Plugin feature
    customModule,   // Module feature
  ],
});
```

### Types of Features

**1. Plugins**
- Complete features (pages, APIs, components)
- Exported from packages
- Usually from npm or internal

```typescript
import catalogPlugin from '@backstage/plugin-catalog/alpha';
import scaffolderPlugin from '@backstage/plugin-scaffolder/alpha';
```

**2. Frontend Modules**
- Extensions that augment plugins
- Created with `createFrontendModule()`
- Can be app-specific or shared

```typescript
import { createFrontendModule } from '@backstage/frontend-plugin-api';

const myModule = createFrontendModule({
  pluginId: 'app',
  extensions: [/* ... */],
});
```

**3. Converted Legacy Features**
- Created with `convertLegacyAppRoot()`
- Used during migration
- Should be temporary

```typescript
import { convertLegacyAppRoot } from '@backstage/core-compat-api';

const legacyFeatures = convertLegacyAppRoot(<Route>...</Route>);
```

### Installation Order

Features are processed **in order**:

```typescript
const app = createApp({
  features: [
    defaultFeature,   // Loaded first
    customOverride,   // Can override default
  ],
});
```

**Why Order Matters**:
- Extensions with same ID: last wins
- Dependencies must come before dependents
- Override order determines priority

---

## Feature Discovery

### Automatic Plugin Discovery

Instead of manually importing plugins, enable automatic discovery:

**Configuration**:
```yaml
# app-config.yaml
app:
  packages: all  # Discover all compatible packages
```

**How It Works**:
1. CLI scans `package.json` dependencies at build time
2. Finds packages with Backstage plugin exports
3. Automatically imports and installs them
4. No manual code changes needed

**Result**: Just add plugins to `package.json`:

```bash
yarn add @backstage/plugin-techdocs
# Plugin automatically available in app!
```

### Discovery Filters

**Include Specific Packages**:
```yaml
app:
  packages:
    include:
      - '@backstage/plugin-catalog'
      - '@backstage/plugin-scaffolder'
      - '@internal/*'
```

**Exclude Specific Packages**:
```yaml
app:
  packages:
    exclude:
      - '@backstage/plugin-kubernetes'
```

**Combine Both**:
```yaml
app:
  packages:
    include:
      - '@backstage/*'
    exclude:
      - '@backstage/plugin-kubernetes'
```

### Manual vs Automatic

**Manual Installation** (explicit):
```typescript
import catalogPlugin from '@backstage/plugin-catalog/alpha';

const app = createApp({
  features: [catalogPlugin],
});
```

**Automatic Discovery** (implicit):
```yaml
# Just enable in config
app:
  packages: all
```

```typescript
// No imports needed!
const app = createApp({
  features: [],  // Empty, but plugins discovered
});
```

**When to Use Which**:
- **Manual**: Control load order, custom configuration, development
- **Automatic**: Production, cleaner code, easier maintenance

### Deduplication

If a plugin is both manually imported AND discovered:
- Only one instance is loaded
- Manual import takes precedence
- Plugin IDs must match

---

## App Configuration

### createApp Options

```typescript
interface CreateAppOptions {
  // Features to install
  features?: FrontendFeature[];

  // Config loader (custom config loading)
  configLoader?: () => Promise<{ config: ConfigApi }>;

  // Bind routes between plugins
  bindRoutes?: (context: { bind: BindRoutesFunc }) => void;

  // Plugin info resolver (customize plugin metadata)
  pluginInfoResolver?: FrontendPluginInfoResolver;
}
```

### configLoader

Custom configuration loading:

```typescript
import { ConfigReader } from '@backstage/core-app-api';

const app = createApp({
  async configLoader() {
    // Load configs from custom source
    const configs = await loadCustomConfigs();

    // Return ConfigApi instance
    return {
      config: ConfigReader.fromConfigs(configs),
    };
  },
});
```

**Use Cases**:
- Load config from custom backend
- Merge multiple config sources
- Dynamic configuration

### bindRoutes

Link external routes between plugins:

```typescript
import { createApp } from '@backstage/frontend-defaults';

const app = createApp({
  bindRoutes({ bind }) {
    // Bind catalog's "create" route to scaffolder
    bind(catalogPlugin.externalRoutes, {
      createComponent: scaffolderPlugin.routes.root,
    });

    // Bind API docs to catalog entities
    bind(apiDocsPlugin.externalRoutes, {
      registerApi: catalogImportPlugin.routes.importPage,
    });
  },
});
```

**Alternative**: Use static config:
```yaml
app:
  routes:
    bindings:
      catalog.createComponent: scaffolder.root
```

---

## Plugin Info Resolution

### What is Plugin Info?

Metadata about plugins shown to users and admins:

```typescript
interface FrontendPluginInfo {
  id: string;                    // Plugin ID
  title?: string;                // Display name
  description?: string;          // Description
  version?: string;              // Version
  homepage?: string;             // Homepage URL
  ownerEntityRefs?: string[];    // Owners in catalog
  links?: Array<{                // Related links
    title: string;
    url: string;
  }>;
  slackChannel?: string;         // Support channel (custom field)
}
```

### Default Resolution

By default, info is extracted from:
- `package.json` (version, description, homepage)
- Plugin manifest (if provided)

### Custom Resolution

**Extend Plugin Info Type**:
```typescript
// File: packages/app/src/pluginInfoResolver.ts
declare module '@backstage/frontend-plugin-api' {
  interface FrontendPluginInfo {
    slackChannel?: string;
    team?: string;
  }
}
```

**Create Custom Resolver**:
```typescript
import { createPluginInfoResolver } from '@backstage/frontend-plugin-api';
import type { Entity } from '@backstage/catalog-model';

export const pluginInfoResolver = createPluginInfoResolver(async ctx => {
  // Get default info
  const { info } = await ctx.defaultResolver({
    packageJson: await ctx.packageJson(),
    manifest: await ctx.manifest(),
  });

  // Enhance with custom data
  const manifest = (await ctx.manifest()) as Entity | undefined;
  const slackChannel = manifest?.metadata?.annotations?.['slack.com/channel'];

  if (slackChannel) {
    info.slackChannel = slackChannel;
    info.links = [
      ...(info.links ?? []),
      {
        title: 'Slack Support',
        url: `https://slack.com/app_redirect?channel=${slackChannel}`,
      },
    ];
  }

  return { info };
});
```

**Install in App**:
```typescript
import { pluginInfoResolver } from './pluginInfoResolver';

const app = createApp({
  pluginInfoResolver,
  features: [/* ... */],
});
```

### Override Plugin Info

**Via Configuration**:
```yaml
# app-config.yaml
app:
  pluginOverrides:
    - match:
        pluginId: catalog
      info:
        ownerEntityRefs: [team:platform]
        slackChannel: C12345678

    - match:
        packageName: /@internal/.*/  # Regex pattern
      info:
        ownerEntityRefs: [team:internal-tools]
```

**Match Criteria**:
- `pluginId`: Exact plugin ID
- `packageName`: Package name (supports regex)

---

## Common Patterns

### Pattern 1: Minimal App

```typescript
import { createApp } from '@backstage/frontend-defaults';

// Simplest possible app
const app = createApp({
  features: [],
});

export default app.createRoot();
```

```yaml
# Enable discovery
app:
  packages: all
```

**Result**: All installed plugins automatically loaded.

---

### Pattern 2: Explicit Features

```typescript
import { createApp } from '@backstage/frontend-defaults';
import catalogPlugin from '@backstage/plugin-catalog/alpha';
import scaffolderPlugin from '@backstage/plugin-scaffolder/alpha';
import techdocsPlugin from '@backstage/plugin-techdocs/alpha';

const app = createApp({
  features: [
    catalogPlugin,
    scaffolderPlugin,
    techdocsPlugin,
  ],
});

export default app.createRoot();
```

**When to Use**: Development, controlled environments, custom plugin order.

---

### Pattern 3: Mixed Manual + Discovery

```typescript
import { createApp } from '@backstage/frontend-defaults';
import customModule from './modules/custom';

const app = createApp({
  features: [
    customModule,  // Manual: app-specific module
    // Other plugins: discovered automatically
  ],
});

export default app.createRoot();
```

```yaml
app:
  packages: all  # Discover standard plugins
```

**Best of Both**: Custom features manually, standard plugins discovered.

---

### Pattern 4: Plugin Overrides

```typescript
import { createApp } from '@backstage/frontend-defaults';
import catalogPlugin from '@backstage/plugin-catalog/alpha';

// Override catalog index page
const customCatalogPage = catalogPlugin
  .getExtension('page:catalog/index')
  .override({
    params: {
      loader: async () => <CustomCatalogPage />,
    },
  });

const app = createApp({
  features: [
    catalogPlugin.withOverrides({
      extensions: [customCatalogPage],
    }),
  ],
});

export default app.createRoot();
```

---

### Pattern 5: App with Custom Modules

```typescript
// File: packages/app/src/modules/customAuth/index.ts
import { createFrontendModule } from '@backstage/frontend-plugin-api';
import { myAuthApi } from './myAuthApi';

export const authModule = createFrontendModule({
  pluginId: 'app',
  extensions: [myAuthApi],
});
```

```typescript
// File: packages/app/src/App.tsx
import { createApp } from '@backstage/frontend-defaults';
import { authModule } from './modules/customAuth';

const app = createApp({
  features: [
    authModule,  // App-specific auth
    // Other features...
  ],
});

export default app.createRoot();
```

---

### Pattern 6: Multi-Environment Setup

```typescript
// File: packages/app/src/App.tsx
import { createApp } from '@backstage/frontend-defaults';
import { getEnvFeatures } from './features';

const app = createApp({
  features: getEnvFeatures(),
});

export default app.createRoot();
```

```typescript
// File: packages/app/src/features.ts
import devModule from './modules/dev';
import prodModule from './modules/prod';

export function getEnvFeatures() {
  const baseFeatures = [
    // Common features
  ];

  if (process.env.NODE_ENV === 'development') {
    return [...baseFeatures, devModule];
  }

  return [...baseFeatures, prodModule];
}
```

---

## Configuration Examples

### Basic App Config

```yaml
# app-config.yaml
app:
  title: My Backstage App
  baseUrl: http://localhost:3000

  # Enable feature discovery
  packages: all

backend:
  baseUrl: http://localhost:7007
  listen:
    port: 7007
  cors:
    origin: http://localhost:3000
    credentials: true
```

### With Extension Configuration

```yaml
app:
  # Enable discovery
  packages: all

  # Configure extensions
  extensions:
    # Disable search
    - page:search: false

    # Configure catalog pagination
    - page:catalog/index:
        config:
          pagination:
            limit: 50

    # Configure theme
    - theme:light:
        config:
          primaryColor: '#1976d2'
```

### With Plugin Overrides

```yaml
app:
  packages: all

  # Override plugin info
  pluginOverrides:
    - match:
        pluginId: catalog
      info:
        title: Service Catalog
        ownerEntityRefs: [team:platform]

    - match:
        packageName: /@internal/.*/
      info:
        ownerEntityRefs: [team:internal-tools]
```

### With Route Bindings

```yaml
app:
  packages: all

  routes:
    bindings:
      # Bind catalog's create route to scaffolder
      catalog.createComponent: scaffolder.root

      # Bind API docs to catalog import
      api-docs.registerApi: catalog-import.importPage
```

---

## Testing Your App

### Development

```bash
# Start backend
yarn start-backend

# Start frontend (in another terminal)
yarn start

# Open browser
open http://localhost:3000
```

### Verify Features

1. **Check plugins loaded**:
   - Install app-visualizer: `yarn add @backstage/plugin-app-visualizer`
   - Navigate to `/visualizer`
   - See extension tree and installed plugins

2. **Check console**:
   ```
   [App] Loading features...
   [App] Discovered plugins: catalog, scaffolder, techdocs
   [App] Extension tree built: 47 extensions
   [App] App ready
   ```

3. **Check routes**:
   - Navigate to plugin pages
   - Verify routing works
   - Check navigation items

### Production Build

```bash
# Build frontend
yarn build

# Serve static files
yarn serve:frontend

# Or build Docker image
yarn build-image
```

---

## Troubleshooting

### Plugins Not Loading

**Problem**: Plugins installed but not appearing

**Solutions**:
1. **Check discovery enabled**:
   ```yaml
   app:
     packages: all  # Must be present
   ```

2. **Check package.json**:
   ```json
   {
     "dependencies": {
       "@backstage/plugin-catalog": "^1.42.0"
     }
   }
   ```

3. **Rebuild**:
   ```bash
   yarn install
   yarn start
   ```

4. **Check excludes**:
   ```yaml
   app:
     packages:
       exclude:
         - '@backstage/plugin-catalog'  # Remove if present
   ```

### Features Not Applying

**Problem**: Manual features not working

**Solutions**:
1. **Check import path**:
   ```typescript
   // Correct
   import plugin from '@backstage/plugin-catalog/alpha';

   // Wrong
   import plugin from '@backstage/plugin-catalog';
   ```

2. **Check features array**:
   ```typescript
   const app = createApp({
     features: [plugin],  // Must be in array
   });
   ```

3. **Check plugin ID conflicts**:
   - Use `/visualizer` to see loaded plugins
   - Check for duplicate IDs

### Extension Overrides Not Working

**Problem**: Override not applying

**Solutions**:
1. **Check extension ID**:
   ```typescript
   // Get exact ID from visualizer
   const ext = plugin.getExtension('page:catalog/index');
   ```

2. **Check order**:
   ```typescript
   const app = createApp({
     features: [
       basePlugin,      // First
       overrideModule,  // Second (overrides basePlugin)
     ],
   });
   ```

3. **Check override syntax**:
   ```typescript
   plugin.withOverrides({
     extensions: [overrideExt],  // Must be array
   })
   ```

---

## Summary

### Key Points

1. **App Creation**: Use `createApp()` from `@backstage/frontend-defaults`
2. **Features**: Plugins and modules provide extensions
3. **Discovery**: Auto-install plugins from package.json
4. **Configuration**: Configure extensions via app-config.yaml
5. **Plugin Info**: Customize plugin metadata
6. **Order Matters**: Features processed in order, last wins for conflicts

### Best Practices

✅ **Use Feature Discovery** in production for cleaner code
✅ **Manual Install** for development and custom features
✅ **Configure via YAML** instead of code when possible
✅ **Use Visualizer** (`/visualizer`) to debug extension tree
✅ **Version Lock** plugins in production
✅ **Test Locally** before deploying

### Next Steps

- **[03-extensions.md](./03-extensions.md)** - Learn about extensions in detail
- **[04-utility-apis.md](./04-utility-apis.md)** - Understand utility APIs
- **[06-plugin-development.md](./06-plugin-development.md)** - Build your own plugins

---

**Navigation**:
- [← Previous: Architecture](./01-architecture.md)
- [Next: Extensions →](./03-extensions.md)
- [Back to INDEX](./INDEX.md)
