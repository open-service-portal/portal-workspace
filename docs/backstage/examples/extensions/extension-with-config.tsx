/**
 * Extension with Configuration Schema Example
 *
 * This example shows how to create extensions that can be configured
 * via app-config.yaml using Zod schemas.
 */

import React from 'react';
import {
  createExtension,
  coreExtensionData,
  createSchemaFromZod,
} from '@backstage/frontend-plugin-api';
import { Page, Header, Content } from '@backstage/core-components';

// ==============================================
// Extension with Simple Configuration
// ==============================================

export const configurablePageExtension = createExtension({
  id: 'page:example/configurable',
  attachTo: { id: 'app/routes', input: 'routes' },

  // Define configuration schema using Zod
  configSchema: createSchemaFromZod((z) =>
    z.object({
      title: z.string().default('Configurable Page'),
      subtitle: z.string().optional(),
      showMetrics: z.boolean().default(true),
      refreshInterval: z.number().min(5).max(300).default(60),
      theme: z.enum(['light', 'dark', 'auto']).default('auto'),
    }),
  ),

  output: {
    element: coreExtensionData.reactElement,
    path: coreExtensionData.routePath,
  },

  factory: ({ config }) => {
    // Access configuration values
    const {
      title,
      subtitle,
      showMetrics,
      refreshInterval,
      theme,
    } = config;

    return {
      element: (
        <Page themeId="tool">
          <Header
            title={title}
            subtitle={subtitle || `Refresh every ${refreshInterval}s | Theme: ${theme}`}
          />
          <Content>
            <div>
              <h2>Configuration Values:</h2>
              <ul>
                <li><strong>Title:</strong> {title}</li>
                <li><strong>Subtitle:</strong> {subtitle || 'Not set'}</li>
                <li><strong>Show Metrics:</strong> {showMetrics ? 'Yes' : 'No'}</li>
                <li><strong>Refresh Interval:</strong> {refreshInterval} seconds</li>
                <li><strong>Theme:</strong> {theme}</li>
              </ul>

              {showMetrics && (
                <div>
                  <h3>Metrics Dashboard</h3>
                  <p>Metrics are displayed because showMetrics is enabled.</p>
                </div>
              )}
            </div>
          </Content>
        </Page>
      ),
      path: '/configurable',
    };
  },
});

// ==============================================
// Configuration in app-config.yaml
// ==============================================

/**
 * app:
 *   extensions:
 *     - page:example/configurable:
 *         config:
 *           title: "Custom Dashboard"
 *           subtitle: "Powered by Configuration"
 *           showMetrics: true
 *           refreshInterval: 30
 *           theme: dark
 */

// ==============================================
// Extension with Complex Configuration
// ==============================================

export const advancedConfigExtension = createExtension({
  id: 'page:example/advanced-config',
  attachTo: { id: 'app/routes', input: 'routes' },

  configSchema: createSchemaFromZod((z) =>
    z.object({
      // Nested objects
      display: z.object({
        title: z.string().default('Advanced Page'),
        showHeader: z.boolean().default(true),
        columns: z.number().min(1).max(12).default(3),
      }),

      // Arrays
      features: z.array(z.enum(['analytics', 'notifications', 'search'])).default(['analytics']),

      // Optional nested object
      apiConfig: z.object({
        endpoint: z.string().url(),
        timeout: z.number().default(5000),
        retries: z.number().default(3),
      }).optional(),

      // Discriminated unions
      authMode: z.discriminatedUnion('type', [
        z.object({
          type: z.literal('basic'),
          username: z.string(),
          password: z.string(),
        }),
        z.object({
          type: z.literal('token'),
          token: z.string(),
        }),
        z.object({
          type: z.literal('none'),
        }),
      ]).default({ type: 'none' }),
    }),
  ),

  output: {
    element: coreExtensionData.reactElement,
    path: coreExtensionData.routePath,
  },

  factory: ({ config }) => {
    const { display, features, apiConfig, authMode } = config;

    return {
      element: (
        <Page themeId="tool">
          {display.showHeader && (
            <Header title={display.title} subtitle="Advanced Configuration Example" />
          )}
          <Content>
            <div>
              <h2>Display Settings:</h2>
              <ul>
                <li>Columns: {display.columns}</li>
                <li>Show Header: {display.showHeader ? 'Yes' : 'No'}</li>
              </ul>

              <h2>Enabled Features:</h2>
              <ul>
                {features.map(feature => (
                  <li key={feature}>{feature}</li>
                ))}
              </ul>

              {apiConfig && (
                <>
                  <h2>API Configuration:</h2>
                  <ul>
                    <li>Endpoint: {apiConfig.endpoint}</li>
                    <li>Timeout: {apiConfig.timeout}ms</li>
                    <li>Retries: {apiConfig.retries}</li>
                  </ul>
                </>
              )}

              <h2>Auth Mode:</h2>
              <p>Type: {authMode.type}</p>
              {authMode.type === 'basic' && <p>Username: {authMode.username}</p>}
              {authMode.type === 'token' && <p>Token: {authMode.token.substring(0, 10)}...</p>}
            </div>
          </Content>
        </Page>
      ),
      path: '/advanced-config',
    };
  },
});

// ==============================================
// Complex Configuration in app-config.yaml
// ==============================================

/**
 * app:
 *   extensions:
 *     - page:example/advanced-config:
 *         config:
 *           display:
 *             title: "Production Dashboard"
 *             showHeader: true
 *             columns: 4
 *
 *           features:
 *             - analytics
 *             - notifications
 *             - search
 *
 *           apiConfig:
 *             endpoint: "https://api.example.com/v1"
 *             timeout: 10000
 *             retries: 5
 *
 *           authMode:
 *             type: token
 *             token: "${API_TOKEN}"  # Environment variable
 */

// ==============================================
// Environment-Specific Configuration
// ==============================================

/**
 * Development (app-config.local.yaml):
 *
 * app:
 *   extensions:
 *     - page:example/advanced-config:
 *         config:
 *           apiConfig:
 *             endpoint: "http://localhost:7007/api"
 *           authMode:
 *             type: none
 *
 * Production (app-config.production.yaml):
 *
 * app:
 *   extensions:
 *     - page:example/advanced-config:
 *         config:
 *           apiConfig:
 *             endpoint: "https://api.prod.example.com/v1"
 *             timeout: 30000
 *           authMode:
 *             type: token
 *             token: "${PROD_API_TOKEN}"
 */

// ==============================================
// Validation Benefits
// ==============================================

/**
 * Zod provides automatic validation:
 *
 * 1. Type Safety: TypeScript knows the exact shape
 * 2. Runtime Validation: Invalid configs rejected at startup
 * 3. Default Values: Missing values use defaults
 * 4. Constraints: min/max, url validation, enums, etc.
 * 5. Error Messages: Clear errors for invalid configs
 *
 * Example error:
 * "Invalid configuration for extension page:example/advanced-config:
 *  - display.columns: Number must be less than or equal to 12
 *  - apiConfig.endpoint: Invalid url
 *  - authMode.type: Invalid enum value. Expected 'basic' | 'token' | 'none'"
 */
