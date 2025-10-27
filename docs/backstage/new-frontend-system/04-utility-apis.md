# Utility APIs

> **Version**: Backstage v1.42.0+
> **Status**: Complete Reference
> **Last Updated**: 2025-10-27

## Overview

Utility APIs are reusable services that provide functionality to components and extensions throughout your Backstage app. They enable dependency injection, separation of concerns, and testability.

This guide covers creating, registering, and consuming Utility APIs in the New Frontend System.

## Table of Contents

1. [What Are Utility APIs?](#what-are-utility-apis)
2. [Standard Utility APIs](#standard-utility-apis)
3. [Creating API Refs](#creating-api-refs)
4. [Implementing APIs](#implementing-apis)
5. [Registering APIs](#registering-apis)
6. [Consuming APIs](#consuming-apis)
7. [API Dependencies](#api-dependencies)
8. [Testing with APIs](#testing-with-apis)
9. [Best Practices](#best-practices)

---

## What Are Utility APIs?

Utility APIs are **services** that provide common functionality across your Backstage app. They follow a dependency injection pattern where:

1. **API Reference** - Defines the contract (interface)
2. **API Implementation** - Provides the functionality
3. **API Registration** - Makes the API available to the app
4. **API Consumption** - Components use the API via hooks

### Why Utility APIs?

**Abstraction**: Hide implementation details behind interfaces

**Dependency Injection**: Components receive dependencies rather than creating them

**Testability**: Easy to mock APIs in tests

**Reusability**: Share logic across plugins and components

**Type Safety**: TypeScript interfaces ensure correct usage

---

## Standard Utility APIs

Backstage provides many standard Utility APIs out of the box.

### Core APIs

```typescript
import {
  configApiRef,
  discoveryApiRef,
  identityApiRef,
  fetchApiRef,
  errorApiRef,
  storageApiRef,
  analyticsApiRef,
  alertApiRef,
} from '@backstage/core-plugin-api';
```

#### configApiRef

Access app configuration from `app-config.yaml`.

```typescript
interface ConfigApi {
  get<T>(key?: string): T | undefined;
  getOptional<T>(key?: string): T | undefined;
  getConfig(key: string): Config;
  getOptionalConfig(key: string): Config | undefined;
  has(key: string): boolean;
  keys(): string[];
}
```

**Usage**:
```typescript
const configApi = useApi(configApiRef);
const appTitle = configApi.getString('app.title');
const backendUrl = configApi.getString('backend.baseUrl');
```

#### discoveryApiRef

Discover backend plugin URLs.

```typescript
interface DiscoveryApi {
  getBaseUrl(pluginId: string): Promise<string>;
}
```

**Usage**:
```typescript
const discoveryApi = useApi(discoveryApiRef);
const catalogUrl = await discoveryApi.getBaseUrl('catalog');
// Returns: http://localhost:7007/api/catalog
```

#### identityApiRef

Get current user identity and credentials.

```typescript
interface IdentityApi {
  getUserId(): string;
  getIdToken(): Promise<string | undefined>;
  getProfile(): ProfileInfo;
  getProfileInfo(): Promise<ProfileInfo>;
  getBackstageIdentity(): Promise<BackstageIdentity>;
  getCredentials(): Promise<{ token?: string }>;
  signOut(): Promise<void>;
}
```

**Usage**:
```typescript
const identityApi = useApi(identityApiRef);
const profile = await identityApi.getProfileInfo();
const credentials = await identityApi.getCredentials();
```

#### fetchApiRef

Make HTTP requests with automatic auth header injection.

```typescript
interface FetchApi {
  fetch(input: string | Request, init?: RequestInit): Promise<Response>;
}
```

**Usage**:
```typescript
const fetchApi = useApi(fetchApiRef);
const response = await fetchApi.fetch('/api/catalog/entities');
const data = await response.json();
```

#### errorApiRef

Post errors to centralized error handling.

```typescript
interface ErrorApi {
  post(error: Error, context?: ErrorContext): void;
  error$(options?: ErrorApiErrorOptions): Observable<{ error: Error; context?: ErrorContext }>;
}
```

**Usage**:
```typescript
const errorApi = useApi(errorApiRef);
try {
  await riskyOperation();
} catch (error) {
  errorApi.post(error);
}
```

#### storageApiRef

Browser storage with namespacing and observability.

```typescript
interface StorageApi {
  set<T>(key: string, data: T): void;
  get<T>(key: string): T | undefined;
  remove(key: string): void;
  observe$<T>(key: string): Observable<{ key: string; newValue: T | undefined }>;
}
```

**Usage**:
```typescript
const storageApi = useApi(storageApiRef);
storageApi.set('theme', 'dark');
const theme = storageApi.get<string>('theme');
```

### Auth APIs

```typescript
import {
  githubAuthApiRef,
  googleAuthApiRef,
  oktaAuthApiRef,
  microsoftAuthApiRef,
} from '@backstage/core-plugin-api';
```

All auth APIs implement common interfaces:

```typescript
interface OAuthApi {
  getAccessToken(scope?: string | string[], options?: AuthRequestOptions): Promise<string>;
}

interface OpenIdConnectApi {
  getIdToken(options?: AuthRequestOptions): Promise<string>;
}

interface ProfileInfoApi {
  getProfile(options?: AuthRequestOptions): Promise<ProfileInfo>;
}

interface BackstageIdentityApi {
  getBackstageIdentity(options?: AuthRequestOptions): Promise<BackstageIdentity>;
}

interface SessionApi {
  signIn(): Promise<void>;
  signOut(): Promise<void>;
  sessionState$(): Observable<SessionState>;
}
```

**Usage**:
```typescript
const githubAuth = useApi(githubAuthApiRef);
await githubAuth.signIn();
const token = await githubAuth.getAccessToken();
const profile = await githubAuth.getProfile();
```

### Plugin-Specific APIs

Many plugins provide their own APIs:

```typescript
import { catalogApiRef } from '@backstage/plugin-catalog-react';
import { scaffolderApiRef } from '@backstage/plugin-scaffolder-react';
import { techdocsStorageApiRef } from '@backstage/plugin-techdocs-react';
```

---

## Creating API Refs

An API ref defines the contract for your API.

### Basic API Ref

```typescript
import { createApiRef } from '@backstage/core-plugin-api';

export interface WeatherApi {
  getCurrentWeather(location: string): Promise<WeatherData>;
  getForecast(location: string, days: number): Promise<ForecastData>;
}

export const weatherApiRef = createApiRef<WeatherApi>({
  id: 'plugin.weather.api',
});
```

### API Ref with Multiple Interfaces

Some APIs implement multiple interfaces:

```typescript
export interface CustomAuthApi
  extends OAuthApi,
          OpenIdConnectApi,
          ProfileInfoApi,
          BackstageIdentityApi,
          SessionApi {
  // Additional custom methods
  refreshToken(): Promise<void>;
}

export const customAuthApiRef = createApiRef<CustomAuthApi>({
  id: 'plugin.custom-auth.api',
});
```

### Generic API Ref

```typescript
export interface CacheApi<T> {
  get(key: string): Promise<T | undefined>;
  set(key: string, value: T, ttl?: number): Promise<void>;
  delete(key: string): Promise<void>;
  clear(): Promise<void>;
}

export const cacheApiRef = createApiRef<CacheApi<any>>({
  id: 'plugin.cache.api',
});
```

---

## Implementing APIs

Create a class that implements your API interface.

### Basic Implementation

```typescript
import { WeatherApi, weatherApiRef } from './api';
import { DiscoveryApi, FetchApi } from '@backstage/core-plugin-api';

export class WeatherApiClient implements WeatherApi {
  private readonly discoveryApi: DiscoveryApi;
  private readonly fetchApi: FetchApi;

  constructor(options: {
    discoveryApi: DiscoveryApi;
    fetchApi: FetchApi;
  }) {
    this.discoveryApi = options.discoveryApi;
    this.fetchApi = options.fetchApi;
  }

  async getCurrentWeather(location: string): Promise<WeatherData> {
    const baseUrl = await this.discoveryApi.getBaseUrl('weather');
    const response = await this.fetchApi.fetch(
      `${baseUrl}/current?location=${encodeURIComponent(location)}`
    );
    if (!response.ok) {
      throw new Error(`Failed to fetch weather: ${response.statusText}`);
    }
    return await response.json();
  }

  async getForecast(location: string, days: number): Promise<ForecastData> {
    const baseUrl = await this.discoveryApi.getBaseUrl('weather');
    const response = await this.fetchApi.fetch(
      `${baseUrl}/forecast?location=${encodeURIComponent(location)}&days=${days}`
    );
    if (!response.ok) {
      throw new Error(`Failed to fetch forecast: ${response.statusText}`);
    }
    return await response.json();
  }
}
```

### Implementation with Configuration

```typescript
export class WeatherApiClient implements WeatherApi {
  private readonly apiKey: string;
  private readonly fetchApi: FetchApi;

  constructor(options: {
    configApi: ConfigApi;
    fetchApi: FetchApi;
  }) {
    this.apiKey = options.configApi.getString('weather.apiKey');
    this.fetchApi = options.fetchApi;
  }

  async getCurrentWeather(location: string): Promise<WeatherData> {
    const response = await this.fetchApi.fetch(
      `https://api.weather.com/current?location=${location}&apiKey=${this.apiKey}`
    );
    return await response.json();
  }
}
```

### Implementation with Caching

```typescript
export class CachedWeatherApiClient implements WeatherApi {
  private readonly delegate: WeatherApi;
  private readonly cache = new Map<string, { data: any; expires: number }>();

  constructor(delegate: WeatherApi) {
    this.delegate = delegate;
  }

  async getCurrentWeather(location: string): Promise<WeatherData> {
    const cacheKey = `current:${location}`;
    const cached = this.cache.get(cacheKey);

    if (cached && cached.expires > Date.now()) {
      return cached.data;
    }

    const data = await this.delegate.getCurrentWeather(location);
    this.cache.set(cacheKey, {
      data,
      expires: Date.now() + 5 * 60 * 1000, // 5 minutes
    });

    return data;
  }

  async getForecast(location: string, days: number): Promise<ForecastData> {
    return this.delegate.getForecast(location, days);
  }
}
```

---

## Registering APIs

APIs must be registered to make them available to components.

### Using ApiBlueprint (Recommended)

```typescript
import { ApiBlueprint } from '@backstage/frontend-plugin-api';
import {
  discoveryApiRef,
  fetchApiRef
} from '@backstage/core-plugin-api';
import { weatherApiRef, WeatherApiClient } from './api';

export const weatherApi = ApiBlueprint.make({
  name: 'weather',
  params: {
    api: weatherApiRef,
    deps: {
      discoveryApi: discoveryApiRef,
      fetchApi: fetchApiRef,
    },
    factory: ({ discoveryApi, fetchApi }) => {
      return new WeatherApiClient({ discoveryApi, fetchApi });
    },
  },
});
```

### Registering in Frontend Module

```typescript
import { createFrontendModule } from '@backstage/frontend-plugin-api';
import { weatherApi } from './apis';

export const weatherModule = createFrontendModule({
  pluginId: 'weather',
  extensions: [weatherApi],
});
```

### Registering in App

```typescript
import { createApp } from '@backstage/frontend-defaults';
import { weatherModule } from '@backstage-community/plugin-weather';

const app = createApp({
  features: [
    weatherModule,
    // other features...
  ],
});
```

### With Configuration

```typescript
export const weatherApi = ApiBlueprint.make({
  name: 'weather',
  params: {
    api: weatherApiRef,
    deps: {
      configApi: configApiRef,
      fetchApi: fetchApiRef,
    },
    factory: ({ configApi, fetchApi }) => {
      const enabled = configApi.getOptionalBoolean('weather.enabled') ?? true;

      if (!enabled) {
        return new MockWeatherApiClient();
      }

      return new WeatherApiClient({ configApi, fetchApi });
    },
  },
});
```

---

## Consuming APIs

Components consume APIs using the `useApi` hook.

### Basic Usage

```typescript
import React from 'react';
import { useApi } from '@backstage/core-plugin-api';
import { weatherApiRef } from '../api';

export const WeatherWidget = () => {
  const weatherApi = useApi(weatherApiRef);
  const [weather, setWeather] = React.useState<WeatherData | null>(null);

  React.useEffect(() => {
    weatherApi.getCurrentWeather('New York').then(setWeather);
  }, [weatherApi]);

  if (!weather) {
    return <div>Loading...</div>;
  }

  return (
    <div>
      <h2>Current Weather</h2>
      <p>Temperature: {weather.temperature}°F</p>
      <p>Conditions: {weather.conditions}</p>
    </div>
  );
};
```

### With Error Handling

```typescript
export const WeatherWidget = () => {
  const weatherApi = useApi(weatherApiRef);
  const errorApi = useApi(errorApiRef);
  const [weather, setWeather] = React.useState<WeatherData | null>(null);
  const [loading, setLoading] = React.useState(true);

  React.useEffect(() => {
    let mounted = true;

    weatherApi.getCurrentWeather('New York')
      .then(data => {
        if (mounted) {
          setWeather(data);
          setLoading(false);
        }
      })
      .catch(error => {
        errorApi.post(error);
        setLoading(false);
      });

    return () => {
      mounted = false;
    };
  }, [weatherApi, errorApi]);

  if (loading) {
    return <div>Loading...</div>;
  }

  if (!weather) {
    return <div>Failed to load weather</div>;
  }

  return <div>{/* ... */}</div>;
};
```

### Using Multiple APIs

```typescript
export const UserDashboard = () => {
  const identityApi = useApi(identityApiRef);
  const catalogApi = useApi(catalogApiRef);
  const weatherApi = useApi(weatherApiRef);

  const [profile, setProfile] = React.useState<ProfileInfo | null>(null);
  const [entities, setEntities] = React.useState<Entity[]>([]);
  const [weather, setWeather] = React.useState<WeatherData | null>(null);

  React.useEffect(() => {
    Promise.all([
      identityApi.getProfileInfo(),
      catalogApi.getEntities({ filter: { kind: 'Component' } }),
      weatherApi.getCurrentWeather('New York'),
    ]).then(([profileData, entitiesData, weatherData]) => {
      setProfile(profileData);
      setEntities(entitiesData.items);
      setWeather(weatherData);
    });
  }, [identityApi, catalogApi, weatherApi]);

  return <div>{/* ... */}</div>;
};
```

### Optional API Usage

```typescript
import { useApi, useApiOptional } from '@backstage/core-plugin-api';
import { analyticsApiRef } from '@backstage/core-plugin-api';

export const TrackedButton = () => {
  // Optional: returns undefined if API not registered
  const analyticsApi = useApiOptional(analyticsApiRef);

  const handleClick = () => {
    // Track only if analytics is available
    analyticsApi?.captureEvent('button_clicked', { button: 'submit' });

    // Do actual work
    submitForm();
  };

  return <button onClick={handleClick}>Submit</button>;
};
```

---

## API Dependencies

APIs can depend on other APIs.

### Simple Dependencies

```typescript
export const notificationApi = ApiBlueprint.make({
  name: 'notification',
  params: {
    api: notificationApiRef,
    deps: {
      alertApi: alertApiRef,
      storageApi: storageApiRef,
    },
    factory: ({ alertApi, storageApi }) => {
      return new NotificationApiClient({ alertApi, storageApi });
    },
  },
});
```

### Complex Dependencies

```typescript
export const complexApi = ApiBlueprint.make({
  name: 'complex',
  params: {
    api: complexApiRef,
    deps: {
      configApi: configApiRef,
      discoveryApi: discoveryApiRef,
      fetchApi: fetchApiRef,
      identityApi: identityApiRef,
      storageApi: storageApiRef,
      errorApi: errorApiRef,
    },
    factory: (deps) => {
      return new ComplexApiClient(deps);
    },
  },
});
```

### Conditional Dependencies

```typescript
export const analyticsApi = ApiBlueprint.make({
  name: 'analytics',
  params: {
    api: analyticsApiRef,
    deps: {
      configApi: configApiRef,
      identityApi: identityApiRef,
    },
    factory: ({ configApi, identityApi }) => {
      const provider = configApi.getOptionalString('analytics.provider');

      switch (provider) {
        case 'google':
          return new GoogleAnalyticsClient({ configApi, identityApi });
        case 'segment':
          return new SegmentAnalyticsClient({ configApi, identityApi });
        default:
          return new NoOpAnalyticsClient();
      }
    },
  },
});
```

---

## Testing with APIs

Utility APIs make components highly testable.

### Mocking APIs in Tests

```typescript
import { TestApiProvider } from '@backstage/test-utils';
import { weatherApiRef } from '../api';

const mockWeatherApi: Partial<WeatherApi> = {
  getCurrentWeather: jest.fn().mockResolvedValue({
    temperature: 72,
    conditions: 'Sunny',
  }),
};

describe('WeatherWidget', () => {
  it('displays weather data', async () => {
    const { getByText } = render(
      <TestApiProvider apis={[[weatherApiRef, mockWeatherApi]]}>
        <WeatherWidget />
      </TestApiProvider>
    );

    await waitFor(() => {
      expect(getByText(/Temperature: 72/)).toBeInTheDocument();
      expect(getByText(/Conditions: Sunny/)).toBeInTheDocument();
    });
  });
});
```

### Testing API Implementations

```typescript
describe('WeatherApiClient', () => {
  let weatherApi: WeatherApiClient;
  let mockDiscoveryApi: jest.Mocked<DiscoveryApi>;
  let mockFetchApi: jest.Mocked<FetchApi>;

  beforeEach(() => {
    mockDiscoveryApi = {
      getBaseUrl: jest.fn().mockResolvedValue('http://localhost:7007/api/weather'),
    };

    mockFetchApi = {
      fetch: jest.fn(),
    };

    weatherApi = new WeatherApiClient({
      discoveryApi: mockDiscoveryApi,
      fetchApi: mockFetchApi,
    });
  });

  it('fetches current weather', async () => {
    mockFetchApi.fetch.mockResolvedValue({
      ok: true,
      json: async () => ({ temperature: 72, conditions: 'Sunny' }),
    } as Response);

    const result = await weatherApi.getCurrentWeather('New York');

    expect(result).toEqual({ temperature: 72, conditions: 'Sunny' });
    expect(mockFetchApi.fetch).toHaveBeenCalledWith(
      'http://localhost:7007/api/weather/current?location=New%20York'
    );
  });

  it('handles errors', async () => {
    mockFetchApi.fetch.mockResolvedValue({
      ok: false,
      statusText: 'Not Found',
    } as Response);

    await expect(weatherApi.getCurrentWeather('InvalidLocation'))
      .rejects.toThrow('Failed to fetch weather: Not Found');
  });
});
```

---

## Best Practices

### 1. Define Clear Interfaces

**Good**:
```typescript
export interface WeatherApi {
  /** Get current weather for a location */
  getCurrentWeather(location: string): Promise<WeatherData>;

  /** Get weather forecast for the next N days */
  getForecast(location: string, days: number): Promise<ForecastData>;
}
```

**Avoid**:
```typescript
export interface WeatherApi {
  get(type: string, ...args: any[]): Promise<any>;
}
```

### 2. Use Descriptive API Ref IDs

**Good**:
```typescript
createApiRef<WeatherApi>({
  id: 'plugin.weather.api',  // Namespaced, descriptive
});
```

**Avoid**:
```typescript
createApiRef<WeatherApi>({
  id: 'weather',  // Too generic, collision risk
});
```

### 3. Handle Errors Gracefully

**Good**:
```typescript
async getCurrentWeather(location: string): Promise<WeatherData> {
  const response = await this.fetchApi.fetch(url);

  if (!response.ok) {
    throw new Error(
      `Weather API error: ${response.status} ${response.statusText}`
    );
  }

  return await response.json();
}
```

### 4. Cache When Appropriate

```typescript
export class CachedApiClient implements MyApi {
  private cache = new Map<string, CacheEntry>();

  async getData(key: string): Promise<Data> {
    const cached = this.cache.get(key);
    if (cached && !this.isExpired(cached)) {
      return cached.data;
    }

    const fresh = await this.fetchFreshData(key);
    this.cache.set(key, { data: fresh, timestamp: Date.now() });
    return fresh;
  }
}
```

### 5. Make APIs Testable

- Accept dependencies via constructor
- Use interfaces, not concrete classes
- Avoid global state
- Return promises for async operations

### 6. Document Your APIs

```typescript
/**
 * API for interacting with the weather backend.
 *
 * @public
 */
export interface WeatherApi {
  /**
   * Get current weather conditions for a location.
   *
   * @param location - City name or coordinates
   * @returns Current weather data
   * @throws {Error} If location is invalid or API is unavailable
   */
  getCurrentWeather(location: string): Promise<WeatherData>;
}
```

### 7. Version Your API Refs

When making breaking changes, create new API refs:

```typescript
// Old version (deprecated)
export const weatherApiRef = createApiRef<WeatherApi>({
  id: 'plugin.weather.api',
});

// New version
export const weatherApiV2Ref = createApiRef<WeatherApiV2>({
  id: 'plugin.weather.api.v2',
});
```

### 8. Use TypeScript Strictly

```typescript
// Define strict types
export interface WeatherData {
  temperature: number;
  conditions: string;
  humidity: number;
  windSpeed: number;
}

// Not 'any'
export interface WeatherApi {
  getCurrentWeather(location: string): Promise<WeatherData>;  // ✓
  // getCurrentWeather(location: string): Promise<any>;       // ✗
}
```

---

## Common Patterns

### Pattern 1: Backend API Client

```typescript
export class BackendApiClient implements MyApi {
  constructor(
    private readonly discoveryApi: DiscoveryApi,
    private readonly fetchApi: FetchApi,
  ) {}

  async getData(id: string): Promise<Data> {
    const baseUrl = await this.discoveryApi.getBaseUrl('my-plugin');
    const response = await this.fetchApi.fetch(`${baseUrl}/data/${id}`);

    if (!response.ok) {
      throw new Error(`API error: ${response.statusText}`);
    }

    return await response.json();
  }
}
```

### Pattern 2: Configuration-Based API

```typescript
export class ConfigurableApiClient implements MyApi {
  private readonly endpoint: string;
  private readonly timeout: number;

  constructor(configApi: ConfigApi, fetchApi: FetchApi) {
    this.endpoint = configApi.getString('myPlugin.endpoint');
    this.timeout = configApi.getOptionalNumber('myPlugin.timeout') ?? 30000;
    // ...
  }
}
```

### Pattern 3: Delegating API

```typescript
export class LoggingApiDecorator implements MyApi {
  constructor(
    private readonly delegate: MyApi,
    private readonly logger: Logger,
  ) {}

  async getData(id: string): Promise<Data> {
    this.logger.info(`Fetching data for ${id}`);
    const result = await this.delegate.getData(id);
    this.logger.info(`Fetched data for ${id}`);
    return result;
  }
}
```

### Pattern 4: Observable API

```typescript
export interface RealtimeApi {
  subscribe(topic: string): Observable<Message>;
}

export class WebSocketRealtimeApi implements RealtimeApi {
  subscribe(topic: string): Observable<Message> {
    return new Observable(subscriber => {
      const ws = new WebSocket(`wss://api.example.com/${topic}`);

      ws.onmessage = (event) => {
        subscriber.next(JSON.parse(event.data));
      };

      ws.onerror = (error) => {
        subscriber.error(error);
      };

      return () => {
        ws.close();
      };
    });
  }
}
```

---

## Summary

**Key Takeaways**:

1. **Utility APIs provide reusable services** - Configuration, HTTP, identity, storage, etc.
2. **Use ApiBlueprint** - Simplifies registration and dependency injection
3. **Define clear interfaces** - TypeScript interfaces ensure correct usage
4. **Inject dependencies** - Makes APIs testable and flexible
5. **useApi hook** - Components consume APIs via hooks
6. **Standard APIs available** - config, discovery, identity, fetch, error, storage, auth
7. **Test with mocks** - TestApiProvider makes components highly testable

**Next Steps**:
- [Learn about Auth Providers →](./05-auth-providers.md)
- [Build Plugins →](./06-plugin-development.md)
- [Understand Extensions →](./03-extensions.md)

---

**Navigation**:
- [← Previous: Extensions](./03-extensions.md)
- [Next: Auth Providers →](./05-auth-providers.md)
- [Back to INDEX](./INDEX.md)
