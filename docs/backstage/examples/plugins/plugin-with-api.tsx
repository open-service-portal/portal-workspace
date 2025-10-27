/**
 * Plugin with API Example
 *
 * This example shows how to create a plugin that provides both
 * a page extension and a utility API extension.
 */

// ==================================================
// File: src/api/types.ts
// ==================================================

export interface TaskData {
  id: string;
  title: string;
  status: 'pending' | 'in-progress' | 'completed';
  createdAt: Date;
  updatedAt: Date;
}

export interface CreateTaskRequest {
  title: string;
}

export interface UpdateTaskRequest {
  title?: string;
  status?: 'pending' | 'in-progress' | 'completed';
}

// ==================================================
// File: src/api/TaskApi.ts
// ==================================================

import { createApiRef } from '@backstage/core-plugin-api';
import type { TaskData, CreateTaskRequest, UpdateTaskRequest } from './types';

/**
 * API for managing tasks
 *
 * @public
 */
export interface TaskApi {
  /** Get all tasks */
  getTasks(): Promise<TaskData[]>;

  /** Get a specific task */
  getTask(id: string): Promise<TaskData>;

  /** Create a new task */
  createTask(request: CreateTaskRequest): Promise<TaskData>;

  /** Update an existing task */
  updateTask(id: string, request: UpdateTaskRequest): Promise<TaskData>;

  /** Delete a task */
  deleteTask(id: string): Promise<void>;
}

export const taskApiRef = createApiRef<TaskApi>({
  id: 'plugin.task.api',
});

// ==================================================
// File: src/api/TaskApiClient.ts
// ==================================================

import {
  DiscoveryApi,
  FetchApi,
} from '@backstage/core-plugin-api';
import { TaskApi, TaskData, CreateTaskRequest, UpdateTaskRequest } from './TaskApi';

export class TaskApiClient implements TaskApi {
  private readonly discoveryApi: DiscoveryApi;
  private readonly fetchApi: FetchApi;

  constructor(options: {
    discoveryApi: DiscoveryApi;
    fetchApi: FetchApi;
  }) {
    this.discoveryApi = options.discoveryApi;
    this.fetchApi = options.fetchApi;
  }

  private async getBaseUrl(): Promise<string> {
    return await this.discoveryApi.getBaseUrl('task');
  }

  async getTasks(): Promise<TaskData[]> {
    const baseUrl = await this.getBaseUrl();
    const response = await this.fetchApi.fetch(`${baseUrl}/tasks`);

    if (!response.ok) {
      throw new Error(`Failed to fetch tasks: ${response.statusText}`);
    }

    return await response.json();
  }

  async getTask(id: string): Promise<TaskData> {
    const baseUrl = await this.getBaseUrl();
    const response = await this.fetchApi.fetch(`${baseUrl}/tasks/${id}`);

    if (!response.ok) {
      throw new Error(`Failed to fetch task: ${response.statusText}`);
    }

    return await response.json();
  }

  async createTask(request: CreateTaskRequest): Promise<TaskData> {
    const baseUrl = await this.getBaseUrl();
    const response = await this.fetchApi.fetch(`${baseUrl}/tasks`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(request),
    });

    if (!response.ok) {
      throw new Error(`Failed to create task: ${response.statusText}`);
    }

