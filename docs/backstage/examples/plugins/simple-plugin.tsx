/**
 * Simple Plugin Example
 *
 * This example shows how to create a complete frontend plugin
 * for the New Frontend System with a single page.
 */

// ==================================================
// File: src/plugin.ts
// ==================================================

import { createFrontendPlugin } from '@backstage/frontend-plugin-api';
import { PageBlueprint } from '@backstage/frontend-plugin-api';
import { createRouteRef } from '@backstage/core-plugin-api';

// Create route ref for navigation
export const rootRouteRef = createRouteRef({
  id: 'my-plugin:root',
});

// Create the plugin
export const myPlugin = createFrontendPlugin({
  id: 'my-plugin',
  extensions: [
    // Main page
    PageBlueprint.make({
      name: 'root',
      params: {
        defaultPath: '/my-plugin',
        routeRef: rootRouteRef,
        loader: async () => {
          const { MyPluginPage } = await import('./components/MyPluginPage');
          return <MyPluginPage />;
        },
      },
    }),
  ],
});

// ==================================================
// File: src/alpha.ts
// ==================================================

/**
 * @alpha
 * My Plugin - A simple example plugin
 */
export { myPlugin as default } from './plugin';

// Optionally export route ref for external use
export { rootRouteRef } from './plugin';

// ==================================================
// File: src/index.ts (Legacy support)
// ==================================================

// Export components for legacy frontend system
export { MyPluginPage } from './components/MyPluginPage';

// ==================================================
// File: src/components/MyPluginPage/MyPluginPage.tsx
// ==================================================

import React from 'react';
import { Page, Header, Content, InfoCard } from '@backstage/core-components';
import { Grid } from '@material-ui/core';

export const MyPluginPage = () => {
  return (
    <Page themeId="tool">
      <Header
        title="My Plugin"
        subtitle="A simple example plugin for the New Frontend System"
      />
      <Content>
        <Grid container spacing={3}>
          <Grid item xs={12} md={6}>
            <InfoCard title="Welcome">
              <p>This is a simple plugin created with the New Frontend System.</p>
              <ul>
                <li>Uses PageBlueprint for easy page creation</li>
                <li>Supports auto-discovery</li>
                <li>Can be configured via app-config.yaml</li>
              </ul>
            </InfoCard>
          </Grid>

          <Grid item xs={12} md={6}>
            <InfoCard title="Features">
              <ul>
                <li>Single page extension</li>
                <li>Lazy-loaded component</li>
                <li>Material-UI integration</li>
                <li>Responsive grid layout</li>
              </ul>
            </InfoCard>
          </Grid>
        </Grid>
      </Content>
    </Page>
  );
};

// ==================================================
// File: src/components/MyPluginPage/index.ts
// ==================================================

export { MyPluginPage } from './MyPluginPage';

// ==================================================
// File: package.json
// ==================================================

/**
 * {
 *   "name": "@internal/plugin-my-plugin",
 *   "version": "0.1.0",
 *   "main": "src/index.ts",
 *   "types": "src/index.ts",
 *   "exports": {
 *     ".": "./src/index.ts",
 *     "./alpha": "./src/alpha.ts",
 *     "./package.json": "./package.json"
 *   },
 *   "backstage": {
 *     "role": "frontend-plugin"
 *   },
 *   "dependencies": {
 *     "@backstage/core-components": "^0.15.0",
 *     "@backstage/core-plugin-api": "^1.10.0",
 *     "@backstage/frontend-plugin-api": "^0.9.0",
 *     "@material-ui/core": "^4.12.4",
 *     "react": "^18.0.0"
 *   },
 *   "peerDependencies": {
 *     "react": "^18.0.0"
 *   }
 * }
 */

// ==================================================
// File: dev/index.tsx (Development environment)
// ==================================================

/**
 * import React from 'react';
 * import { createDevApp } from '@backstage/dev-utils';
 * import { myPlugin } from '../src/plugin';
 *
 * createDevApp()
 *   .registerPlugin(myPlugin)
 *   .render();
 */

// ==================================================
// Usage in App
// ==================================================

/**
 * The plugin is automatically discovered if you have auto-discovery enabled:
 *
 * // app-config.yaml
 * app:
 *   packages:
 *     - all
 *
 * Or manually install:
 *
 * // App.tsx
 * import myPlugin from '@internal/plugin-my-plugin/alpha';
 *
 * const app = createApp({
 *   features: [myPlugin],
 * });
 */

// ==================================================
// Configuration Override
// ==================================================

/**
 * Users can override the default path in app-config.yaml:
 *
 * app:
 *   extensions:
 *     - page:my-plugin/root:
 *         config:
 *           path: /custom-path  # Override /my-plugin
 *
 * Or disable the plugin:
 *
 * app:
 *   extensions:
 *     - page:my-plugin/root:
 *         disabled: true
 */

// ==================================================
// Directory Structure
// ==================================================

/**
 * plugins/my-plugin/
 * ├── package.json
 * ├── src/
 * │   ├── index.ts           # Legacy exports
 * │   ├── alpha.ts           # New frontend system exports
 * │   ├── plugin.ts          # Plugin definition
 * │   └── components/
 * │       └── MyPluginPage/
 * │           ├── MyPluginPage.tsx
 * │           └── index.ts
 * ├── dev/
 * │   └── index.tsx          # Development environment
 * └── README.md
 */

// ==================================================
// Testing
// ==================================================

/**
 * // src/components/MyPluginPage/MyPluginPage.test.tsx
 *
 * import React from 'react';
 * import { render } from '@testing-library/react';
 * import { TestApiProvider } from '@backstage/test-utils';
 * import { MyPluginPage } from './MyPluginPage';
 *
 * describe('MyPluginPage', () => {
 *   it('renders without crashing', () => {
 *     const { getByText } = render(
 *       <TestApiProvider apis={[]}>
 *         <MyPluginPage />
 *       </TestApiProvider>
 *     );
 *
 *     expect(getByText('My Plugin')).toBeInTheDocument();
 *     expect(getByText('Welcome')).toBeInTheDocument();
 *   });
 * });
 */

// ==================================================
// README.md
// ==================================================

/**
 * # My Plugin
 *
 * A simple Backstage plugin for the New Frontend System.
 *
 * ## Installation
 *
 * ```bash
 * yarn add @internal/plugin-my-plugin
 * ```
 *
 * ## Usage
 *
 * ### New Frontend System (Recommended)
 *
 * The plugin is automatically discovered if you have auto-discovery enabled:
 *
 * ```yaml
 * # app-config.yaml
 * app:
 *   packages:
 *     - all
 * ```
 *
 * Or manually install:
 *
 * ```typescript
 * // App.tsx
 * import myPlugin from '@internal/plugin-my-plugin/alpha';
 *
 * const app = createApp({
 *   features: [myPlugin],
 * });
 * ```
 *
 * ### Legacy Frontend System
 *
 * ```typescript
 * // App.tsx
 * import { MyPluginPage } from '@internal/plugin-my-plugin';
 *
 * const routes = (
 *   <FlatRoutes>
 *     <Route path="/my-plugin" element={<MyPluginPage />} />
 *   </FlatRoutes>
 * );
 * ```
 *
 * ## Configuration
 *
 * You can customize the plugin path in app-config.yaml:
 *
 * ```yaml
 * app:
 *   extensions:
 *     - page:my-plugin/root:
 *         config:
 *           path: /custom-path
 * ```
 *
 * ## Development
 *
 * ```bash
 * yarn start # Starts dev environment
 * yarn build # Build the plugin
 * yarn test  # Run tests
 * yarn lint  # Lint code
 * ```
 */
