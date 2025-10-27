/**
 * PageBlueprint Example
 *
 * This example shows how to use PageBlueprint to create page extensions.
 * PageBlueprint is the recommended way to create pages in the New Frontend System.
 */

import React from 'react';
import { PageBlueprint } from '@backstage/frontend-plugin-api';
import { createRouteRef } from '@backstage/core-plugin-api';

// ==============================================
// 1. Basic Page with PageBlueprint
// ==============================================

export const basicPageExtension = PageBlueprint.make({
  name: 'basic',
  params: {
    // Default path (can be overridden in app-config.yaml)
    defaultPath: '/basic',

    // Lazy-loaded component
    loader: async () => {
      const { BasicPage } = await import('./pages/BasicPage');
      return <BasicPage />;
    },
  },
});

// Generated extension ID: page:{namespace}/basic
// Attaches to: app/routes
// Provides: reactElement, routePath

// ==============================================
// 2. Page with Route Ref
// ==============================================

export const detailRouteRef = createRouteRef({
  id: 'example:detail',
});

export const detailPageExtension = PageBlueprint.make({
  name: 'detail',
  params: {
    defaultPath: '/detail/:id',
    routeRef: detailRouteRef,
    loader: async () => {
      const { DetailPage } = await import('./pages/DetailPage');
      return <DetailPage />;
    },
  },
});

// Now other plugins can navigate using the route ref:
// const detailRoute = useRouteRef(detailRouteRef);
// navigate(detailRoute({ id: '123' }));

// ==============================================
// 3. Page with Configuration Schema
// ==============================================

export const configurablePageExtension = PageBlueprint.make({
  name: 'configurable',
  params: {
    defaultPath: '/configurable',
    loader: async () => {
      const { ConfigurablePage } = await import('./pages/ConfigurablePage');
      return <ConfigurablePage />;
    },
  },
  // Add configuration schema
  configSchema: PageBlueprint.makeConfigSchema({
    showWelcome: {
      type: 'boolean',
      default: true,
    },
    itemsPerPage: {
      type: 'number',
      default: 20,
    },
  }),
});

// Configure in app-config.yaml:
// app:
//   extensions:
//     - page:example/configurable:
//         config:
//           showWelcome: false
//           itemsPerPage: 50

// ==============================================
// 4. Multiple Pages in a Plugin
// ==============================================

/**
 * import { createFrontendPlugin } from '@backstage/frontend-plugin-api';
 *
 * export const examplePlugin = createFrontendPlugin({
 *   id: 'example',
 *   extensions: [
 *     // Index page
 *     PageBlueprint.make({
 *       name: 'index',
 *       params: {
 *         defaultPath: '/example',
 *         loader: async () => {
 *           const { IndexPage } = await import('./pages/IndexPage');
 *           return <IndexPage />;
 *         },
 *       },
 *     }),
 *
 *     // Detail page with parameter
 *     PageBlueprint.make({
 *       name: 'detail',
 *       params: {
 *         defaultPath: '/example/:id',
 *         loader: async () => {
 *           const { DetailPage } = await import('./pages/DetailPage');
 *           return <DetailPage />;
 *         },
 *       },
 *     }),
 *
 *     // Settings page
 *     PageBlueprint.make({
 *       name: 'settings',
 *       params: {
 *         defaultPath: '/example/settings',
 *         loader: async () => {
 *           const { SettingsPage } = await import('./pages/SettingsPage');
 *           return <SettingsPage />;
 *         },
 *       },
 *     }),
 *   ],
 * });
 */

// ==============================================
// 5. Page Component Examples
// ==============================================

// pages/BasicPage.tsx
/**
 * import React from 'react';
 * import { Page, Header, Content } from '@backstage/core-components';
 *
 * export const BasicPage = () => {
 *   return (
 *     <Page themeId="tool">
 *       <Header title="Basic Page" subtitle="Created with PageBlueprint" />
 *       <Content>
 *         <div>
 *           <h1>Welcome to the Basic Page</h1>
 *           <p>This page was created using PageBlueprint.</p>
 *         </div>
 *       </Content>
 *     </Page>
 *   );
 * };
 */

// pages/DetailPage.tsx
/**
 * import React from 'react';
 * import { useParams } from 'react-router-dom';
 * import { Page, Header, Content } from '@backstage/core-components';
 *
 * export const DetailPage = () => {
 *   const { id } = useParams();
 *
 *   return (
 *     <Page themeId="tool">
 *       <Header title={`Detail: ${id}`} />
 *       <Content>
 *         <div>
 *           <h1>Detail Page</h1>
 *           <p>Viewing details for item: {id}</p>
 *         </div>
 *       </Content>
 *     </Page>
 *   );
 * };
 */

// ==============================================
// 6. Advanced: Custom Page Blueprint
// ==============================================

/**
 * You can create custom blueprints for specialized page types:
 *
 * import { createExtensionBlueprint } from '@backstage/frontend-plugin-api';
 *
 * export const DashboardPageBlueprint = createExtensionBlueprint({
 *   kind: 'dashboard-page',
 *   attachTo: { id: 'app/routes', input: 'routes' },
 *   output: {
 *     element: coreExtensionData.reactElement,
 *     path: coreExtensionData.routePath,
 *   },
 *   factory: (params: {
 *     title: string;
 *     widgets: React.ComponentType[];
 *     refreshInterval?: number;
 *   }) => {
 *     return {
 *       element: (
 *         <DashboardLayout
 *           title={params.title}
 *           widgets={params.widgets}
 *           refreshInterval={params.refreshInterval}
 *         />
 *       ),
 *       path: `/${params.title.toLowerCase().replace(/\s+/g, '-')}`,
 *     };
 *   },
 * });
 *
 * // Usage:
 * const myDashboard = DashboardPageBlueprint.make({
 *   name: 'my-dashboard',
 *   params: {
 *     title: 'My Dashboard',
 *     widgets: [StatsWidget, ChartWidget],
 *     refreshInterval: 60000,
 *   },
 * });
 */

// ==============================================
// 7. PageBlueprint vs createExtension
// ==============================================

/**
 * PREFER PageBlueprint:
 * - Less boilerplate
 * - Correct attachment point automatically
 * - Built-in configuration support
 * - Path override support
 * - Route ref integration
 *
 * Use createExtension only for:
 * - Custom extension kinds
 * - Non-page extensions
 * - When you need full control over inputs/outputs
 */

// With PageBlueprint (recommended):
const pageWithBlueprint = PageBlueprint.make({
  name: 'example',
  params: {
    defaultPath: '/example',
    loader: async () => <ExamplePage />,
  },
});

// With createExtension (more verbose):
/**
 * const pageWithCreateExtension = createExtension({
 *   id: 'page:namespace/example',
 *   attachTo: { id: 'app/routes', input: 'routes' },
 *   output: {
 *     element: coreExtensionData.reactElement,
 *     path: coreExtensionData.routePath,
 *   },
 *   factory: () => ({
 *     element: <ExamplePage />,
 *     path: '/example',
 *   }),
 * });
 */

// ==============================================
// Summary
// ==============================================

/**
 * PageBlueprint benefits:
 *
 * 1. Simple API for common use case
 * 2. Lazy loading built-in
 * 3. Path can be overridden via config
 * 4. Route refs supported
 * 5. Type-safe
 * 6. Consistent naming
 *
 * Best practices:
 *
 * - Always use lazy loading (loader function)
 * - Provide sensible default paths
 * - Use route refs for navigation between pages
 * - Add configuration schemas for customizable pages
 * - Keep page components in separate files
 */
