/**
 * Extension with Inputs Example
 *
 * This example demonstrates how to create a parent extension that accepts
 * child extensions through inputs.
 */

import React from 'react';
import {
  createExtension,
  createExtensionInput,
  coreExtensionData,
} from '@backstage/frontend-plugin-api';
import { Page, Header, Content } from '@backstage/core-components';
import { Grid } from '@material-ui/core';

// ==============================================
// Parent Extension: Dashboard with Widget Slots
// ==============================================

export const dashboardPageExtension = createExtension({
  id: 'page:example/dashboard',
  attachTo: { id: 'app/routes', input: 'routes' },

  // Define inputs: what child extensions this accepts
  inputs: {
    // Accepts multiple widget extensions
    widgets: createExtensionInput(
      {
        element: coreExtensionData.reactElement,
      },
      { optional: true }, // Widgets are optional
    ),

    // Accepts exactly one header extension
    header: createExtensionInput(
      {
        element: coreExtensionData.reactElement,
      },
      { singleton: true, optional: true },
    ),
  },

  output: {
    element: coreExtensionData.reactElement,
    path: coreExtensionData.routePath,
  },

  factory: ({ inputs }) => {
    // Access child extensions' outputs
    const widgetElements = inputs.widgets?.map((widget, index) => (
      <Grid item xs={12} md={6} key={index}>
        {widget.output.element}
      </Grid>
    )) ?? [];

    const headerElement = inputs.header?.output.element;

    return {
      element: (
        <Page themeId="home">
          {headerElement || <Header title="Dashboard" />}
          <Content>
            <Grid container spacing={3}>
              {widgetElements.length > 0 ? (
                widgetElements
              ) : (
                <Grid item xs={12}>
                  <p>No widgets available. Add widget extensions to populate the dashboard.</p>
                </Grid>
              )}
            </Grid>
          </Content>
        </Page>
      ),
      path: '/dashboard',
    };
  },
});

// ==============================================
// Child Extension 1: Stats Widget
// ==============================================

export const statsWidgetExtension = createExtension({
  id: 'widget:example/stats',
  // Attach to dashboard's widgets input
  attachTo: { id: 'page:example/dashboard', input: 'widgets' },

  output: {
    element: coreExtensionData.reactElement,
  },

  factory: () => ({
    element: (
      <div style={{ padding: 16, border: '1px solid #ccc', borderRadius: 4 }}>
        <h3>Stats Widget</h3>
        <p>Total Users: 1,234</p>
        <p>Active Sessions: 56</p>
      </div>
    ),
  }),
});

// ==============================================
// Child Extension 2: Recent Activity Widget
// ==============================================

export const recentActivityWidgetExtension = createExtension({
  id: 'widget:example/recent-activity',
  attachTo: { id: 'page:example/dashboard', input: 'widgets' },

  output: {
    element: coreExtensionData.reactElement,
  },

  factory: () => ({
    element: (
      <div style={{ padding: 16, border: '1px solid #ccc', borderRadius: 4 }}>
        <h3>Recent Activity</h3>
        <ul>
          <li>User logged in - 2 minutes ago</li>
          <li>New component created - 10 minutes ago</li>
          <li>System deployed - 1 hour ago</li>
        </ul>
      </div>
    ),
  }),
});

// ==============================================
// Child Extension 3: Custom Header
// ==============================================

export const dashboardHeaderExtension = createExtension({
  id: 'header:example/dashboard',
  attachTo: { id: 'page:example/dashboard', input: 'header' },

  output: {
    element: coreExtensionData.reactElement,
  },

  factory: () => ({
    element: (
      <Header
        title="Custom Dashboard"
        subtitle="Powered by Extension Inputs"
      />
    ),
  }),
});

// ==============================================
// Usage in Plugin
// ==============================================

/**
 * import { createFrontendPlugin } from '@backstage/frontend-plugin-api';
 *
 * export const examplePlugin = createFrontendPlugin({
 *   id: 'example',
 *   extensions: [
 *     // Parent extension
 *     dashboardPageExtension,
 *
 *     // Child extensions (will attach automatically)
 *     statsWidgetExtension,
 *     recentActivityWidgetExtension,
 *     dashboardHeaderExtension,
 *   ],
 * });
 */

// ==============================================
// Configuration Override Example
// ==============================================

/**
 * Users can add custom widgets via configuration:
 *
 * // app-config.yaml
 * app:
 *   extensions:
 *     # Disable a specific widget
 *     - widget:example/stats:
 *         disabled: true
 *
 *     # Add a widget from another plugin
 *     - widget:other-plugin/custom:
 *         attachTo:
 *           id: page:example/dashboard
 *           input: widgets
 */

// ==============================================
// Input Options
// ==============================================

/**
 * createExtensionInput options:
 *
 * 1. optional: true/false
 *    - true: Child extensions are optional (0 or more)
 *    - false: At least one child extension required
 *
 * 2. singleton: true/false
 *    - true: Exactly one child extension allowed
 *    - false: Multiple child extensions allowed (default)
 *
 * Examples:
 *
 * // Optional, multiple children
 * widgets: createExtensionInput({ ... }, { optional: true })
 *
 * // Required, multiple children
 * tabs: createExtensionInput({ ... }, { optional: false })
 *
 * // Optional, exactly one child
 * header: createExtensionInput({ ... }, { singleton: true, optional: true })
 *
 * // Required, exactly one child
 * content: createExtensionInput({ ... }, { singleton: true, optional: false })
 */
