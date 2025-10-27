/**
 * Consuming APIs Example
 *
 * This example shows various patterns for consuming utility APIs in components.
 */

import React from 'react';
import { useApi, useApiOptional } from '@backstage/core-plugin-api';
import {
  identityApiRef,
  errorApiRef,
  configApiRef,
  analyticsApiRef,
} from '@backstage/core-plugin-api';
import { weatherApiRef } from './creating-api-ref';

// ==============================================
// 1. Basic API Usage
// ==============================================

export const BasicWeatherComponent = () => {
  const weatherApi = useApi(weatherApiRef);
  const [weather, setWeather] = React.useState(null);

  React.useEffect(() => {
    weatherApi.getCurrentWeather('New York').then(setWeather);
  }, [weatherApi]);

  return <div>{weather && <p>Temperature: {weather.temperature}°F</p>}</div>;
};

// ==============================================
// 2. API Usage with Error Handling
// ==============================================

export const WeatherWithErrorHandling = () => {
  const weatherApi = useApi(weatherApiRef);
  const errorApi = useApi(errorApiRef);

  const [weather, setWeather] = React.useState(null);
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
        if (mounted) {
          errorApi.post(error);  // Send to error handler
          setLoading(false);
        }
      });

    return () => {
      mounted = false;
    };
  }, [weatherApi, errorApi]);

  if (loading) return <div>Loading...</div>;
  if (!weather) return <div>Failed to load weather</div>;

  return <div>Temperature: {weather.temperature}°F</div>;
};

// ==============================================
// 3. Using Multiple APIs
// ==============================================

export const UserDashboard = () => {
  const identityApi = useApi(identityApiRef);
  const weatherApi = useApi(weatherApiRef);
  const configApi = useApi(configApiRef);

  const [userInfo, setUserInfo] = React.useState(null);
  const [weather, setWeather] = React.useState(null);
  const [location, setLocation] = React.useState('');

  React.useEffect(() => {
    // Get user's default location from config
    const defaultLocation = configApi.getOptionalString('weather.defaultLocation') ?? 'New York';
    setLocation(defaultLocation);

    // Fetch user profile and weather in parallel
    Promise.all([
      identityApi.getProfileInfo(),
      weatherApi.getCurrentWeather(defaultLocation),
    ]).then(([profile, weatherData]) => {
      setUserInfo(profile);
      setWeather(weatherData);
    });
  }, [identityApi, weatherApi, configApi]);

  if (!userInfo || !weather) return <div>Loading...</div>;

  return (
    <div>
      <h2>Welcome, {userInfo.displayName}!</h2>
      <p>Weather in {location}: {weather.temperature}°F, {weather.conditions}</p>
    </div>
  );
};

// ==============================================
// 4. Optional API Usage
// ==============================================

export const OptionalAnalyticsComponent = () => {
  // Use useApiOptional for APIs that might not be registered
  const analyticsApi = useApiOptional(analyticsApiRef);

  const handleClick = () => {
    // Track only if analytics is available
    analyticsApi?.captureEvent('button_clicked', {
      component: 'OptionalAnalyticsComponent',
      timestamp: new Date().toISOString(),
    });

    // Do actual work
    console.log('Button clicked');
  };

  return (
    <button onClick={handleClick}>
      Click me
      {analyticsApi && ' (Analytics enabled)'}
    </button>
  );
};

// ==============================================
// 5. Custom Hook for API
// ==============================================

/**
 * Create reusable hooks for common API patterns.
 */

interface UseWeatherOptions {
  location: string;
  refreshInterval?: number;
}

export function useWeather({ location, refreshInterval }: UseWeatherOptions) {
  const weatherApi = useApi(weatherApiRef);
  const errorApi = useApi(errorApiRef);

  const [weather, setWeather] = React.useState(null);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState(null);

  const fetchWeather = React.useCallback(async () => {
    try {
      setLoading(true);
      const data = await weatherApi.getCurrentWeather(location);
      setWeather(data);
      setError(null);
    } catch (err) {
      setError(err);
      errorApi.post(err);
    } finally {
      setLoading(false);
    }
  }, [weatherApi, errorApi, location]);

  // Initial fetch
  React.useEffect(() => {
    fetchWeather();
  }, [fetchWeather]);

  // Auto-refresh
  React.useEffect(() => {
    if (!refreshInterval) return;

    const interval = setInterval(fetchWeather, refreshInterval);
    return () => clearInterval(interval);
  }, [fetchWeather, refreshInterval]);

  return { weather, loading, error, refetch: fetchWeather };
}

// Usage:
export const WeatherWithHook = () => {
  const { weather, loading, error, refetch } = useWeather({
    location: 'San Francisco',
    refreshInterval: 60000, // Refresh every minute
  });

  if (loading) return <div>Loading...</div>;
  if (error) return <div>Error: {error.message}</div>;

  return (
    <div>
      <p>Temperature: {weather.temperature}°F</p>
      <button onClick={refetch}>Refresh</button>
    </div>
  );
};

