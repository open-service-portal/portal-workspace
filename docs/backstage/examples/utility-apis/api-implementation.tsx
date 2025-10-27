/**
 * API Implementation Example
 *
 * This example shows how to implement and register utility APIs.
 */

import React from 'react';
import {
  DiscoveryApi,
  FetchApi,
  ConfigApi,
} from '@backstage/core-plugin-api';
import { weatherApiRef, WeatherApi, WeatherData, ForecastData } from './creating-api-ref';

// ==============================================
// 1. Basic API Implementation
// ==============================================

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
    const url = `${baseUrl}/current?location=${encodeURIComponent(location)}`;

    const response = await this.fetchApi.fetch(url);

    if (!response.ok) {
      throw new Error(
        `Failed to fetch weather: ${response.status} ${response.statusText}`
      );
    }

    return await response.json();
  }

  async getForecast(location: string, days: number): Promise<ForecastData> {
    const baseUrl = await this.discoveryApi.getBaseUrl('weather');
    const url = `${baseUrl}/forecast?location=${encodeURIComponent(location)}&days=${days}`;

    const response = await this.fetchApi.fetch(url);

    if (!response.ok) {
      throw new Error(
        `Failed to fetch forecast: ${response.status} ${response.statusText}`
      );
    }

    return await response.json();
  }
}

// ==============================================
// 2. Register API using ApiBlueprint
// ==============================================

import { ApiBlueprint } from '@backstage/frontend-plugin-api';
import {
  discoveryApiRef,
  fetchApiRef,
} from '@backstage/core-plugin-api';

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

// ==============================================
// 3. Create Frontend Module
// ==============================================

import { createFrontendModule } from '@backstage/frontend-plugin-api';

export const weatherApiModule = createFrontendModule({
  pluginId: 'weather',
  extensions: [weatherApi],
});

// ==============================================
// 4. Install in App
// ==============================================

/**
 * // App.tsx
 * import { createApp } from '@backstage/frontend-defaults';
 * import { weatherApiModule } from '@internal/plugin-weather/alpha';
 *
 * const app = createApp({
 *   features: [weatherApiModule],
 * });
 *
 * export default app.createRoot();
 */

// ==============================================
// 5. Using the API in Components
// ==============================================

import { useApi } from '@backstage/core-plugin-api';

export const WeatherWidget = () => {
  const weatherApi = useApi(weatherApiRef);
  const [weather, setWeather] = React.useState<WeatherData | null>(null);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  React.useEffect(() => {
    let mounted = true;

    weatherApi.getCurrentWeather('New York')
      .then(data => {
        if (mounted) {
          setWeather(data);
          setLoading(false);
        }
      })
      .catch(err => {
        if (mounted) {
          setError(err.message);
          setLoading(false);
        }
      });

    return () => {
      mounted = false;
    };
  }, [weatherApi]);

  if (loading) return <div>Loading weather...</div>;
  if (error) return <div>Error: {error}</div>;
  if (!weather) return <div>No weather data</div>;

  return (
    <div>
      <h3>Current Weather</h3>
      <p>Temperature: {weather.temperature}°F</p>
      <p>Conditions: {weather.conditions}</p>
      <p>Humidity: {weather.humidity}%</p>
      <p>Wind Speed: {weather.windSpeed} mph</p>
    </div>
  );
};

// ==============================================
// 6. Implementation with Configuration
// ==============================================

export class ConfigurableWeatherApiClient implements WeatherApi {
  private readonly apiKey: string;
  private readonly baseUrl: string;
  private readonly fetchApi: FetchApi;

  constructor(options: {
    configApi: ConfigApi;
    fetchApi: FetchApi;
  }) {
    // Read configuration
    this.apiKey = options.configApi.getString('weather.apiKey');
    this.baseUrl = options.configApi.getOptionalString('weather.baseUrl')
      ?? 'https://api.weather.com';
    this.fetchApi = options.fetchApi;
  }

  async getCurrentWeather(location: string): Promise<WeatherData> {
    const url = `${this.baseUrl}/current?location=${encodeURIComponent(location)}&apiKey=${this.apiKey}`;
    const response = await this.fetchApi.fetch(url);

    if (!response.ok) {
      throw new Error(`Weather API error: ${response.statusText}`);
    }

    return await response.json();
  }

