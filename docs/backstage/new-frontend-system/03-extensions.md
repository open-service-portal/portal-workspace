# Extensions Deep Dive

> **Version**: Backstage v1.42.0+
> **Status**: Complete Reference
> **Last Updated**: 2025-10-27

## Overview

Extensions are the fundamental building blocks of the New Frontend System. Everything in a Backstage app - pages, APIs, themes, nav items, and more - is represented as an extension. This document provides a comprehensive guide to understanding, creating, and configuring extensions.

## Table of Contents

1. [What Are Extensions?](#what-are-extensions)
2. [Extension Structure](#extension-structure)
3. [Creating Extensions](#creating-extensions)
4. [Extension Blueprints](#extension-blueprints)
5. [Extension Data References](#extension-data-references)
6. [Inputs and Outputs](#inputs-and-outputs)
7. [Configuration Schemas](#configuration-schemas)
8. [Extension Overrides](#extension-overrides)
9. [Best Practices](#best-practices)

---

## What Are Extensions?

Extensions are **declarative units of functionality** that form a tree structure in your Backstage app. Each extension:

- Has a unique ID
- Declares inputs (what it needs from other extensions)
- Produces outputs (what it provides to parent extensions)
- Can be configured via app-config.yaml
- Can be overridden without modifying source code

### Extension Tree

The extension tree starts with a root `app` extension and branches out to plugins, pages, APIs, and other features:

```
app
├── apis
│   ├── api:app/github-auth
│   ├── api:app/config
│   └── api:app/discovery
├── plugins
│   ├── plugin:catalog
│   │   ├── page:catalog/index
│   │   └── page:catalog/entity
│   └── plugin:scaffolder
│       └── page:scaffolder/templates
└── themes
    ├── theme:app/light
    └── theme:app/dark
```

### Why Extensions?

**Modularity**: Each extension is self-contained and reusable

**Composability**: Extensions can be combined in different ways

**Configuration**: Behavior can be changed without code changes

**Discoverability**: Extensions are automatically discovered from installed packages

**Type Safety**: TypeScript ensures correct inputs/outputs

---

## Extension Structure

Every extension has four key properties:

### 1. Extension ID

A unique identifier in the format: `kind:namespace/name`

```typescript
const myExtension = createExtension({
  id: 'page:my-plugin/dashboard',
  // kind = 'page'
  // namespace = 'my-plugin'
  // name = 'dashboard'
  // ...
});
```

**Naming Conventions**:
- **kind**: The type of extension (page, api, theme, nav-item, etc.)
- **namespace**: Usually the plugin ID that provides the extension
- **name**: Specific name for this instance

### 2. Attachment Point

Where this extension attaches in the tree (optional, often handled by blueprints)

```typescript
const myExtension = createExtension({
  id: 'page:my-plugin/dashboard',
  attachTo: { id: 'app/routes', input: 'routes' },
  // ...
});
```

### 3. Inputs

Data this extension needs from child extensions

```typescript
const myExtension = createExtension({
  id: 'plugin:my-plugin',
  inputs: {
    pages: createExtensionInput({
      element: coreExtensionData.reactElement,
    }),
  },
  // ...
});
```

### 4. Output

Data this extension provides to its parent

```typescript
const myExtension = createExtension({
  id: 'page:my-plugin/dashboard',
  output: {
    element: coreExtensionData.reactElement,
  },
  factory: () => {
    return {
      element: <DashboardPage />,
    };
  },
});
```

---

## Creating Extensions

There are two ways to create extensions:

### 1. Using Extension Blueprints (Recommended)

Blueprints are pre-configured templates for common extension types.

```typescript
import { PageBlueprint } from '@backstage/frontend-plugin-api';

const myPage = PageBlueprint.make({
  name: 'dashboard',
  params: {
    defaultPath: '/dashboard',
    loader: async () => {
      const { DashboardPage } = await import('./components/DashboardPage');
      return <DashboardPage />;
    },
  },
});
```

**Benefits**:
- Less boilerplate
- Correct attachment points automatically
- Built-in configuration support
- Type safety

**Common Blueprints**:
- `PageBlueprint` - For pages/routes
- `ApiBlueprint` - For utility APIs
- `SignInPageBlueprint` - For sign-in pages
- `ThemeBlueprint` - For themes
- `NavItemBlueprint` - For navigation items

### 2. Using createExtension (Advanced)

Direct extension creation for custom extension types.

```typescript
import { createExtension, coreExtensionData } from '@backstage/frontend-plugin-api';

const myExtension = createExtension({
  id: 'page:my-plugin/dashboard',
  attachTo: { id: 'app/routes', input: 'routes' },
  output: {
    element: coreExtensionData.reactElement,
    path: coreExtensionData.routePath,
  },
  factory: () => {
    return {
      element: <DashboardPage />,
      path: '/dashboard',
    };
  },
});
```

**When to use createExtension**:
- Creating custom extension kinds
- Need fine-grained control over inputs/outputs
- Building reusable extension patterns
- Creating extension blueprints themselves

---

## Extension Blueprints

Blueprints simplify common extension patterns. Here's how each major blueprint works:

### PageBlueprint

Creates routable pages.

```typescript
import { PageBlueprint } from '@backstage/frontend-plugin-api';

const catalogPage = PageBlueprint.make({
  name: 'catalog',
  params: {
    defaultPath: '/catalog',
    loader: async () => {
      const { CatalogIndexPage } = await import('./components/CatalogIndexPage');
      return <CatalogIndexPage />;
    },
  },
});
```

**Generated Extension ID**: `page:{namespace}/catalog`

**Attaches To**: `app/routes` extension

**Outputs**: `reactElement`, `routePath`, `routeRef`

**Configuration Schema**: Supports `path` override

### ApiBlueprint

Creates utility API registrations.

```typescript
import { ApiBlueprint, configApiRef } from '@backstage/frontend-plugin-api';

const myApi = ApiBlueprint.make({
  name: 'my-api',
  params: {
    api: myApiRef,
    deps: {
      configApi: configApiRef,
      discoveryApi: discoveryApiRef,
    },
    factory: ({ configApi, discoveryApi }) => {
      return new MyApiImpl({ configApi, discoveryApi });
    },
  },
});
```

**Generated Extension ID**: `api:{namespace}/my-api`

**Attaches To**: `core/apis` extension

**Outputs**: `apiFactory`

**Configuration Schema**: None by default

### SignInPageBlueprint

Creates custom sign-in pages.

```typescript
import { SignInPageBlueprint } from '@backstage/frontend-plugin-api';

const customSignInPage = SignInPageBlueprint.make({
  name: 'custom-sign-in',
  params: {
    loader: async () => {
      const { CustomSignInPage } = await import('./components/CustomSignInPage');
      return <CustomSignInPage />;
    },
  },
});
```

**Generated Extension ID**: `sign-in-page:{namespace}/custom-sign-in`

**Attaches To**: `app` extension

**Outputs**: `reactElement`

### ThemeBlueprint

Creates custom themes.

```typescript
import { ThemeBlueprint } from '@backstage/frontend-plugin-api';
import { darkTheme } from './themes';

const customDarkTheme = ThemeBlueprint.make({
  name: 'dark',
  params: {
    theme: darkTheme,
  },
});
```

**Generated Extension ID**: `theme:{namespace}/dark`

**Attaches To**: `app/themes` extension

**Outputs**: `theme`

### NavItemBlueprint

Creates navigation items.

```typescript
import { NavItemBlueprint } from '@backstage/frontend-plugin-api';
import HomeIcon from '@material-ui/icons/Home';

const homeNavItem = NavItemBlueprint.make({
  name: 'home',
  params: {
    title: 'Home',
    icon: HomeIcon,
    routeRef: homeRouteRef,
  },
});
```

**Generated Extension ID**: `nav-item:{namespace}/home`

**Attaches To**: `app/nav` extension

**Outputs**: `navItem`

---

## Extension Data References

Extension data references define the types of data that can flow between extensions.

### Core Extension Data

Backstage provides standard data types:

```typescript
import { coreExtensionData } from '@backstage/frontend-plugin-api';

// React components
coreExtensionData.reactElement

// Routes
coreExtensionData.routePath
coreExtensionData.routeRef

// APIs
coreExtensionData.apiFactory

// Themes
coreExtensionData.theme

// Navigation
coreExtensionData.navItem

// Configuration
coreExtensionData.config
```

### Using Extension Data in Outputs

```typescript
const myExtension = createExtension({
  id: 'page:my-plugin/dashboard',
  output: {
    element: coreExtensionData.reactElement,
    path: coreExtensionData.routePath,
  },
  factory: () => {
    return {
      element: <DashboardPage />,
      path: '/dashboard',
    };
  },
});
```

### Custom Extension Data

Create your own data types for custom extension kinds:

```typescript
import { createExtensionDataRef } from '@backstage/frontend-plugin-api';

export const widgetDataRef = createExtensionDataRef<{
  title: string;
  component: React.ComponentType;
}>('plugin.my-plugin.widget');

const widgetExtension = createExtension({
  id: 'widget:my-plugin/stats',
  output: {
    widget: widgetDataRef,
  },
  factory: () => {
    return {
      widget: {
        title: 'Stats Widget',
        component: StatsWidget,
      },
    };
  },
});
```

---

## Inputs and Outputs

Extensions communicate through typed inputs and outputs, forming a dependency graph.

### Outputs: What an Extension Provides

Every extension defines what it provides to its parent:

```typescript
const childExtension = createExtension({
  id: 'card:my-plugin/info-card',
  output: {
    element: coreExtensionData.reactElement,
    title: customDataRef.cardTitle,
  },
  factory: () => {
    return {
      element: <InfoCard />,
      title: 'Information',
    };
  },
});
```

### Inputs: What an Extension Consumes

Parent extensions declare what they accept from children:

```typescript
const parentExtension = createExtension({
  id: 'page:my-plugin/dashboard',
  inputs: {
    cards: createExtensionInput({
      element: coreExtensionData.reactElement,
      title: customDataRef.cardTitle,
    }),
  },
  output: {
    element: coreExtensionData.reactElement,
  },
  factory: ({ inputs }) => {
    // Access all child extensions that attached to 'cards' input
    const cardElements = inputs.cards.map((card) => ({
      element: card.output.element,
      title: card.output.title,
    }));

    return {
      element: <Dashboard cards={cardElements} />,
    };
  },
});
```

### Optional vs Required Inputs

```typescript
inputs: {
  // Required: At least one child extension must attach
  cards: createExtensionInput({
    element: coreExtensionData.reactElement,
  }),

  // Optional: Child extensions are optional
  widgets: createExtensionInput({
    element: coreExtensionData.reactElement,
  }, {
    optional: true,
  }),

  // Singleton: Exactly one child extension must attach
  header: createExtensionInput({
    element: coreExtensionData.reactElement,
  }, {
    singleton: true,
  }),
}
```

### Replaceability

Some inputs allow replacing instead of collecting:

```typescript
inputs: {
  // Allows replacing via configuration
  signInPage: createExtensionInput({
    element: coreExtensionData.reactElement,
  }, {
    singleton: true,
    optional: true,
  }),
}
```

---

## Configuration Schemas

Extensions can be configured via `app-config.yaml` using configuration schemas.

### Defining Configuration Schema

```typescript
import { createExtension, createSchemaFromZod } from '@backstage/frontend-plugin-api';
import { z } from 'zod';

const myExtension = createExtension({
  id: 'page:my-plugin/dashboard',
  configSchema: createSchemaFromZod((z) =>
    z.object({
      refreshInterval: z.number().default(60),
      showMetrics: z.boolean().default(true),
      displayMode: z.enum(['compact', 'detailed']).default('detailed'),
    }),
  ),
  output: {
    element: coreExtensionData.reactElement,
  },
  factory: ({ config }) => {
    const refreshInterval = config.refreshInterval;
    const showMetrics = config.showMetrics;
    const displayMode = config.displayMode;

    return {
      element: (
        <DashboardPage
          refreshInterval={refreshInterval}
          showMetrics={showMetrics}
          displayMode={displayMode}
        />
      ),
    };
  },
});
```

### Configuring Extensions in app-config.yaml

```yaml
app:
  extensions:
    - page:my-plugin/dashboard:
        config:
          refreshInterval: 30
          showMetrics: false
          displayMode: compact
```

### Blueprint Configuration

Blueprints often include built-in configuration schemas:

```typescript
const catalogPage = PageBlueprint.make({
  name: 'catalog',
  params: {
    defaultPath: '/catalog',
    loader: async () => <CatalogIndexPage />,
  },
});
```

Configure via app-config.yaml:

```yaml
app:
  extensions:
    - page:catalog/catalog:
        config:
          path: /my-catalog  # Override default path
```

---

## Extension Overrides

Extensions can be disabled, replaced, or configured without modifying code.

### Disabling Extensions

```yaml
app:
  extensions:
    - page:my-plugin/dashboard:
        disabled: true
```

### Replacing Extensions

Create a new extension with the same ID:

```typescript
// Original extension in plugin
const originalPage = PageBlueprint.make({
  name: 'dashboard',
  params: {
    defaultPath: '/dashboard',
    loader: async () => <OriginalDashboard />,
  },
});

// Override in app
const overridePage = PageBlueprint.make({
  name: 'dashboard',
  namespace: 'my-plugin',  // Must match original namespace
  params: {
    defaultPath: '/custom-dashboard',
    loader: async () => <CustomDashboard />,
  },
});
```

Register the override later in the features array:

```typescript
createApp({
  features: [
    myPlugin,  // Contains original
    createFrontendModule({
      pluginId: 'app',
      extensions: [overridePage],  // Replaces original
    }),
  ],
});
```

### Configuring Extension Attachment

Change where an extension attaches:

```yaml
app:
  extensions:
    - widget:my-plugin/stats:
        attachTo:
          id: page:catalog/entity
          input: widgets
```

---

## Best Practices

### 1. Prefer Blueprints Over createExtension

**Good**:
```typescript
const myPage = PageBlueprint.make({
  name: 'dashboard',
  params: { ... },
});
```

**Avoid** (unless creating custom extension kinds):
```typescript
const myPage = createExtension({
  id: 'page:my-plugin/dashboard',
  attachTo: { id: 'app/routes', input: 'routes' },
  output: { ... },
  factory: () => { ... },
});
```

### 2. Use Consistent Naming

- Extension IDs: `{kind}:{namespace}/{name}`
- Namespaces: Match plugin ID
- Names: Descriptive and unique within namespace

### 3. Lazy Load Components

Always use dynamic imports in loaders:

```typescript
const myPage = PageBlueprint.make({
  name: 'dashboard',
  params: {
    loader: async () => {
      const { DashboardPage } = await import('./components/DashboardPage');
      return <DashboardPage />;
    },
  },
});
```

### 4. Provide Configuration Defaults

Always provide sensible defaults in config schemas:

```typescript
configSchema: createSchemaFromZod((z) =>
  z.object({
    refreshInterval: z.number().default(60),  // Default value
  }),
)
```

### 5. Document Extension Inputs

If creating extensions with custom inputs, document what can attach:

```typescript
/**
 * Dashboard page extension
 *
 * Accepts child extensions:
 * - widgets: Dashboard widgets (kind: 'widget')
 * - actions: Dashboard actions (kind: 'action')
 */
const dashboardPage = createExtension({
  id: 'page:my-plugin/dashboard',
  inputs: {
    widgets: createExtensionInput({ ... }),
    actions: createExtensionInput({ ... }),
  },
  // ...
});
```

### 6. Namespace Custom Data Refs

Use namespaced IDs for custom data refs:

```typescript
const widgetDataRef = createExtensionDataRef<WidgetData>(
  'plugin.my-plugin.widget'  // Namespaced
);
```

### 7. Test Extension Overrides

Ensure your extensions can be disabled/overridden:

```yaml
# Test disabling
app:
  extensions:
    - page:my-plugin/dashboard:
        disabled: true
```

### 8. Use TypeScript Strictly

Leverage TypeScript for extension data types:

```typescript
interface WidgetData {
  title: string;
  component: React.ComponentType<{ data: any }>;
  priority?: number;
}

const widgetDataRef = createExtensionDataRef<WidgetData>('...');
```

---

## Common Patterns

### Pattern 1: Extensible Page

Create a page that accepts child extensions:

```typescript
const dashboardPage = createExtension({
  id: 'page:dashboard/root',
  attachTo: { id: 'app/routes', input: 'routes' },
  inputs: {
    widgets: createExtensionInput({
      element: coreExtensionData.reactElement,
    }, { optional: true }),
  },
  output: {
    element: coreExtensionData.reactElement,
    path: coreExtensionData.routePath,
  },
  factory: ({ inputs }) => {
    const widgets = inputs.widgets?.map(w => w.output.element) ?? [];

    return {
      element: <DashboardPage widgets={widgets} />,
      path: '/dashboard',
    };
  },
});

// Add widgets to dashboard
const statsWidget = createExtension({
  id: 'widget:dashboard/stats',
  attachTo: { id: 'page:dashboard/root', input: 'widgets' },
  output: {
    element: coreExtensionData.reactElement,
  },
  factory: () => ({
    element: <StatsWidget />,
  }),
});
```

### Pattern 2: Conditional Extensions

Load extensions based on configuration:

```typescript
const featureFlaggedPage = createExtension({
  id: 'page:my-plugin/beta-feature',
  configSchema: createSchemaFromZod((z) =>
    z.object({
      enabled: z.boolean().default(false),
    }),
  ),
  output: {
    element: coreExtensionData.reactElement,
  },
  factory: ({ config }) => {
    if (!config.enabled) {
      return { element: null };
    }
    return { element: <BetaFeaturePage /> };
  },
});
```

Configure:
```yaml
app:
  extensions:
    - page:my-plugin/beta-feature:
        config:
          enabled: true
```

### Pattern 3: Extension Composition

Combine multiple extensions:

```typescript
const myPlugin = createFrontendPlugin({
  id: 'my-plugin',
  extensions: [
    dashboardPage,
    statsWidget,
    metricsWidget,
    settingsPage,
    myApi,
  ],
});
```

### Pattern 4: Dynamic Extension Data

Pass runtime data through extensions:

```typescript
const widgetDataRef = createExtensionDataRef<{
  title: string;
  priority: number;
}>('plugin.dashboard.widget');

const widget = createExtension({
  id: 'widget:dashboard/stats',
  output: {
    element: coreExtensionData.reactElement,
    widget: widgetDataRef,
  },
  factory: () => ({
    element: <StatsWidget />,
    widget: {
      title: 'Statistics',
      priority: 10,
    },
  }),
});

const dashboardPage = createExtension({
  inputs: {
    widgets: createExtensionInput({
      element: coreExtensionData.reactElement,
      widget: widgetDataRef,
    }),
  },
  factory: ({ inputs }) => {
    // Sort widgets by priority
    const sortedWidgets = inputs.widgets
      .sort((a, b) => b.output.widget.priority - a.output.widget.priority)
      .map(w => ({
        title: w.output.widget.title,
        element: w.output.element,
      }));

    return {
      element: <DashboardPage widgets={sortedWidgets} />,
    };
  },
});
```

---

## Troubleshooting

### Extension Not Found

**Symptom**: Extension ID not found in app

**Solutions**:
1. Check extension is included in plugin's `extensions` array
2. Verify plugin is in app's `features` array
3. Ensure extension ID matches exactly (kind:namespace/name)
4. Check for typos in attachment point

### Extension Not Attaching

**Symptom**: Extension created but not appearing in app

**Solutions**:
1. Verify `attachTo` points to valid parent extension
2. Check parent's input accepts your extension's output
3. Ensure output data matches input requirements
4. Check extension is not disabled in app-config.yaml

### Configuration Not Applied

**Symptom**: app-config.yaml changes not taking effect

**Solutions**:
1. Verify extension ID in config matches extension
2. Check schema validates your config values
3. Restart dev server after config changes
4. Check for YAML syntax errors

### Type Errors

**Symptom**: TypeScript errors with extension data

**Solutions**:
1. Ensure extension data types match between input/output
2. Import data refs from correct packages
3. Verify generic types in createExtensionDataRef
4. Check factory return type matches output declaration

---

## Advanced Topics

### Creating Custom Blueprints

Blueprints are themselves created using `createExtensionBlueprint`:

```typescript
import { createExtensionBlueprint } from '@backstage/frontend-plugin-api';

export const WidgetBlueprint = createExtensionBlueprint({
  kind: 'widget',
  attachTo: { id: 'page:dashboard/root', input: 'widgets' },
  output: {
    element: coreExtensionData.reactElement,
    widget: widgetDataRef,
  },
  factory: (params: {
    title: string;
    priority?: number;
    component: React.ComponentType;
  }) => {
    return {
      element: React.createElement(params.component),
      widget: {
        title: params.title,
        priority: params.priority ?? 0,
      },
    };
  },
});

// Usage
const statsWidget = WidgetBlueprint.make({
  name: 'stats',
  params: {
    title: 'Statistics',
    priority: 10,
    component: StatsWidget,
  },
});
```

### Extension Graphs

Visualize extension relationships:

```typescript
import { extractExtensionGraph } from '@backstage/frontend-plugin-api';

const graph = extractExtensionGraph(app);
console.log(graph.extensions);  // All extensions
console.log(graph.attachments);  // Parent-child relationships
```

### Runtime Extension Registration

Extensions can be registered at runtime (advanced):

```typescript
import { createApp } from '@backstage/frontend-defaults';

const app = createApp({
  features: [...initialFeatures],
});

// Later, add more extensions
app.addFeature(createFrontendModule({
  pluginId: 'dynamic',
  extensions: [dynamicExtension],
}));
```

---

## Summary

**Key Takeaways**:

1. **Extensions are the foundation** - Everything in Backstage New Frontend System is an extension
2. **Use blueprints** - PageBlueprint, ApiBlueprint, etc. handle common patterns
3. **Inputs and outputs** - Extensions communicate through typed data flows
4. **Configuration-driven** - Extensions can be configured via app-config.yaml
5. **Override without code changes** - Disable, replace, or reconfigure extensions declaratively
6. **Type-safe** - TypeScript ensures correct extension composition

**Next Steps**:
- [Learn about Utility APIs →](./04-utility-apis.md)
- [Explore Auth Providers →](./05-auth-providers.md)
- [Build Plugins →](./06-plugin-development.md)

---

**Navigation**:
- [← Previous: App Creation](./02-app-creation.md)
- [Next: Utility APIs →](./04-utility-apis.md)
- [Back to INDEX](./INDEX.md)
