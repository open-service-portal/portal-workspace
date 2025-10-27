# Modular Configuration Architecture

The app-portal uses a modular configuration architecture that splits the traditional monolithic `app-config.yaml` into focused, manageable configuration modules. This improves maintainability, reduces merge conflicts, and makes configuration more discoverable.

## Overview

Instead of a single large configuration file, settings are organized into logical modules within the `app-config/` directory. Each module focuses on a specific aspect of the Backstage application.

## Configuration Structure

```
app-portal/
├── app-config.yaml          # Legacy config (kept for reference)
├── app-config/              # Modular configuration directory
│   ├── README.md           # Configuration documentation
│   ├── auth.yaml           # Authentication providers
│   ├── backend.yaml        # Backend service settings
│   ├── catalog.yaml        # Software catalog configuration
│   ├── ingestor.yaml       # Ingestor plugins configuration
│   ├── integrations.yaml   # SCM integrations (GitHub/GitLab)
│   ├── kubernetes.yaml     # Kubernetes cluster connections
│   ├── scaffolder.yaml     # Scaffolder templates settings
│   └── techdocs.yaml       # TechDocs configuration
```

## Module Descriptions

### auth.yaml - Authentication Configuration

Configures authentication providers and security settings:

```yaml
auth:
  environment: development
  providers:
    github:
      development:
        clientId: ${AUTH_GITHUB_CLIENT_ID}
        clientSecret: ${AUTH_GITHUB_CLIENT_SECRET}
  session:
    secret: ${SESSION_SECRET}
```

**Key settings:**
- OAuth providers (GitHub, GitLab, Google, etc.)
- Session management
- API key configuration
- Guest access policies

### backend.yaml - Backend Service Configuration

Core backend service settings:

```yaml
backend:
  baseUrl: http://localhost:7007
  listen:
    port: 7007
  cors:
    origin: http://localhost:3000
    methods: [GET, HEAD, PATCH, POST, PUT, DELETE]
    credentials: true
  database:
    client: better-sqlite3
    connection: ':memory:'
  reading:
    allow:
      - host: example.com
      - host: '*.mozilla.org'
```

**Key settings:**
- Server ports and URLs
- CORS configuration
- Database connections
- Content security policies
- Cache settings

### catalog.yaml - Software Catalog Configuration

Defines how the catalog discovers and processes entities:

```yaml
catalog:
  rules:
    - allow: [Component, System, API, Resource, Location, Template]
  locations:
    - type: url
      target: https://github.com/open-service-portal/app-portal/blob/main/catalog-info.yaml
  providers:
    github:
      providerId:
        organization: 'open-service-portal'
        catalogPath: '/catalog-info.yaml'
        filters:
          branch: 'main'
          repository: '.*'
        schedule:
          frequency: { minutes: 30 }
          timeout: { minutes: 3 }
```

**Key settings:**
- Entity discovery locations
- GitHub/GitLab organization scanning
- Processing rules and filters
- Refresh schedules
- Custom processors

### ingestor.yaml - Ingestor Plugins Configuration

Configuration for Kubernetes and Crossplane ingestors:

```yaml
kubernetesIngestor:
  enabled: true
  clusters:
    - name: local
      authProvider: serviceAccount
      skipTLSVerify: false
  schedule:
    frequency: { seconds: 60 }
    timeout: { seconds: 30 }

crossplaneIngestor:
  enabled: true
  defaultOwner: platform-team
  defaultSystem: crossplane
  xrdFilters:
    labelSelector: "openportal.dev/ingest=true"
  templateGeneration:
    generateApiEntities: true
    includeCompositionDetails: false
  caching:
    ttl: 300
    maxSize: 100
```

**Key settings:**
- Cluster connections
- Discovery intervals
- XRD filtering rules
- Template generation options
- Caching configuration

### integrations.yaml - SCM Integrations

Source control management integrations:

```yaml
integrations:
  github:
    - host: github.com
      token: ${GITHUB_TOKEN}
  gitlab:
    - host: gitlab.com
      token: ${GITLAB_TOKEN}
      apiBaseUrl: https://gitlab.com/api/v4
```

**Key settings:**
- GitHub/GitLab credentials
- Enterprise instances
- API endpoints
- Rate limiting

### kubernetes.yaml - Kubernetes Configuration

Kubernetes cluster connections:

```yaml
kubernetes:
  serviceLocatorMethod:
    type: 'multiTenant'
  clusterLocatorMethods:
    - type: 'config'
      clusters:
        - name: local-cluster
          url: https://kubernetes.default.svc
          authProvider: 'serviceAccount'
          skipTLSVerify: false
          serviceAccountToken: ${K8S_SA_TOKEN}
```

**Key settings:**
- Cluster authentication
- Service discovery
- TLS verification
- Custom resources

### scaffolder.yaml - Scaffolder Configuration