// ==============================================
// 6. Async API Initialization
// ==============================================

/**
 * Some APIs need initialization before use.
 */

import { databaseApiRef } from './creating-api-ref';

export const DatabaseComponent = () => {
  const databaseApi = useApi(databaseApiRef);
  const [initialized, setInitialized] = React.useState(false);
  const [data, setData] = React.useState([]);

  React.useEffect(() => {
    let mounted = true;

    async function init() {
      if (!databaseApi.isInitialized()) {
        await databaseApi.initialize();
      }

      if (mounted) {
        setInitialized(true);
        const results = await databaseApi.query('SELECT * FROM items');
        setData(results);
      }
    }

    init();

    return () => {
      mounted = false;
    };
  }, [databaseApi]);

  if (!initialized) return <div>Initializing database...</div>;

  return (
    <ul>
      {data.map(item => (
        <li key={item.id}>{item.name}</li>
      ))}
    </ul>
  );
};

// ==============================================
// 7. Observable API Pattern
// ==============================================

/**
 * For APIs that provide real-time updates via Observables.
 */

import { notificationApiRef } from './creating-api-ref';

export const NotificationCenter = () => {
  const notificationApi = useApi(notificationApiRef);
  const [notifications, setNotifications] = React.useState([]);

  React.useEffect(() => {
    // Subscribe to notification stream
    const subscription = notificationApi.notifications$().subscribe({
      next: notification => {
        setNotifications(prev => [notification, ...prev].slice(0, 10));
      },
      error: err => console.error('Notification error:', err),
    });

    // Cleanup subscription
    return () => subscription.unsubscribe();
  }, [notificationApi]);

  const handleMarkAsRead = (id: string) => {
    notificationApi.markAsRead(id);
  };

  return (
    <div>
      <h3>Notifications</h3>
      {notifications.length === 0 && <p>No notifications</p>}
      <ul>
        {notifications.map(notif => (
          <li key={notif.id} style={{ opacity: notif.read ? 0.5 : 1 }}>
            <strong>{notif.type}:</strong> {notif.message}
            {!notif.read && (
              <button onClick={() => handleMarkAsRead(notif.id)}>
                Mark as read
              </button>
            )}
          </li>
        ))}
      </ul>
    </div>
  );
};

// ==============================================
// 8. API Usage in Class Components
// ==============================================

/**
 * For legacy class components (prefer functional components with hooks).
 */

import { withApis } from '@backstage/core-app-api';

interface WeatherClassProps {
  weatherApi: WeatherApi;
}

class WeatherClassComponentBase extends React.Component<WeatherClassProps> {
  state = { weather: null };

  componentDidMount() {
    this.props.weatherApi.getCurrentWeather('Boston').then(weather => {
      this.setState({ weather });
    });
  }

  render() {
    const { weather } = this.state;
    if (!weather) return <div>Loading...</div>;

    return <div>Temperature: {weather.temperature}°F</div>;
  }
}

export const WeatherClassComponent = withApis({
  weatherApi: weatherApiRef,
})(WeatherClassComponentBase);

// ==============================================
// 9. Testing Components with APIs
// ==============================================

/**
 * Mock APIs in tests using TestApiProvider.
 */

/**
 * import { render, waitFor } from '@testing-library/react';
 * import { TestApiProvider } from '@backstage/test-utils';
 * import { weatherApiRef } from './creating-api-ref';
 *
 * describe('WeatherComponent', () => {
 *   it('displays weather data', async () => {
 *     const mockWeatherApi = {
 *       getCurrentWeather: jest.fn().mockResolvedValue({
 *         temperature: 72,
 *         conditions: 'Sunny',
 *         humidity: 45,
 *         windSpeed: 5,
 *       }),
 *       getForecast: jest.fn(),
 *     };
 *
 *     const { getByText } = render(
 *       <TestApiProvider apis={[[weatherApiRef, mockWeatherApi]]}>
 *         <BasicWeatherComponent />
 *       </TestApiProvider>
 *     );
 *
 *     await waitFor(() => {
 *       expect(getByText(/Temperature: 72°F/)).toBeInTheDocument();
 *     });
 *
 *     expect(mockWeatherApi.getCurrentWeather).toHaveBeenCalledWith('New York');
 *   });
 * });
 */

// ==============================================
// Best Practices
// ==============================================

/**
 * 1. Always handle loading states
 * 2. Always handle errors
 * 3. Clean up effects (return cleanup function)
 * 4. Use useCallback for functions passed to effects
 * 5. Create custom hooks for reusable patterns
 * 6. Use optional APIs when appropriate
 * 7. Mock APIs in tests
 * 8. Avoid calling APIs on every render
 * 9. Consider caching for expensive calls
 * 10. Use Observables for real-time data
 */
