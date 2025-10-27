# Migration Guide

> **Version**: Backstage v1.42.0+
> **Status**: Complete Reference
> **Last Updated**: 2025-10-27

## Overview

This guide helps you migrate from the Legacy Frontend System to the New Frontend System. The migration can be done incrementally, allowing you to adopt the new system at your own pace.

## Table of Contents

1. [Migration Overview](#migration-overview)
2. [Migration Phases](#migration-phases)
3. [Migrating the App](#migrating-the-app)
4. [Migrating Plugins](#migrating-plugins)
5. [Migrating Components](#migrating-components)
6. [Migrating Auth Providers](#migrating-auth-providers)
7. [Migrating Themes](#migrating-themes)
8. [Troubleshooting](#troubleshooting)
9. [Migration Checklist](#migration-checklist)

---

## Migration Overview

### Why Migrate?

**Benefits of the New Frontend System**:
- **Auto-discovery**: Install plugins via package.json, no manual imports
- **Configuration-driven**: Override behavior via app-config.yaml
- **Modularity**: Better separation of concerns
- **Type safety**: Stronger TypeScript integration
- **Future-proof**: Active development and new features

### Migration Strategy

**Incremental Migration**: Both systems can coexist during migration

**Two-Phase Approach**:
1. **Phase 1**: Hybrid mode - Enable new system alongside legacy
2. **Phase 2**: Full migration - Remove legacy system completely

**Timeline**: Most apps can migrate in days to weeks, depending on customizations

---

## Migration Phases

### Phase 1: Hybrid Mode

Run both systems side-by-side. This allows:
- Testing new system with minimal risk
- Gradual migration of custom plugins
- Learning new patterns

#### Enable Hybrid Mode

```typescript
// packages/app/src/App.tsx
import { createApp } from '@backstage/frontend-defaults';
import { createLegacyApp } from '@backstage/app-defaults';

// Create new frontend system app
const newApp = createApp({
  features: [
    // Auto-discover plugins with /alpha exports
  ],
  bindRoutes({ bind }) {
    bind(catalogPlugin.externalRoutes, {
      createComponent: scaffolderPlugin.routes.root,
    });
  },
});

// Keep legacy app for non-migrated parts
const legacyApp = createLegacyApp({
  apis,
  components: {
    SignInPage: /* ... */,
  },
  // ... existing configuration
});

// Export new app
export default newApp.createRoot();

// Or use legacy during migration
// export default legacyApp.createRoot();
```

Enable auto-discovery in app-config.yaml:

```yaml
app:
  packages:
    - all  # Auto-discover all plugins
```

### Phase 2: Full Migration

Once all customizations are migrated, remove legacy system:

1. Remove legacy app creation
2. Remove manual component imports
3. Clean up App.tsx
4. Update package.json dependencies

---

## Migrating the App

### Before: Legacy App

```typescript
// packages/app/src/App.tsx (Legacy)
import React from 'react';
import { Navigate, Route } from 'react-router-dom';
import { apiDocsPlugin, ApiExplorerPage } from '@backstage/plugin-api-docs';
import {
  CatalogEntityPage,
  CatalogIndexPage,
  catalogPlugin,
} from '@backstage/plugin-catalog';
import { ScaffolderPage, scaffolderPlugin } from '@backstage/plugin-scaffolder';
import { TechDocsIndexPage, TechDocsReaderPage } from '@backstage/plugin-techdocs';
import { createApp } from '@backstage/app-defaults';
import { FlatRoutes } from '@backstage/core-app-api';
import { apis } from './apis';
import { Root } from './components/Root';

const app = createApp({
  apis,
  components: {
    SignInPage: props => <SignInPage {...props} provider="github" />,
  },
  bindRoutes({ bind }) {
    bind(catalogPlugin.externalRoutes, {
      createComponent: scaffolderPlugin.routes.root,
    });
  },
});

const AppProvider = app.getProvider();
const AppRouter = app.getRouter();

const routes = (
  <FlatRoutes>
    <Route path="/" element={<Navigate to="catalog" />} />
    <Route path="/catalog" element={<CatalogIndexPage />} />
    <Route path="/catalog/:namespace/:kind/:name" element={<CatalogEntityPage />} />
    <Route path="/docs" element={<TechDocsIndexPage />} />
    <Route path="/docs/:namespace/:kind/:name/*" element={<TechDocsReaderPage />} />
    <Route path="/create" element={<ScaffolderPage />} />
    <Route path="/api-docs" element={<ApiExplorerPage />} />
  </FlatRoutes>
);

export default app.createRoot(
  <AppProvider>
    <AppRouter>
      <Root>{routes}</Root>
    </AppRouter>
  </AppProvider>
);
```

### After: New Frontend System

```typescript
// packages/app/src/App.tsx (New System)
import React from 'react';
import { createApp } from '@backstage/frontend-defaults';

const app = createApp({
  // Plugins are auto-discovered from package.json!
  // No manual imports needed if using auto-discovery

  bindRoutes({ bind }) {
    // Route bindings still needed
    bind(catalogPlugin.externalRoutes, {
      createComponent: scaffolderPlugin.routes.root,
    });
  },
});

export default app.createRoot();
```

### Configuration

Move customizations to app-config.yaml:

```yaml
app:
  # Auto-discovery
  packages:
    - all

  # Extensions can be configured
  extensions:
    - sign-in-page:app/github:
        config:
          provider: github

    # Disable unwanted extensions
    - page:some-plugin/unwanted:
        disabled: true

    # Override paths
    - page:catalog/index:
        config:
          path: /services  # Change /catalog to /services
```

---

## Migrating Plugins

### Custom Plugin Migration

#### Before: Legacy Plugin

```typescript
// plugins/my-plugin/src/plugin.ts (Legacy)
import { createPlugin, createRoutableExtension } from '@backstage/core-plugin-api';
import { rootRouteRef } from './routes';

export const myPlugin = createPlugin({
  id: 'my-plugin',
  routes: {
    root: rootRouteRef,
  },
});

export const MyPage = myPlugin.provide(
  createRoutableExtension({
    name: 'MyPage',
    component: () => import('./components/MyPage').then(m => m.MyPage),
    mountPoint: rootRouteRef,
  }),
);
```

```typescript
// plugins/my-plugin/src/index.ts (Legacy)
export { myPlugin, MyPage } from './plugin';
```

Usage in app:

```typescript
// App.tsx (Legacy)
import { MyPage } from '@internal/plugin-my-plugin';

<Route path="/my-plugin" element={<MyPage />} />
```

#### After: New Frontend System

```typescript
// plugins/my-plugin/src/plugin.ts (New System)
import { createFrontendPlugin } from '@backstage/frontend-plugin-api';
import { PageBlueprint } from '@backstage/frontend-plugin-api';
import { rootRouteRef } from './routes';

export const myPlugin = createFrontendPlugin({
  id: 'my-plugin',
  extensions: [
    PageBlueprint.make({
      name: 'root',
      params: {
        defaultPath: '/my-plugin',
        routeRef: rootRouteRef,
        loader: async () => {
          const { MyPage } = await import('./components/MyPage');
          return <MyPage />;
        },
      },
    }),
  ],
});
```

```typescript
// plugins/my-plugin/src/alpha.ts (New System)
/**
 * @alpha
 */
export { myPlugin as default } from './plugin';
```

```typescript
// plugins/my-plugin/src/index.ts (Backward compatibility)
// Keep legacy exports for backward compatibility
export { MyPage } from './components/MyPage';
```

package.json:

```json
{
  "name": "@internal/plugin-my-plugin",
  "exports": {
    ".": "./src/index.ts",
    "./alpha": "./src/alpha.ts"
  },
  "backstage": {
    "role": "frontend-plugin"
  }
}
```

No usage code needed in app - auto-discovered!

---

## Migrating Components

### SignInPage Migration

#### Before

```typescript
// App.tsx (Legacy)
import { SignInPage } from '@backstage/core-components';

const app = createApp({
  components: {
    SignInPage: props => (
      <SignInPage
        {...props}
        provider={{
          id: 'github',
          title: 'GitHub',
          message: 'Sign in using GitHub',
        }}
      />
    ),
  },
});
```

#### After

```typescript
// src/modules/sign-in.tsx (New System)
import { createFrontendModule } from '@backstage/frontend-plugin-api';
import { SignInPageBlueprint } from '@backstage/frontend-plugin-api';

export const signInModule = createFrontendModule({
  pluginId: 'app',
  extensions: [
    SignInPageBlueprint.make({
      name: 'github',
      params: {
        loader: async () => {
          const { SignInPage } = await import('@backstage/core-components');
          return (
            <SignInPage
              provider={{
                id: 'github',
                title: 'GitHub',
                message: 'Sign in using GitHub',
              }}
            />
          );
        },
      },
    }),
  ],
});
```

```typescript
// App.tsx
import { signInModule } from './modules/sign-in';

const app = createApp({
  features: [signInModule],
});
```

Or configure via app-config.yaml:

```yaml
app:
  extensions:
    - sign-in-page:app/github:
        config:
          provider:
            id: github
            title: GitHub
            message: Sign in using GitHub
```

### Root Component Migration

#### Before

```typescript
// App.tsx (Legacy)
import { Root } from './components/Root';

const routes = (
  <FlatRoutes>
    <Route path="/catalog" element={<CatalogIndexPage />} />
  </FlatRoutes>
);

export default app.createRoot(
  <AppProvider>
    <AppRouter>
      <Root>{routes}</Root>
    </AppRouter>
  </AppProvider>
);
```

#### After

The Root component is no longer needed explicitly. Layout is handled by the new system.

If you need custom layout:

```typescript
// src/modules/layout.tsx
import { createFrontendModule } from '@backstage/frontend-plugin-api';
import { createExtension, coreExtensionData } from '@backstage/frontend-plugin-api';

const customLayoutExtension = createExtension({
  id: 'app/layout',
  attachTo: { id: 'app', input: 'root' },
  output: {
    element: coreExtensionData.reactElement,
  },
  factory: () => ({
    element: <CustomRootLayout />,
  }),
});

export const layoutModule = createFrontendModule({
  pluginId: 'app',
  extensions: [customLayoutExtension],
});
```

### Sidebar Migration

#### Before

```typescript
// components/Root/Root.tsx (Legacy)
import { Sidebar, SidebarPage } from '@backstage/core-components';

export const Root = ({ children }: PropsWithChildren<{}>) => (
  <SidebarPage>
    <Sidebar>
      <SidebarLogo />
      <SidebarGroup>
        <SidebarItem icon={HomeIcon} to="/" text="Home" />
        <SidebarItem icon={CatalogIcon} to="catalog" text="Catalog" />
      </SidebarGroup>
    </Sidebar>
    {children}
  </SidebarPage>
);
```

#### After

Use NavItemBlueprint for sidebar items:

```typescript
// src/modules/navigation.tsx
import { createFrontendModule } from '@backstage/frontend-plugin-api';
import { NavItemBlueprint } from '@backstage/frontend-plugin-api';
import HomeIcon from '@material-ui/icons/Home';
import CatalogIcon from '@material-ui/icons/Category';

export const navigationModule = createFrontendModule({
  pluginId: 'app',
  extensions: [
    NavItemBlueprint.make({
      name: 'home',
      params: {
        title: 'Home',
        icon: HomeIcon,
        routeRef: rootRouteRef,
      },
    }),
    NavItemBlueprint.make({
      name: 'catalog',
      params: {
        title: 'Catalog',
        icon: CatalogIcon,
        routeRef: catalogIndexRouteRef,
      },
    }),
  ],
});
```

---

## Migrating Auth Providers

### Custom Auth Provider Migration

#### Before: Legacy System

```typescript
// packages/app/src/apis.ts (Legacy)
import {
  AnyApiFactory,
  configApiRef,
  createApiFactory,
  discoveryApiRef,
  oauthRequestApiRef,
} from '@backstage/core-plugin-api';
import { OAuth2 } from '@backstage/core-app-api';

export const apis: AnyApiFactory[] = [
  createApiFactory({
    api: customOidcAuthApiRef,
    deps: {
      configApi: configApiRef,
      discoveryApi: discoveryApiRef,
      oauthRequestApi: oauthRequestApiRef,
    },
    factory: ({ configApi, discoveryApi, oauthRequestApi }) =>
      OAuth2.create({
        configApi,
        discoveryApi,
        oauthRequestApi,
        provider: {
          id: 'custom-oidc',
          title: 'Custom OIDC',
          icon: () => null,
        },
      }),
  }),
];
```

#### After: New Frontend System

```typescript
// packages/app/src/modules/custom-auth.tsx (New System)
import { createFrontendModule } from '@backstage/frontend-plugin-api';
import { ApiBlueprint } from '@backstage/frontend-plugin-api';
import {
  configApiRef,
  discoveryApiRef,
  oauthRequestApiRef,
} from '@backstage/core-plugin-api';
import { OAuth2 } from '@backstage/core-app-api';
import { customOidcAuthApiRef } from './api';

const customOidcAuthApi = ApiBlueprint.make({
  name: 'custom-oidc-auth',
  params: {
    api: customOidcAuthApiRef,
    deps: {
      configApi: configApiRef,
      discoveryApi: discoveryApiRef,
      oauthRequestApi: oauthRequestApiRef,
    },
    factory: ({ configApi, discoveryApi, oauthRequestApi }) =>
      OAuth2.create({
        configApi,
        discoveryApi,
        oauthRequestApi,
        provider: {
          id: 'custom-oidc',
          title: 'Custom OIDC',
          icon: () => null,
        },
      }),
  },
});

export const customAuthModule = createFrontendModule({
  pluginId: 'app',
  extensions: [customOidcAuthApi],
});
```

```typescript
// App.tsx
import { customAuthModule } from './modules/custom-auth';

const app = createApp({
  features: [customAuthModule],
});
```

See [05-auth-providers.md](./05-auth-providers.md) for complete auth provider migration details.

---

## Migrating Themes

### Custom Theme Migration

#### Before

```typescript
// App.tsx (Legacy)
import { lightTheme, darkTheme } from './themes';

const app = createApp({
  themes: [
    {
      id: 'light',
      title: 'Light',
      variant: 'light',
      Provider: ({ children }) => (
        <ThemeProvider theme={lightTheme}>{children}</ThemeProvider>
      ),
    },
    {
      id: 'dark',
      title: 'Dark',
      variant: 'dark',
      Provider: ({ children }) => (
        <ThemeProvider theme={darkTheme}>{children}</ThemeProvider>
      ),
    },
  ],
});
```

#### After

```typescript
// src/modules/themes.tsx (New System)
import { createFrontendModule } from '@backstage/frontend-plugin-api';
import { ThemeBlueprint } from '@backstage/frontend-plugin-api';
import { lightTheme, darkTheme } from './themes';

export const themesModule = createFrontendModule({
  pluginId: 'app',
  extensions: [
    ThemeBlueprint.make({
      name: 'light',
      params: {
        theme: lightTheme,
      },
    }),
    ThemeBlueprint.make({
      name: 'dark',
      params: {
        theme: darkTheme,
      },
    }),
  ],
});
```

```typescript
// App.tsx
import { themesModule } from './modules/themes';

const app = createApp({
  features: [themesModule],
});
```

---

## Troubleshooting

### Common Issues

#### 1. "Cannot find module '/alpha'"

**Cause**: Plugin doesn't export `/alpha` subpath

**Solution**: Add to plugin's package.json:

```json
{
  "exports": {
    ".": "./src/index.ts",
    "./alpha": "./src/alpha.ts"
  }
}
```

Create `src/alpha.ts`:

```typescript
export { myPlugin as default } from './plugin';
```

#### 2. Plugin Not Auto-Discovered

**Cause**: Missing backstage.role in package.json

**Solution**: Add to plugin's package.json:

```json
{
  "backstage": {
    "role": "frontend-plugin"
  }
}
```

Enable auto-discovery in app-config.yaml:

```yaml
app:
  packages:
    - all
```

#### 3. Routes Not Working

**Cause**: Route bindings not migrated

**Solution**: Keep bindRoutes in createApp:

```typescript
createApp({
  bindRoutes({ bind }) {
    bind(catalogPlugin.externalRoutes, {
      createComponent: scaffolderPlugin.routes.root,
    });
  },
});
```

#### 4. Custom Components Not Rendering

**Cause**: Components not wrapped in extensions

**Solution**: Create extensions for custom components:

```typescript
const myCustomExtension = createExtension({
  id: 'page:app/custom',
  attachTo: { id: 'app/routes', input: 'routes' },
  output: {
    element: coreExtensionData.reactElement,
    path: coreExtensionData.routePath,
  },
  factory: () => ({
    element: <MyCustomComponent />,
    path: '/custom',
  }),
});
```

#### 5. APIs Not Available

**Cause**: APIs not registered in new system

**Solution**: Create API extensions:

```typescript
const myApi = ApiBlueprint.make({
  name: 'my-api',
  params: {
    api: myApiRef,
    deps: { /* ... */ },
    factory: (deps) => new MyApiImpl(deps),
  },
});
```

---

## Migration Checklist

### Phase 1: Preparation

- [ ] Update Backstage to v1.42.0+
- [ ] Review plugin dependencies
- [ ] Create backup branch
- [ ] Test current app functionality

### Phase 2: App Migration

- [ ] Replace createApp import from `@backstage/app-defaults` to `@backstage/frontend-defaults`
- [ ] Enable auto-discovery in app-config.yaml
- [ ] Remove manual route definitions
- [ ] Simplify App.tsx
- [ ] Test core functionality

### Phase 3: Plugin Migration

For each custom plugin:

- [ ] Add `exports["./alpha"]` to package.json
- [ ] Add `backstage.role: "frontend-plugin"`
- [ ] Create `src/alpha.ts` export file
- [ ] Convert plugin to createFrontendPlugin
- [ ] Convert pages to PageBlueprint
- [ ] Convert APIs to ApiBlueprint
- [ ] Test plugin functionality

### Phase 4: Component Migration

- [ ] Migrate SignInPage to SignInPageBlueprint
- [ ] Migrate themes to ThemeBlueprint
- [ ] Migrate nav items to NavItemBlueprint
- [ ] Remove Root component (or convert to extension)
- [ ] Test UI components

### Phase 5: Cleanup

- [ ] Remove legacy App configuration
- [ ] Remove unused imports
- [ ] Update documentation
- [ ] Remove `apis.ts` file
- [ ] Clean up App.tsx
- [ ] Final testing

### Phase 6: Verification

- [ ] All pages load correctly
- [ ] Authentication works
- [ ] Navigation works
- [ ] Themes switch correctly
- [ ] APIs function properly
- [ ] Entity pages render
- [ ] Search works
- [ ] TechDocs work
- [ ] Scaffolder works

---

## Migration Timeline

**Typical Timeline**:

- **Small app** (few customizations): 1-2 days
- **Medium app** (some custom plugins): 1 week
- **Large app** (many custom plugins): 2-4 weeks

**Recommended Approach**:

1. Week 1: Enable hybrid mode, test standard plugins
2. Week 2-3: Migrate custom plugins one by one
3. Week 4: Clean up, remove legacy code, full testing

---

## Getting Help

### Resources

- [Official Migration Guide](https://backstage.io/docs/frontend-system/building-apps/migrating)
- [Discord #support channel](https://discord.gg/backstage-687207715902193673)
- [GitHub Discussions](https://github.com/backstage/backstage/discussions)
- [GitHub Issues](https://github.com/backstage/backstage/issues)

### Common Questions

**Q: Can I keep both systems running?**

A: Yes, during Phase 1 (hybrid mode). Eventually migrate fully.

**Q: Do plugins need to support both systems?**

A: Ideally yes, during transition. Export both legacy and alpha.

**Q: What about community plugins?**

A: Many community plugins already support both systems. Check plugin documentation.

**Q: Can I migrate incrementally?**

A: Yes! That's the recommended approach.

---

## Summary

**Key Takeaways**:

1. **Incremental migration is supported** - Both systems can coexist
2. **Auto-discovery eliminates boilerplate** - No manual imports needed
3. **Configuration-driven** - Customize via app-config.yaml
4. **Extension-based** - Everything is an extension
5. **Backward compatible** - Plugins can support both systems

**Migration Path**:

1. Enable hybrid mode
2. Test with standard plugins
3. Migrate custom plugins
4. Migrate custom components
5. Clean up legacy code
6. Verify functionality

**Next Steps**:
- [Understand Architecture →](./01-architecture.md)
- [Learn about Extensions →](./03-extensions.md)
- [Build New Plugins →](./06-plugin-development.md)

---

**Navigation**:
- [← Previous: Plugin Development](./06-plugin-development.md)
- [Back to INDEX](./INDEX.md)
