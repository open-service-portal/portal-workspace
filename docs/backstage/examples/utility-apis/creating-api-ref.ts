/**
 * Creating API Refs Example
 *
 * This example shows how to create API references (contracts/interfaces)
 * for utility APIs in Backstage.
 */

import { createApiRef } from '@backstage/core-plugin-api';

// ==============================================
// 1. Basic API Ref
// ==============================================

export interface WeatherApi {
  getCurrentWeather(location: string): Promise<WeatherData>;
  getForecast(location: string, days: number): Promise<ForecastData>;
}

export interface WeatherData {
  temperature: number;
  conditions: string;
  humidity: number;
  windSpeed: number;
}

export interface ForecastData {
  location: string;
  forecast: Array<{
    date: string;
    temperature: { high: number; low: number };
    conditions: string;
  }>;
}

export const weatherApiRef = createApiRef<WeatherApi>({
  id: 'plugin.weather.api',  // Unique namespaced ID
});

// ==============================================
// 2. API Ref with Multiple Interfaces
// ==============================================

/**
 * Some APIs implement multiple standard interfaces.
 * This is common for auth providers.
 */

import {
  OAuthApi,
  OpenIdConnectApi,
  ProfileInfoApi,
  BackstageIdentityApi,
  SessionApi,
} from '@backstage/core-plugin-api';

export interface CustomAuthApi
  extends OAuthApi,
          OpenIdConnectApi,
          ProfileInfoApi,
          BackstageIdentityApi,
          SessionApi {
  // Add custom methods
  refreshToken(): Promise<void>;
  revokeToken(): Promise<void>;
}

export const customAuthApiRef = createApiRef<CustomAuthApi>({
  id: 'plugin.custom-auth.api',
});

// ==============================================
// 3. Generic API Ref
// ==============================================

/**
 * Create generic APIs that can work with different data types.
 */

export interface CacheApi<T = any> {
  get(key: string): Promise<T | undefined>;
  set(key: string, value: T, ttlSeconds?: number): Promise<void>;
  delete(key: string): Promise<void>;
  clear(): Promise<void>;
  keys(): Promise<string[]>;
}

export const cacheApiRef = createApiRef<CacheApi>({
  id: 'plugin.cache.api',
});

// Usage with specific type:
// const stringCache: CacheApi<string> = useApi(cacheApiRef);

// ==============================================
// 4. Read-Only API Ref
// ==============================================

/**
 * For APIs that only provide data, no mutations.
 */

export interface MetricsApi {
  readonly getMetrics: (filters?: MetricFilters) => Promise<Metric[]>;
  readonly getMetric: (id: string) => Promise<Metric>;
  readonly subscribeToMetrics: (callback: (metrics: Metric[]) => void) => () => void;
}

export interface Metric {
  id: string;
  name: string;
  value: number;
  unit: string;
  timestamp: Date;
}

export interface MetricFilters {
  tags?: string[];
  startDate?: Date;
  endDate?: Date;
}

export const metricsApiRef = createApiRef<MetricsApi>({
  id: 'plugin.metrics.api',
});

// ==============================================
// 5. Event-Based API Ref
// ==============================================

/**
 * APIs that use Observable patterns for real-time updates.
 */

import { Observable } from '@backstage/types';

export interface NotificationApi {
  notify(message: Notification): void;
  notifications$(): Observable<Notification>;
  markAsRead(id: string): Promise<void>;
  clearAll(): Promise<void>;
}

export interface Notification {
  id: string;
  type: 'info' | 'warning' | 'error' | 'success';
  message: string;
  timestamp: Date;
  read: boolean;
}

export const notificationApiRef = createApiRef<NotificationApi>({
  id: 'plugin.notification.api',
});

// ==============================================
// 6. Async Initialization API
// ==============================================

/**
 * APIs that need initialization before use.
 */

export interface DatabaseApi {
  initialize(): Promise<void>;
  isInitialized(): boolean;
  query<T>(sql: string, params?: any[]): Promise<T[]>;
  execute(sql: string, params?: any[]): Promise<number>;
  transaction<T>(callback: (tx: Transaction) => Promise<T>): Promise<T>;
}

export interface Transaction {
  query<T>(sql: string, params?: any[]): Promise<T[]>;
  execute(sql: string, params?: any[]): Promise<number>;
}

export const databaseApiRef = createApiRef<DatabaseApi>({
  id: 'plugin.database.api',
});

// ==============================================
// 7. Plugin-Specific API Ref
// ==============================================

/**
 * APIs specific to a plugin's domain.
 */

export interface CatalogEnhancementApi {
  enrichEntity(entity: Entity): Promise<EnrichedEntity>;
  getRelatedEntities(entityRef: string): Promise<Entity[]>;
  calculateMetrics(entity: Entity): Promise<EntityMetrics>;
}

export interface EnrichedEntity {
  entity: Entity;
  relatedCount: number;
  lastUpdated: Date;
  healthScore: number;
}

export interface EntityMetrics {
  deploymentFrequency: number;
  changeFailureRate: number;
  meanTimeToRestore: number;
  leadTime: number;
}

export const catalogEnhancementApiRef = createApiRef<CatalogEnhancementApi>({
  id: 'plugin.catalog-enhancement.api',
});

// ==============================================
// Best Practices for API Refs
// ==============================================

/**
 * 1. Use namespaced IDs:
 *    - Good: 'plugin.weather.api'
 *    - Bad: 'weather' (too generic)
 *
 * 2. Define clear interfaces:
 *    - Document all methods with JSDoc
 *    - Use TypeScript types, not 'any'
 *    - Define all DTOs/models
 *
 * 3. Consider versioning for breaking changes:
 *    - 'plugin.weather.api.v1'
 *    - 'plugin.weather.api.v2'
 *
 * 4. Group related types:
 *    - Keep API ref and related types together
 *    - Export from single file for discoverability
 *
 * 5. Use standard interfaces when applicable:
 *    - Extend OAuthApi, ProfileInfoApi, etc.
 *    - Consistent patterns across plugins
 *
 * 6. Make APIs testable:
 *    - Interfaces, not concrete classes
 *    - Pure functions where possible
 *    - Observable for reactive data
 */

// ==============================================
// Example: Complete API Module
// ==============================================

/**
 * // api/index.ts - Single export point
 *
 * export { weatherApiRef, type WeatherApi } from './WeatherApi';
 * export type { WeatherData, ForecastData } from './types';
 */

/**
 * // api/WeatherApi.ts
 *
 * import { createApiRef } from '@backstage/core-plugin-api';
 * import type { WeatherData, ForecastData } from './types';
 *
 * export interface WeatherApi {
 *   getCurrentWeather(location: string): Promise<WeatherData>;
 *   getForecast(location: string, days: number): Promise<ForecastData>;
 * }
 *
 * export const weatherApiRef = createApiRef<WeatherApi>({
 *   id: 'plugin.weather.api',
 * });
 */

/**
 * // api/types.ts
 *
 * export interface WeatherData {
 *   temperature: number;
 *   conditions: string;
 *   humidity: number;
 *   windSpeed: number;
 * }
 *
 * export interface ForecastData {
 *   location: string;
 *   forecast: DayForecast[];
 * }
 *
 * export interface DayForecast {
 *   date: string;
 *   temperature: { high: number; low: number };
 *   conditions: string;
 * }
 */