Template scaffolding settings:

```yaml
scaffolder:
  defaultAuthor:
    name: Scaffolder
    email: scaffolder@backstage.io
  defaultCommitMessage: "Initial commit"
```

**Key settings:**
- Default values
- Git configuration
- Custom actions
- Template locations

### techdocs.yaml - TechDocs Configuration

Documentation platform settings:

```yaml
techdocs:
  builder: 'local'
  generator:
    runIn: 'local'
  publisher:
    type: 'local'
```

**Key settings:**
- Build configuration
- Storage backends
- Publishing targets
- MkDocs settings

## Configuration Loading

The modular configuration is loaded by the enhanced `start.js` script:

```javascript
// start.js
const configPaths = [
  '--config', 'app-config.yaml',
  '--config', 'app-config/auth.yaml',
  '--config', 'app-config/backend.yaml',
  '--config', 'app-config/catalog.yaml',
  '--config', 'app-config/ingestor.yaml',
  '--config', 'app-config/integrations.yaml',
  '--config', 'app-config/kubernetes.yaml',
  '--config', 'app-config/scaffolder.yaml',
  '--config', 'app-config/techdocs.yaml'
];

// Environment-specific overrides
if (process.env.APP_CONFIG_ENV) {
  configPaths.push('--config', `app-config.${process.env.APP_CONFIG_ENV}.yaml`);
}
```

## Benefits

### 1. Improved Organization
- Logical grouping of related settings
- Easier to find specific configurations
- Clear separation of concerns

### 2. Better Collaboration
- Reduced merge conflicts
- Teams can own specific config modules
- Parallel development of features

### 3. Enhanced Maintainability
- Smaller, focused files
- Easier to review changes
- Simpler troubleshooting

### 4. Flexible Deployment
- Environment-specific overrides
- Feature flags per module
- Gradual rollout capabilities

## Migration Guide

### From Monolithic to Modular

1. **Backup existing configuration:**
   ```bash
   cp app-config.yaml app-config.yaml.backup
   ```

2. **Create app-config directory:**
   ```bash
   mkdir -p app-config
   ```

3. **Split configuration into modules:**
   - Move auth settings to `auth.yaml`
   - Move backend settings to `backend.yaml`
   - Continue for each module

4. **Update start script:**
   - Ensure `start.js` loads all modules
   - Test configuration loading

5. **Verify functionality:**
   ```bash
   yarn dev
   ```

### Environment-Specific Configuration

Create environment-specific files that override base settings:

```yaml
# app-config.production.yaml
backend:
  baseUrl: https://backstage.example.com
  database:
    client: pg
    connection:
      host: ${POSTGRES_HOST}
      port: ${POSTGRES_PORT}
      user: ${POSTGRES_USER}
      password: ${POSTGRES_PASSWORD}
```

## Best Practices

### 1. Module Boundaries
- Keep modules focused on a single concern
- Avoid cross-module dependencies
- Use clear, descriptive filenames

### 2. Secret Management
- Never commit secrets to modules
- Use environment variables
- Consider secret management tools (SOPS, Vault)

### 3. Documentation
- Document each module's purpose
- Include examples in comments
- Maintain module README files

### 4. Version Control
- Review module changes carefully
- Use semantic commit messages
- Tag configuration versions

### 5. Testing
- Test each module independently
- Validate complete configuration
- Use configuration schemas

## Troubleshooting

### Common Issues

#### Configuration Not Loading
```bash
# Check if all files exist
ls -la app-config/*.yaml

# Verify YAML syntax
yarn backstage-cli config:check
```

#### Missing Environment Variables
```bash
# List required variables
grep -r '\${' app-config/ | grep -v '#'

# Set missing variables
export GITHUB_TOKEN=your-token
```

#### Merge Conflicts
- Resolve conflicts per module
- Test affected functionality
- Validate final configuration

### Debugging

Enable configuration debugging:
```bash
LOG_LEVEL=debug yarn dev
```

Check loaded configuration:
```bash
yarn backstage-cli config:print
```

## Advanced Topics

### Dynamic Configuration
Load configuration from external sources:

```javascript
// Custom config loader
const loadDynamicConfig = async () => {
  const remoteConfig = await fetch('https://config-service/backstage');
  return remoteConfig.json();
};
```

### Configuration Validation
Add schema validation:

```yaml
# config-schema.yaml
auth:
  type: object
  required: [providers]
  properties:
    providers:
      type: object
```

### Feature Flags
Implement feature toggles:

```yaml
# features.yaml
features:
  crossplaneIngestor: true
  customTemplateCards: false
  darkMode: true
```

## Related Documentation

- [Backstage Configuration](https://backstage.io/docs/conf/)
- [Environment Variables](../environment-variables.md)
- [Secret Management](./secret-management.md)
- [Crossplane Ingestor](./crossplane-ingestor.md)