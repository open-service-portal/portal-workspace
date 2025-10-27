/**
 * Basic App Creation Example
 *
 * This example shows the minimal setup for creating a Backstage app
 * using the New Frontend System.
 *
 * @see https://backstage.io/docs/frontend-system/building-apps/create-an-app
 */

import React from 'react';
import { createApp } from '@backstage/frontend-defaults';

// Create the app with default features
const app = createApp({
  // Auto-discovery is enabled by default when using @backstage/frontend-defaults
  // All plugins with /alpha exports will be discovered automatically
});

// Export the app root
export default app.createRoot();

/**
 * That's it! With auto-discovery enabled, the app will automatically:
 *
 * 1. Discover all installed plugins from package.json
 * 2. Load their /alpha exports
 * 3. Register all extensions (pages, APIs, themes, etc.)
 * 4. Create routes automatically
 * 5. Set up navigation
 *
 * No manual imports or configuration needed!
 */
