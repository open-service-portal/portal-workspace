# Plugin Development

> **Version**: Backstage v1.42.0+
> **Status**: Complete Reference
> **Last Updated**: 2025-10-27

## Overview

This guide covers creating frontend plugins for the New Frontend System. Plugins are packages that provide extensions (pages, APIs, themes, etc.) to Backstage apps.

## Table of Contents

1. [What is a Frontend Plugin?](#what-is-a-frontend-plugin)
2. [Plugin Structure](#plugin-structure)
3. [Creating a Plugin](#creating-a-plugin)
4. [Alpha Exports](#alpha-exports)
5. [Providing Extensions](#providing-extensions)
6. [Plugin Configuration](#plugin-configuration)
7. [Frontend Modules](#frontend-modules)
8. [Publishing Plugins](#publishing-plugins)
9. [Best Practices](#best-practices)

---

## What is a Frontend Plugin?

A frontend plugin is a **collection of extensions** packaged as an npm module. Plugins:

- Provide one or more extensions (pages, APIs, nav items, etc.)
- Can be installed via `package.json`
- Are automatically discovered by the app
- Can be configured via `app-config.yaml`
- Are independently versioned and published

### Plugin vs Extension vs Module

- **Extension**: Single unit of functionality (page, API, theme)
- **Plugin**: Collection of extensions from a single package
- **Frontend Module**: Extension to an existing plugin without modifying it

---

## Plugin Structure

### Directory Layout

```
packages/
└── my-plugin/
    ├── package.json
    ├── src/
    │   ├── index.ts              # Public API (legacy components)
    │   ├── alpha.ts              # New frontend system exports
    │   ├── plugin.ts             # Plugin definition
    │   ├── routes.ts             # Route refs
    │   ├── components/           # React components
    │   │   ├── MyPage/
    │   │   └── MyWidget/
    │   └── api/                  # API definitions
    │       ├── types.ts
    │       └── MyApiClient.ts
    ├── dev/
    │   └── index.tsx             # Dev environment
    └── README.md
```

### package.json

```json
{
  "name": "@backstage-community/plugin-my-plugin",
  "version": "1.0.0",
  "main": "src/index.ts",
  "types": "src/index.ts",
  "exports": {
    ".": "./src/index.ts",
    "./alpha": "./src/alpha.ts",
    "./package.json": "./package.json"
  },
  "backstage": {
    "role": "frontend-plugin"
  },
  "dependencies": {
    "@backstage/core-components": "^0.15.0",
    "@backstage/core-plugin-api": "^1.10.0",
    "@backstage/frontend-plugin-api": "^0.9.0",
    "react": "^18.0.0"
  },
  "peerDependencies": {
    "react": "^18.0.0"
  }
}
```

**Key Points**:
- `exports` field includes `/alpha` subpath
- `backstage.role` identifies plugin type
- Both legacy and new frontend system dependencies

---

## Creating a Plugin

### Using Backstage CLI

```bash
# From workspace root
yarn backstage-cli create --select plugin

# Or with new frontend plugin template
yarn backstage-cli create --select plugin --option id=my-plugin
```

### Manual Plugin Creation

#### 1. Create Plugin Definition

```typescript
// src/plugin.ts
import { createFrontendPlugin } from '@backstage/frontend-plugin-api';
import { myPageExtension } from './extensions';

export const myPlugin = createFrontendPlugin({
  id: 'my-plugin',
  extensions: [
    myPageExtension,
    // More extensions...
  ],
});
```

#### 2. Create Extensions

```typescript
// src/extensions.ts
import { PageBlueprint } from '@backstage/frontend-plugin-api';

export const myPageExtension = PageBlueprint.make({
  name: 'my-page',
  params: {
    defaultPath: '/my-plugin',
    loader: async () => {
      const { MyPage } = await import('./components/MyPage');
      return <MyPage />;
    },
  },
});
```

#### 3. Create Alpha Exports

```typescript
// src/alpha.ts
export { myPlugin as default } from './plugin';
export { myPageExtension } from './extensions';
```

#### 4. Create Page Component

```typescript
// src/components/MyPage/MyPage.tsx
import React from 'react';
import { Header, Page, Content } from '@backstage/core-components';

export const MyPage = () => {
  return (
    <Page themeId="tool">
      <Header title="My Plugin" subtitle="Welcome to my plugin" />
      <Content>
        <div>Hello from My Plugin!</div>
      </Content>
    </Page>
  );
};
```

---

## Alpha Exports

The `/alpha` subpath is where new frontend system exports live.

### Why Alpha Exports?

- **Separation**: Keep new system exports separate from legacy
- **Compatibility**: Support both systems during migration
- **Discovery**: Apps can auto-discover alpha exports
- **Versioning**: Signal that APIs may change

### Alpha Export Structure

```typescript
// src/alpha.ts

/**
 * @alpha
 * Frontend plugin for My Plugin
 */
export { myPlugin as default } from './plugin';

/**
 * @alpha
 * Extensions provided by this plugin
 */
export { myPageExtension, myWidgetExtension } from './extensions';

/**
 * @alpha
 * API definitions
 */
export { myApiRef, type MyApi } from './api';

/**
 * @alpha
 * Utility components (if needed by app customizations)
 */
export { MyCustomComponent } from './components';
```

### Importing Alpha Exports

```typescript
// In app
import myPlugin from '@backstage-community/plugin-my-plugin/alpha';

createApp({
  features: [myPlugin],
});
```

### Auto-Discovery of Alpha Exports

Enable in app-config.yaml:

```yaml
app:
  packages:
    - all  # Auto-discover all plugins with /alpha exports
```

With auto-discovery, no manual imports needed!

---

## Providing Extensions

Plugins can provide multiple types of extensions.

### Multiple Page Extensions

```typescript
export const myPlugin = createFrontendPlugin({
  id: 'my-plugin',
  extensions: [
    // Main index page
    PageBlueprint.make({
      name: 'index',
      params: {
        defaultPath: '/my-plugin',
        loader: async () => import('./pages/IndexPage').then(m => <m.IndexPage />),
      },
    }),

    // Detail page
    PageBlueprint.make({
      name: 'detail',
      params: {
        defaultPath: '/my-plugin/:id',
        loader: async () => import('./pages/DetailPage').then(m => <m.DetailPage />),
      },
    }),

    // Settings page
    PageBlueprint.make({
      name: 'settings',
      params: {
        defaultPath: '/my-plugin/settings',
        loader: async () => import('./pages/SettingsPage').then(m => <m.SettingsPage />),
      },
    }),
  ],
});
```

### Providing APIs

```typescript
import { ApiBlueprint } from '@backstage/frontend-plugin-api';
import { myApiRef, MyApiClient } from './api';

export const myApiExtension = ApiBlueprint.make({
  name: 'my-api',
  params: {
    api: myApiRef,
    deps: {
      discoveryApi: discoveryApiRef,
      fetchApi: fetchApiRef,
    },
    factory: ({ discoveryApi, fetchApi }) =>
      new MyApiClient({ discoveryApi, fetchApi }),
  },
});

export const myPlugin = createFrontendPlugin({
  id: 'my-plugin',
  extensions: [
    myPageExtension,
    myApiExtension,  // Provide API
  ],
});
```

### Providing Nav Items

```typescript
import { NavItemBlueprint } from '@backstage/frontend-plugin-api';
import ExtensionIcon from '@material-ui/icons/Extension';

export const myNavItemExtension = NavItemBlueprint.make({
  name: 'my-plugin',
  params: {
    title: 'My Plugin',
    icon: ExtensionIcon,
    routeRef: myRouteRef,
  },
});

export const myPlugin = createFrontendPlugin({
  id: 'my-plugin',
  extensions: [
    myPageExtension,
    myNavItemExtension,  // Add to sidebar
  ],
});
```

### Providing Entity Cards

```typescript
import { createExtension, coreExtensionData } from '@backstage/frontend-plugin-api';

export const myEntityCardExtension = createExtension({
  id: 'entity-card:my-plugin/overview',
  attachTo: { id: 'page:catalog/entity', input: 'cards' },
  output: {
    element: coreExtensionData.reactElement,
  },
  factory: () => ({
    element: <MyEntityCard />,
  }),
});

export const myPlugin = createFrontendPlugin({
  id: 'my-plugin',
  extensions: [
    myEntityCardExtension,  // Show on entity pages
  ],
});
```

---

## Plugin Configuration

Plugins can be configured via app-config.yaml.

### Reading Configuration in Components

```typescript
import { useApi, configApiRef } from '@backstage/core-plugin-api';

export const MyPage = () => {
  const configApi = useApi(configApiRef);
  const apiUrl = configApi.getString('myPlugin.apiUrl');
  const refreshInterval = configApi.getOptionalNumber('myPlugin.refreshInterval') ?? 60;

  // Use configuration...
};
```

### Configuration in API Implementations

```typescript
export class MyApiClient implements MyApi {
  private readonly baseUrl: string;
  private readonly timeout: number;

  constructor(options: {
    configApi: ConfigApi;
    fetchApi: FetchApi;
  }) {
    this.baseUrl = options.configApi.getString('myPlugin.apiUrl');
    this.timeout = options.configApi.getOptionalNumber('myPlugin.timeout') ?? 30000;
  }
}
```

### Extension Configuration Schema

```typescript
import { createSchemaFromZod } from '@backstage/frontend-plugin-api';

export const myPageExtension = PageBlueprint.make({
  name: 'index',
  params: {
    defaultPath: '/my-plugin',
    loader: async () => <MyPage />,
  },
  configSchema: createSchemaFromZod((z) =>
    z.object({
      showWelcome: z.boolean().default(true),
      itemsPerPage: z.number().default(20),
    }),
  ),
});
```

App users can configure:

```yaml
app:
  extensions:
    - page:my-plugin/index:
        config:
          showWelcome: false
          itemsPerPage: 50
```

---

## Frontend Modules

Frontend modules extend existing plugins without modifying them.

### What Are Frontend Modules?

- Add extensions to existing plugins
- Override plugin defaults
- Customize plugin behavior
- No need to fork the plugin

### Creating a Frontend Module

```typescript
import { createFrontendModule } from '@backstage/frontend-plugin-api';
import { PageBlueprint } from '@backstage/frontend-plugin-api';

export const catalogCustomPage = createFrontendModule({
  pluginId: 'catalog',  // Extends catalog plugin
  extensions: [
    PageBlueprint.make({
      name: 'custom-view',
      params: {
        defaultPath: '/catalog/custom',
        loader: async () => <CustomCatalogView />,
      },
    }),
  ],
});
```

### Module Export Structure

```typescript
// src/alpha.ts
export { catalogCustomPage as default } from './module';
```

### Installing Frontend Modules

```typescript
import catalogCustomPage from './modules/catalog-custom-page/alpha';

createApp({
  features: [
    catalogCustomPage,  // Install module
  ],
});
```

Or with auto-discovery:

```yaml
app:
  packages:
    - all  # Discovers modules automatically
```

---

## Publishing Plugins

### Package Configuration

Ensure your package.json is properly configured:

```json
{
  "name": "@backstage-community/plugin-my-plugin",
  "version": "1.0.0",
  "publishConfig": {
    "access": "public"
  },
  "repository": {
    "type": "git",
    "url": "https://github.com/backstage/community-plugins",
    "directory": "workspaces/my-plugin/plugins/my-plugin"
  },
  "exports": {
    ".": "./src/index.ts",
    "./alpha": "./src/alpha.ts",
    "./package.json": "./package.json"
  },
  "files": [
    "dist",
    "config.d.ts"
  ],
  "backstage": {
    "role": "frontend-plugin"
  }
}
```

### Build Configuration

```json
{
  "scripts": {
    "build": "backstage-cli package build",
    "clean": "backstage-cli package clean",
    "lint": "backstage-cli package lint",
    "test": "backstage-cli package test",
    "prepack": "backstage-cli package prepack",
    "postpack": "backstage-cli package postpack"
  }
}
```

### Documentation

Create comprehensive README.md:

```markdown
# My Plugin

## Installation

```bash
yarn add @backstage-community/plugin-my-plugin
```

## Configuration

Add to your `app-config.yaml`:

```yaml
myPlugin:
  apiUrl: https://api.example.com
```

## Usage

### New Frontend System

The plugin is automatically discovered if you have plugin auto-discovery enabled:

```yaml
app:
  packages:
    - all
```

Or manually install:

```typescript
import myPlugin from '@backstage-community/plugin-my-plugin/alpha';

createApp({
  features: [myPlugin],
});
```

### Legacy Frontend System

```typescript
// packages/app/src/App.tsx
import { MyPage } from '@backstage-community/plugin-my-plugin';

const routes = (
  <FlatRoutes>
    <Route path="/my-plugin" element={<MyPage />} />
  </FlatRoutes>
);
```

## Features

- Feature 1
- Feature 2
```

### Publishing to npm

```bash
# Build the plugin
yarn build

# Publish to npm
npm publish

# Or with Backstage CLI
yarn backstage-cli package publish
```

---

## Best Practices

### 1. Support Both Systems

Support both legacy and new frontend systems during the transition period:

```typescript
// src/index.ts - Legacy exports
export { MyPage, MyWidget } from './components';
export { myApiRef, type MyApi } from './api';

// src/alpha.ts - New system exports
export { myPlugin as default } from './plugin';
export { myPageExtension } from './extensions';
```

### 2. Lazy Load Components

Always use dynamic imports for component loading:

```typescript
// Good
loader: async () => {
  const { MyPage } = await import('./components/MyPage');
  return <MyPage />;
}

// Avoid
loader: async () => <MyPage />  // MyPage imported at top level
```

### 3. Provide Clear Extension Names

```typescript
// Good - Clear, descriptive names
PageBlueprint.make({ name: 'overview' })
PageBlueprint.make({ name: 'entity-detail' })
PageBlueprint.make({ name: 'settings' })

// Avoid - Generic names
PageBlueprint.make({ name: 'page1' })
PageBlueprint.make({ name: 'page2' })
```

### 4. Document Extensions

```typescript
/**
 * Main overview page for My Plugin
 *
 * @alpha
 * Extension ID: page:my-plugin/overview
 * Default path: /my-plugin
 */
export const overviewPageExtension = PageBlueprint.make({
  name: 'overview',
  params: { /* ... */ },
});
```

### 5. Use Semantic Versioning

- **Major**: Breaking changes
- **Minor**: New features, backward compatible
- **Patch**: Bug fixes

### 6. Provide Migration Guide

Help users migrate from legacy to new system:

```markdown
## Migration from Legacy to New Frontend System

### Before (Legacy)

```typescript
import { MyPage } from '@backstage-community/plugin-my-plugin';

<Route path="/my-plugin" element={<MyPage />} />
```

### After (New System)

```typescript
// Auto-discovered, or:
import myPlugin from '@backstage-community/plugin-my-plugin/alpha';
createApp({ features: [myPlugin] });
```
```

### 7. Test Plugin Installation

Test that your plugin works when installed in a fresh Backstage app:

```bash
# Create test app
npx @backstage/create-app@latest --next test-app

# Add your plugin
cd test-app
yarn add @backstage-community/plugin-my-plugin

# Test auto-discovery
yarn dev
```

### 8. Minimize Dependencies

Only include necessary dependencies:

```json
{
  "dependencies": {
    "@backstage/core-components": "^0.15.0",
    "@backstage/core-plugin-api": "^1.10.0",
    "@backstage/frontend-plugin-api": "^0.9.0"
  },
  "peerDependencies": {
    "react": "^18.0.0"
  }
}
```

Avoid heavy libraries if possible.

---

## Common Patterns

### Pattern 1: Plugin with Multiple Features

```typescript
export const myPlugin = createFrontendPlugin({
  id: 'my-plugin',
  extensions: [
    // Pages
    overviewPage,
    detailPage,
    settingsPage,

    // Navigation
    navItem,

    // APIs
    myApi,

    // Entity extensions
    entityCard,
    entityContent,
  ],
});
```

### Pattern 2: Configurable Plugin

```typescript
export const myPlugin = createFrontendPlugin({
  id: 'my-plugin',
  extensions: [
    PageBlueprint.make({
      name: 'index',
      params: {
        defaultPath: '/my-plugin',
        loader: async () => <MyPage />,
      },
      configSchema: createSchemaFromZod((z) =>
        z.object({
          features: z.object({
            analytics: z.boolean().default(true),
            notifications: z.boolean().default(false),
          }),
        }),
      ),
    }),
  ],
});
```

### Pattern 3: Plugin with Optional Extensions

```typescript
export const myPlugin = createFrontendPlugin({
  id: 'my-plugin',
  extensions: [
    // Always included
    mainPage,

    // Conditionally included
    process.env.NODE_ENV === 'development' && devToolsPage,

    // Optional based on config
    experimentalFeature,
  ].filter(Boolean),
});
```

### Pattern 4: Plugin Extending Another Plugin

```typescript
// Extending the catalog plugin
export const catalogEnhancementsModule = createFrontendModule({
  pluginId: 'catalog',
  extensions: [
    // Add custom entity card
    createExtension({
      id: 'entity-card:catalog-enhancements/metrics',
      attachTo: { id: 'page:catalog/entity', input: 'cards' },
      output: { element: coreExtensionData.reactElement },
      factory: () => ({ element: <MetricsCard /> }),
    }),
  ],
});
```

---

## Troubleshooting

### Plugin Not Discovered

**Symptom**: Plugin not loading automatically

**Solutions**:
1. Check `exports` field includes `./alpha`
2. Verify `backstage.role: "frontend-plugin"` in package.json
3. Ensure plugin is installed in package.json dependencies
4. Check app-config.yaml has `app.packages: [all]`
5. Restart dev server

### Extension Not Appearing

**Symptom**: Extension registered but not visible

**Solutions**:
1. Check extension is in plugin's `extensions` array
2. Verify extension ID doesn't conflict
3. Check `attachTo` points to valid parent
4. Ensure extension isn't disabled in app-config.yaml

### Type Errors with Alpha Exports

**Symptom**: TypeScript errors when importing `/alpha`

**Solutions**:
1. Add `./alpha` to `exports` in package.json
2. Ensure alpha.ts exists and exports plugin
3. Check TypeScript version compatibility
4. Verify `@backstage/frontend-plugin-api` version

---

## Summary

**Key Takeaways**:

1. **Plugins are collections of extensions** - Pages, APIs, nav items, etc.
2. **Use /alpha exports** - Separate new frontend system from legacy
3. **Support auto-discovery** - Configure package.json correctly
4. **Provide clear documentation** - Help users install and configure
5. **Test thoroughly** - Test in fresh Backstage apps
6. **Follow semantic versioning** - Help users manage updates

**Next Steps**:
- [Learn about Migration →](./07-migration.md)
- [Understand Extensions →](./03-extensions.md)
- [Explore Auth Providers →](./05-auth-providers.md)

---

**Navigation**:
- [← Previous: Auth Providers](./05-auth-providers.md)
- [Next: Migration Guide →](./07-migration.md)
- [Back to INDEX](./INDEX.md)