    return await response.json();
  }

  async updateTask(id: string, request: UpdateTaskRequest): Promise<TaskData> {
    const baseUrl = await this.getBaseUrl();
    const response = await this.fetchApi.fetch(`${baseUrl}/tasks/${id}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(request),
    });

    if (!response.ok) {
      throw new Error(`Failed to update task: ${response.statusText}`);
    }

    return await response.json();
  }

  async deleteTask(id: string): Promise<void> {
    const baseUrl = await this.getBaseUrl();
    const response = await this.fetchApi.fetch(`${baseUrl}/tasks/${id}`, {
      method: 'DELETE',
    });

    if (!response.ok) {
      throw new Error(`Failed to delete task: ${response.statusText}`);
    }
  }
}

// ==================================================
// File: src/api/index.ts
// ==================================================

export { taskApiRef, type TaskApi } from './TaskApi';
export { TaskApiClient } from './TaskApiClient';
export type { TaskData, CreateTaskRequest, UpdateTaskRequest } from './types';

// ==================================================
// File: src/plugin.ts
// ==================================================

import { createFrontendPlugin } from '@backstage/frontend-plugin-api';
import { PageBlueprint, ApiBlueprint } from '@backstage/frontend-plugin-api';
import {
  discoveryApiRef,
  fetchApiRef,
} from '@backstage/core-plugin-api';
import { taskApiRef, TaskApiClient } from './api';

export const taskPlugin = createFrontendPlugin({
  id: 'task',
  extensions: [
    // API Extension
    ApiBlueprint.make({
      name: 'task-api',
      params: {
        api: taskApiRef,
        deps: {
          discoveryApi: discoveryApiRef,
          fetchApi: fetchApiRef,
        },
        factory: ({ discoveryApi, fetchApi }) =>
          new TaskApiClient({ discoveryApi, fetchApi }),
      },
    }),

    // Page Extension
    PageBlueprint.make({
      name: 'root',
      params: {
        defaultPath: '/tasks',
        loader: async () => {
          const { TaskListPage } = await import('./components/TaskListPage');
          return <TaskListPage />;
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
 * Task Plugin - Manage tasks in Backstage
 */
export { taskPlugin as default } from './plugin';

// Export API for use by other plugins
export { taskApiRef, type TaskApi } from './api';
export type { TaskData } from './api';

// ==================================================
// File: src/index.ts (Legacy support)
// ==================================================

// Legacy exports
export { TaskListPage } from './components/TaskListPage';
export { taskApiRef, type TaskApi, type TaskData } from './api';

// ==================================================
// File: src/components/TaskListPage/TaskListPage.tsx
// ==================================================

import React from 'react';
import { Page, Header, Content, InfoCard } from '@backstage/core-components';
import { useApi } from '@backstage/core-plugin-api';
import { taskApiRef, TaskData } from '../../api';
import {
  Table,
  TableHead,
  TableRow,
  TableCell,
  TableBody,
  Button,
  Chip,
} from '@material-ui/core';

export const TaskListPage = () => {
  const taskApi = useApi(taskApiRef);

  const [tasks, setTasks] = React.useState<TaskData[]>([]);
  const [loading, setLoading] = React.useState(true);

  const fetchTasks = React.useCallback(async () => {
    try {
      setLoading(true);
      const data = await taskApi.getTasks();
      setTasks(data);
    } catch (error) {
      console.error('Failed to fetch tasks:', error);
    } finally {
      setLoading(false);
    }
  }, [taskApi]);

  React.useEffect(() => {
    fetchTasks();
  }, [fetchTasks]);

  const handleStatusChange = async (id: string, status: TaskData['status']) => {
    try {
      await taskApi.updateTask(id, { status });
      await fetchTasks(); // Refresh list
    } catch (error) {
      console.error('Failed to update task:', error);
    }
  };

  const handleDelete = async (id: string) => {
    if (!window.confirm('Are you sure you want to delete this task?')) {
      return;
    }

    try {
      await taskApi.deleteTask(id);
      await fetchTasks(); // Refresh list
    } catch (error) {
      console.error('Failed to delete task:', error);
    }
  };

  const getStatusColor = (status: TaskData['status']) => {
    switch (status) {
      case 'completed':
        return 'primary';
      case 'in-progress':
        return 'secondary';
      default:
        return 'default';
    }
  };

  return (
    <Page themeId="tool">
      <Header title="Tasks" subtitle="Manage your tasks" />
      <Content>
        <InfoCard title="All Tasks">
          {loading && <p>Loading tasks...</p>}
          {!loading && tasks.length === 0 && <p>No tasks found.</p>}
          {!loading && tasks.length > 0 && (
            <Table>
              <TableHead>
                <TableRow>
                  <TableCell>Title</TableCell>
                  <TableCell>Status</TableCell>
                  <TableCell>Created</TableCell>
                  <TableCell>Actions</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {tasks.map(task => (
                  <TableRow key={task.id}>
                    <TableCell>{task.title}</TableCell>
                    <TableCell>
                      <Chip
                        label={task.status}
                        color={getStatusColor(task.status)}
                        size="small"
                      />
                    </TableCell>
                    <TableCell>
                      {new Date(task.createdAt).toLocaleDateString()}
                    </TableCell>
                    <TableCell>
                      {task.status !== 'completed' && (
                        <Button
                          size="small"
                          onClick={() => handleStatusChange(task.id, 'completed')}
                        >
                          Complete
                        </Button>
                      )}
                      <Button
                        size="small"
                        color="secondary"
                        onClick={() => handleDelete(task.id)}
                      >
                        Delete
                      </Button>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </InfoCard>
      </Content>
    </Page>
  );
};

// ==================================================
// File: package.json
// ==================================================

/**
 * {
 *   "name": "@internal/plugin-task",
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
 *   }
 * }
 */

// ==================================================
// Usage in Other Plugins
// ==================================================

/**
 * Other plugins can use the Task API:
 *
 * import { useApi } from '@backstage/core-plugin-api';
 * import { taskApiRef } from '@internal/plugin-task/alpha';
 *
 * export const MyComponent = () => {
 *   const taskApi = useApi(taskApiRef);
 *
 *   const handleCreateTask = async () => {
 *     const task = await taskApi.createTask({
 *       title: 'New task from another plugin',
 *     });
 *     console.log('Created task:', task);
 *   };
 *
 *   return <button onClick={handleCreateTask}>Create Task</button>;
 * };
 */

// ==================================================
// Directory Structure
// ==================================================

/**
 * plugins/task/
 * ├── package.json
 * ├── src/
 * │   ├── index.ts           # Legacy exports
 * │   ├── alpha.ts           # New frontend system exports
 * │   ├── plugin.ts          # Plugin definition
 * │   ├── api/
 * │   │   ├── index.ts       # API exports
 * │   │   ├── types.ts       # Type definitions
 * │   │   ├── TaskApi.ts     # API interface and ref
 * │   │   └── TaskApiClient.ts # API implementation
 * │   └── components/
 * │       └── TaskListPage/
 * │           ├── TaskListPage.tsx
 * │           └── index.ts
 * └── README.md
 */
