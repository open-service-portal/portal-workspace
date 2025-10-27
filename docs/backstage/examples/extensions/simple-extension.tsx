/**
 * Simple Extension Example
 *
 * This example shows how to create a basic extension using createExtension.
 * For most use cases, prefer using Blueprints (PageBlueprint, ApiBlueprint, etc.)
 * but createExtension gives you full control when needed.
 */

import React from 'react';
import {
  createExtension,
  coreExtensionData,
} from '@backstage/frontend-plugin-api';
import { Page, Header, Content } from '@backstage/core-components';

// Simple page extension
export const simplePageExtension = createExtension({
  // Unique extension ID: kind:namespace/name
  id: 'page:example/simple',

  // Where this extension attaches in the extension tree
  attachTo: { id: 'app/routes', input: 'routes' },

  // What this extension provides to its parent
  output: {
    element: coreExtensionData.reactElement,
    path: coreExtensionData.routePath,
  },

  // Factory function that creates the extension's output
  factory: () => {
    return {
      element: (
        <Page themeId="tool">
          <Header title="Simple Page" subtitle="Created with createExtension" />
          <Content>
            <div>
              <h1>Hello from Simple Extension!</h1>
              <p>This page was created using createExtension directly.</p>
            </div>
          </Content>
        </Page>
      ),
      path: '/simple',
    };
  },
});

/**
 * Using the extension in a plugin:
 *
 * import { createFrontendPlugin } from '@backstage/frontend-plugin-api';
 * import { simplePageExtension } from './extensions';
 *
 * export const examplePlugin = createFrontendPlugin({
 *   id: 'example',
 *   extensions: [simplePageExtension],
 * });
 */

/**
 * Better Alternative: Use PageBlueprint
 *
 * import { PageBlueprint } from '@backstage/frontend-plugin-api';
 *
 * export const simplePageExtension = PageBlueprint.make({
 *   name: 'simple',
 *   params: {
 *     defaultPath: '/simple',
 *     loader: async () => {
 *       const { SimplePage } = await import('./components/SimplePage');
 *       return <SimplePage />;
 *     },
 *   },
 * });
 */