  async getForecast(location: string, days: number): Promise<ForecastData> {
    const url = `${this.baseUrl}/forecast?location=${encodeURIComponent(location)}&days=${days}&apiKey=${this.apiKey}`;
    const response = await this.fetchApi.fetch(url);

    if (!response.ok) {
      throw new Error(`Weather API error: ${response.statusText}`);
    }

    return await response.json();
  }
}

// Register configurable version
import { configApiRef } from '@backstage/core-plugin-api';

export const configurableWeatherApi = ApiBlueprint.make({
  name: 'weather',
  params: {
    api: weatherApiRef,
    deps: {
      configApi: configApiRef,
      fetchApi: fetchApiRef,
    },
    factory: ({ configApi, fetchApi }) => {
      return new ConfigurableWeatherApiClient({ configApi, fetchApi });
    },
  },
});

/**
 * Configuration in app-config.yaml:
 *
 * weather:
 *   apiKey: ${WEATHER_API_KEY}
 *   baseUrl: https://api.weather.com  # Optional, has default
 */

// ==============================================
// 7. Implementation with Caching
// ==============================================

export class CachedWeatherApiClient implements WeatherApi {
  private readonly delegate: WeatherApi;
  private readonly cache = new Map<string, {
    data: any;
    expires: number;
  }>();
  private readonly cacheTtl: number;

  constructor(delegate: WeatherApi, cacheTtl: number = 5 * 60 * 1000) {
    this.delegate = delegate;
    this.cacheTtl = cacheTtl;
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
      expires: Date.now() + this.cacheTtl,
    });

    return data;
  }

  async getForecast(location: string, days: number): Promise<ForecastData> {
    const cacheKey = `forecast:${location}:${days}`;
    const cached = this.cache.get(cacheKey);

    if (cached && cached.expires > Date.now()) {
      return cached.data;
    }

    const data = await this.delegate.getForecast(location, days);

    this.cache.set(cacheKey, {
      data,
      expires: Date.now() + this.cacheTtl,
    });

    return data;
  }
}

// Register cached version
export const cachedWeatherApi = ApiBlueprint.make({
  name: 'weather',
  params: {
    api: weatherApiRef,
    deps: {
      discoveryApi: discoveryApiRef,
      fetchApi: fetchApiRef,
      configApi: configApiRef,
    },
    factory: ({ discoveryApi, fetchApi, configApi }) => {
      const baseClient = new WeatherApiClient({ discoveryApi, fetchApi });
      const cacheTtl = configApi.getOptionalNumber('weather.cacheTtl') ?? 300000;

      return new CachedWeatherApiClient(baseClient, cacheTtl);
    },
  },
});

// ==============================================
// 8. Mock Implementation for Testing
// ==============================================

export class MockWeatherApiClient implements WeatherApi {
  async getCurrentWeather(location: string): Promise<WeatherData> {
    // Return mock data
    return {
      temperature: 72,
      conditions: 'Sunny',
      humidity: 45,
      windSpeed: 5,
    };
  }

  async getForecast(location: string, days: number): Promise<ForecastData> {
    return {
      location,
      forecast: Array.from({ length: days }, (_, i) => ({
        date: new Date(Date.now() + i * 24 * 60 * 60 * 1000).toISOString(),
        temperature: { high: 75, low: 60 },
        conditions: 'Partly Cloudy',
      })),
    };
  }
}

// Use mock in development
export const devWeatherApi = ApiBlueprint.make({
  name: 'weather',
  params: {
    api: weatherApiRef,
    deps: {},
    factory: () => {
      return new MockWeatherApiClient();
    },
  },
});

/**
 * Conditional registration based on environment:
 *
 * import { createFrontendModule } from '@backstage/frontend-plugin-api';
 *
 * export const weatherApiModule = createFrontendModule({
 *   pluginId: 'weather',
 *   extensions: [
 *     process.env.NODE_ENV === 'development'
 *       ? devWeatherApi
 *       : cachedWeatherApi
 *   ],
 * });
 */
