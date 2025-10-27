# Frontend System Architecture

> **Comprehensive guide to the new frontend system architecture**
>
> Understanding these concepts is essential for building plugins and apps with the new frontend system.

## Table of Contents

- [Overview](#overview)
- [Building Blocks](#building-blocks)
- [Extension Tree Architecture](#extension-tree-architecture)
- [Data Flow](#data-flow)
- [Key Concepts](#key-concepts)
- [Legacy vs New System](#legacy-vs-new-system)
- [Architecture Patterns](#architecture-patterns)

---

## Overview

The new frontend system is built on an **extension-based architecture** where everything in the app is an extension that can be configured, replaced, or extended. This creates a highly modular and composable system.

### Core Philosophy

**Everything is an Extension**:
- Pages
- Components
- Utility APIs
- Themes
- Routes
- Even the app itself

**Declarative Configuration**:
- Extensions are wired together via configuration
- Less boilerplate code in App.tsx
- Override behavior via app-config.yaml

**Plugin Autonomy**:
- Plugins provide their own extensions
- Apps compose plugins, not individual components
- Clearer boundaries and responsibilities

---

## Building Blocks

### 1. App

The app instance is the root of everything. It:
- Wires together all extensions into a tree
- Provides built-in core extensions
- Handles feature discovery and installation
- Renders the final React tree

**Creation**:
```typescript
import { createApp } from '@backstage/frontend-defaults';

const app = createApp({
  features: [
    catalogPlugin,
    scaffolderPlugin,
    // ... more features
  ],
});

export default app.createRoot();
```

**Key Point**: The app doesn't render JSX directly. It builds an extension tree that generates the React tree.

---

### 2. Extensions

Extensions are the **fundamental building blocks**. Each extension:
- Has a unique ID
- Can have inputs (receives data from children)
- Has outputs (provides data to parent)
- Attaches to a parent via attachment point
- Can be configured, disabled, or replaced

**Visual Representation**:

```
┌─────────────────────────────────────┐
│         Extension                   │
├─────────────────────────────────────┤
│ ID: page:catalog/index              │
│                                     │
│ Attachment Point:                   │
│   → core/routes (parent)            │
│                                     │
│ Inputs:                             │
│   ← items: [ExtensionData]          │
│                                     │
│ Output:                             │
│   → reactElement: <CatalogPage/>    │
│   → path: "/catalog"                │
│   → routeRef: catalogRouteRef       │
│                                     │
│ Configuration:                      │
│   title: "Catalog"                  │
│   pagination: { limit: 20 }         │
│                                     │
│ Factory:                            │
│   ({ inputs, config }) => { ... }   │
└─────────────────────────────────────┘
```

---

### 3. Plugins

Plugins are **collections of extensions** that provide features. A plugin can:
- Provide pages (via PageBlueprint)
- Provide APIs (via ApiBlueprint)
- Provide components
- Provide routes
- Extend other plugins

**Structure**:
```typescript
export default createFrontendPlugin({
  pluginId: 'catalog',
  extensions: [
    catalogIndexPage,        // Page extension
    catalogEntityPage,       // Page extension
    catalogApi,              // API extension
    catalogNavItem,          // Nav item extension
    catalogSearchResultList, // Search result extension
  ],
  routes: {
    catalogIndex: catalogRouteRef,
    catalogEntity: catalogEntityRouteRef,
  },
});
```

**Key Point**: Plugins export extensions, not React components. The app wires extensions together.

---

### 4. Extension Overrides

You can override any extension in the app, allowing for deep customization without modifying plugin code.

**Use Cases**:
- Replace a plugin's page with custom implementation
- Override theme
- Customize sidebar
- Replace utility API implementation

**Pattern**:
```typescript
// Override the catalog index page
const customCatalogPage = catalogPlugin.getExtension('page:catalog/index').override({
  params: {
    loader: async () => <MyCustomCatalogPage />,
  },
});

const app = createApp({
  features: [
    catalogPlugin.withOverrides({
      extensions: [customCatalogPage],
    }),
  ],
});
```

---

### 5. Utility APIs

Utility APIs are **shared functionality** provided as extensions. They:
- Define TypeScript interfaces
- Can be accessed via `useApi()` hook
- Can depend on other APIs
- Can be replaced or configured
- Are themselves extensions

**Example APIs**:
- `configApi` - Read app configuration
- `discoveryApi` - Find backend URLs
- `storageApi` - Browser storage
- `errorApi` - Error reporting
- `githubAuthApi` - GitHub authentication

**Structure**:
```
API Ref (Contract)     → createApiRef<ConfigApi>({ id: 'core.config' })
API Implementation     → class ConfigReader implements ConfigApi
API Extension          → ApiBlueprint.make({ api: configApiRef, factory: ... })
API Registration       → Install in app features
API Consumption        → useApi(configApiRef) in components
```

---

### 6. Routes

The routing system adds **indirection** for plugin-to-plugin navigation. Instead of hardcoded URLs, plugins:
- Define route refs (logical references)
- Bind route refs to actual routes
- Generate links dynamically at runtime

**Benefits**:
- Plugins don't need to know each other's URLs
- Routes can be reconfigured without changing plugin code
- Type-safe navigation

**Example**:
```typescript
// Plugin A defines a route ref
export const myRouteRef = createRouteRef({ id: 'my-route' });

// Plugin B references it without knowing the URL
const { url } = useRouteRef(myRouteRef);
// Returns: "/my-plugin/my-route" (or whatever it's configured as)

// App binds routes
app.bind({ routes: { myRoute: myRouteRef } });
```

---

## Extension Tree Architecture

### Tree Structure

All extensions form a **tree structure** where:
- Root: Core extension provided by the app
- Branches: Plugin extensions, pages, APIs
- Leaves: Terminal extensions with no children

**Example Tree**:

```
core (root)
├─── apis
│    ├─── config
│    ├─── discovery
│    ├─── github-auth
│    └─── catalog-client
├─── routes
│    ├─── page:catalog/index
│    │    └─── items (children extensions)
│    ├─── page:catalog/entity
│    │    └─── tabs
│    │         ├─── overview-tab
│    │         ├─── api-tab
│    │         └─── dependencies-tab
│    └─── page:scaffolder
│         └─── items
├─── nav
│    ├─── nav-item:catalog
│    ├─── nav-item:create
│    └─── nav-item:docs
└─── components
     ├─── sign-in-page
     └─── theme:light
```

**Key Properties**:
- **Single Parent**: Each extension has exactly one parent (or is root)
- **Multiple Children**: Extensions can have multiple children
- **No Cycles**: Tree cannot contain loops
- **Typed Connections**: Parent/child must have compatible data types

---

### Extension IDs

Every extension has a unique ID constructed from:
- **Kind**: Type of extension (e.g., `page`, `api`, `nav-item`)
- **Namespace**: Usually plugin ID (e.g., `catalog`)
- **Name**: Distinguishes multiple extensions of same kind

**Pattern**: `[<kind>:][<namespace>][/][<name>]`

**Examples**:
- `api:core/config` - Config API
- `page:catalog/index` - Catalog index page
- `nav-item:catalog` - Catalog nav item
- `core` - Root extension (no kind or namespace)

---

### Attachment Points

Extensions attach to parents via **attachment points**:
- `id`: Parent extension ID
- `input`: Input name on parent

**Example**:
```typescript
const myExtension = createExtension({
  attachTo: {
    id: 'page:catalog/index',  // Parent ID
    input: 'items',             // Input name
  },
  output: [coreExtensionData.reactElement],
  factory() {
    return [coreExtensionData.reactElement(<MyComponent />)];
  },
});
```

**Multiple Attachment Points**:
Extensions can attach to multiple parents:
```typescript
attachTo: [
  { id: 'parent1', input: 'content' },
  { id: 'parent2', input: 'items' },
]
```

---

## Data Flow

### Extension Data

Communication between extensions happens through **extension data**:

```
Child Extension                     Parent Extension
┌──────────────┐                   ┌──────────────┐
│              │                   │              │
│   Output     │  ───────────────> │    Input     │
│              │   Extension Data  │              │
│ [reactElement,│                  │ items: [...]  │
│  routeRef,    │                  │              │
│  path]        │                  │              │
└──────────────┘                   └──────────────┘
```

**Data References**:
Each piece of data has a reference:
```typescript
const myDataRef = createExtensionDataRef<string>().with({
  id: 'my-plugin.my-data',
});
```

**Declaring Output**:
```typescript
const extension = createExtension({
  output: [
    coreExtensionData.reactElement,
    coreExtensionData.routeRef,
  ],
  factory() {
    return [
      coreExtensionData.reactElement(<MyComponent />),
      coreExtensionData.routeRef(myRouteRef),
    ];
  },
});
```

**Declaring Input**:
```typescript
const parentExtension = createExtension({
  inputs: {
    items: createExtensionInput(
      [coreExtensionData.reactElement],
      { optional: false }
    ),
  },
  factory({ inputs }) {
    const children = inputs.items.map(item =>
      item.get(coreExtensionData.reactElement)
    );
    return [
      coreExtensionData.reactElement(
        <div>{children}</div>
      ),
    ];
  },
});
```

---

### Factory Execution Order

The app instantiates extensions in **bottom-up order**:

```
1. Leaf extensions (no children) are instantiated first
2. Then their parents (once all children are ready)
3. Continue up the tree to the root

Example:
  nav-item:catalog → nav → core (root)
```

**Why Bottom-Up?**
- Parents need children's output data
- Prevents forward references
- Ensures data is available when needed

**Factory Rules**:
- Must be synchronous (or return Promise-like)
- Should be lean (no heavy computation)
- Prefer callbacks for expensive work

---

## Key Concepts

### 1. Extension Blueprints

Blueprints are **templates for common extension patterns**:

**Available Blueprints**:
- `PageBlueprint` - Create pages
- `ApiBlueprint` - Create utility APIs
- `SignInPageBlueprint` - Create sign-in pages
- `ThemeBlueprint` - Create themes
- `NavItemBlueprint` - Create navigation items
- `TranslationBlueprint` - Add translations

**Why Blueprints?**
- Reduce boilerplate
- Ensure consistency
- Handle extension data automatically
- Provide type safety

**Example**:
```typescript
// With blueprint (recommended)
const myPage = PageBlueprint.make({
  params: {
    defaultPath: '/my-page',
    loader: async () => <MyPage />,
  },
});

// Without blueprint (manual)
const myPage = createExtension({
  kind: 'page',
  attachTo: { id: 'core/routes', input: 'routes' },
  output: [
    coreExtensionData.reactElement,
    coreExtensionData.routePath,
    coreExtensionData.routeRef.optional(),
  ],
  factory() {
    return [
      coreExtensionData.reactElement(<MyPage />),
      coreExtensionData.routePath('/my-page'),
    ];
  },
});
```

---

### 2. Feature Discovery

The app can **automatically discover and install** plugins from dependencies:

**Configuration**:
```yaml
# app-config.yaml
app:
  packages: all  # Discover all packages
```

**Or with filters**:
```yaml
app:
  packages:
    include:
      - '@backstage/plugin-catalog'
      - '@internal/*'
```

**How It Works**:
1. CLI scans `package.json` dependencies
2. Checks for Backstage plugin exports
3. Imports plugins at build time
4. Adds to app features automatically

**Benefits**:
- No manual imports
- Just add to package.json
- Automatic updates

---

### 3. Configuration

Extensions can be configured via `app-config.yaml`:

**Extension Configuration**:
```yaml
app:
  extensions:
    - page:catalog/index:
        config:
          pagination:
            limit: 50
        disabled: false
    - nav-item:docs: false  # Disable extension
```

**Configuration Schema**:
Extensions define schemas with Zod:
```typescript
const myExtension = createExtension({
  config: {
    schema: {
      title: z => z.string().default('Default Title'),
      limit: z => z.number().min(1).max(100).default(20),
    },
  },
  factory({ config }) {
    // config.title and config.limit are type-safe
    return [/* ... */];
  },
});
```

---

### 4. Extension Priority

When multiple extensions have the same ID:
- **Last registered wins**
- Explicit features override discovered
- Can be controlled via order in `features` array

**Use Cases**:
- Override default implementations
- Replace plugin behavior
- Customize without forking

---

## Legacy vs New System

### Comparison Table

| Aspect | Legacy System | New Frontend System |
|--------|---------------|---------------------|
| **Main Import** | `@backstage/app-defaults` | `@backstage/frontend-defaults` |
| **Plugin Loading** | `plugins: [plugin]` | `features: [plugin]` |
| **Plugin Exports** | Default export | `/alpha` subpath export |
| **App Structure** | JSX tree in createRoot() | Extension tree |
| **Pages** | Manual Route components | PageBlueprint extensions |
| **APIs** | createApiFactory in apis.ts | ApiBlueprint extensions |
| **Configuration** | Mostly code-based | Declarative in app-config |
| **Customization** | Modify App.tsx | Extension overrides |
| **Plugin Discovery** | Manual imports | Automatic via config |
| **Routing** | Hardcoded in App.tsx | Route refs + bindings |

---

### Migration Path

**Phase 1: Hybrid Mode**
- Use new frontend system
- Keep legacy plugins via `convertLegacyAppRoot`
- Gradually migrate plugins

**Phase 2: Full Migration**
- All plugins using new system
- Remove compatibility helpers
- Clean extension tree

See [07-migration.md](./07-migration.md) for complete guide.

---

### What Changed?

**1. App Creation**
```typescript
// Legacy
import { createApp } from '@backstage/app-defaults';
const app = createApp({ plugins, apis, themes });
export default app.createRoot(<AppProvider><AppRouter>...</AppRouter></AppProvider>);

// New
import { createApp } from '@backstage/frontend-defaults';
const app = createApp({ features: [catalogPlugin, scaffolderPlugin] });
export default app.createRoot(); // No JSX!
```

**2. Plugin Structure**
```typescript
// Legacy: Export components
export { CatalogIndexPage, CatalogEntityPage };

// New: Export plugin with extensions
export default createFrontendPlugin({
  pluginId: 'catalog',
  extensions: [catalogIndexPage, catalogEntityPage],
});
```

**3. API Registration**
```typescript
// Legacy: apis.ts with createApiFactory
export const apis = [
  createApiFactory({
    api: catalogApiRef,
    deps: { discoveryApi: discoveryApiRef },
    factory: ({ discoveryApi }) => new CatalogClient({ discoveryApi }),
  }),
];

// New: ApiBlueprint in plugin
const catalogApi = ApiBlueprint.make({
  name: 'catalog',
  params: {
    factory: createApiFactory({
      api: catalogApiRef,
      deps: { discoveryApi: discoveryApiRef },
      factory: ({ discoveryApi }) => new CatalogClient({ discoveryApi }),
    }),
  },
});
```

**4. Customization**
```typescript
// Legacy: Modify App.tsx JSX
<Route path="/catalog" element={<CustomCatalogPage />} />

// New: Override extension
const customPage = catalogPlugin.getExtension('page:catalog/index').override({
  params: { loader: async () => <CustomCatalogPage /> },
});

createApp({
  features: [catalogPlugin.withOverrides({ extensions: [customPage] })],
});
```

---

## Architecture Patterns

### Pattern 1: Page with Children

**Use Case**: Page that renders child extensions (e.g., entity page with tabs)

```typescript
const entityPage = PageBlueprint.make({
  params: {
    defaultPath: '/catalog/:namespace/:kind/:name',
    loader: async () => {
      // Use PageBlueprint to automatically handle inputs
      return ({ children }) => (
        <EntityLayout>
          {children}  {/* Child tab extensions */}
        </EntityLayout>
      );
    },
  },
});

// Child extensions attach to entity page
const overviewTab = createExtension({
  attachTo: { id: 'page:catalog/entity', input: 'tabs' },
  output: [coreExtensionData.reactElement, tabDataRef],
  factory() {
    return [
      coreExtensionData.reactElement(<OverviewContent />),
      tabDataRef({ title: 'Overview', path: '/' }),
    ];
  },
});
```

---

### Pattern 2: Conditional Extension Loading

**Use Case**: Enable/disable extensions based on configuration

```yaml
# app-config.yaml
app:
  extensions:
    - page:admin:
        disabled: false  # Enable admin page
    - feature:experimental:
        disabled: true   # Disable experimental features
```

```typescript
const adminPage = PageBlueprint.make({
  params: {
    defaultPath: '/admin',
    loader: async () => <AdminPage />,
  },
});

// Extension is registered but can be disabled via config
```

---

### Pattern 3: Extension Composition

**Use Case**: Build complex features from simpler extensions

```typescript
// Base extension
const baseTable = createExtension({
  output: [tableDataRef],
  factory() {
    return [tableDataRef({ columns: ['name', 'type'] })];
  },
});

// Enhanced extension that composes base
const enhancedTable = createExtension({
  inputs: {
    base: createExtensionInput([tableDataRef]),
  },
  factory({ inputs }) {
    const baseTable = inputs.base.get(tableDataRef);
    return [
      tableDataRef({
        ...baseTable,
        columns: [...baseTable.columns, 'actions'],
      }),
    ];
  },
});
```

---

### Pattern 4: API with Dependencies

**Use Case**: Utility API that depends on other APIs

```typescript
const catalogApi = ApiBlueprint.make({
  name: 'catalog',
  params: {
    factory: createApiFactory({
      api: catalogApiRef,
      deps: {
        discoveryApi: discoveryApiRef,
        fetchApi: fetchApiRef,
        identityApi: identityApiRef,
      },
      factory: ({ discoveryApi, fetchApi, identityApi }) => {
        return new CatalogClient({
          discoveryApi,
          fetchApi,
          identityApi,
        });
      },
    }),
  },
});
```

---

### Pattern 5: Plugin Modules

**Use Case**: Extend existing plugins without modifying their code

```typescript
// Module that adds to catalog plugin
const catalogCustomModule = createFrontendModule({
  pluginId: 'catalog',  // Extends catalog plugin
  extensions: [
    customEntityTab,    // Add new tab
    customFilter,       // Add custom filter
  ],
});

createApp({
  features: [
    catalogPlugin,          // Base plugin
    catalogCustomModule,    // Extension module
  ],
});
```

---

## Summary

### Key Takeaways

1. **Extension-Based**: Everything is an extension in a tree structure
2. **Declarative**: Configure via app-config.yaml, less code
3. **Composable**: Extensions can be combined and nested
4. **Replaceable**: Any extension can be overridden
5. **Type-Safe**: TypeScript ensures correctness
6. **Discoverable**: Plugins can be auto-installed

### Architecture Benefits

✅ **Modular**: Clear boundaries between plugins
✅ **Flexible**: Override any behavior without forking
✅ **Maintainable**: Less boilerplate code
✅ **Scalable**: Add plugins without modifying app
✅ **Type-Safe**: Compile-time checks
✅ **Configurable**: Runtime customization via config

### Next Steps

- **[02-app-creation.md](./02-app-creation.md)** - Learn how to create and configure apps
- **[03-extensions.md](./03-extensions.md)** - Deep dive into extensions
- **[04-utility-apis.md](./04-utility-apis.md)** - Understand utility APIs
- **[06-plugin-development.md](./06-plugin-development.md)** - Build your own plugins

---

**Navigation**:
- [← Back to INDEX](./INDEX.md)
- [Next: App Creation →](./02-app-creation.md)
