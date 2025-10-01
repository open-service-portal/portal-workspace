# Ingestor v2 Architecture Concept

## Vision
Redesign the ingestor as three independent, composable tools that follow the Unix philosophy: do one thing well. Each tool can be used standalone or orchestrated together, with complete control over template generation through Eta templates.

## Architecture Decisions

### Core Principles
1. **Three Independent Tools** - Extract, Transform, Provide (complete implementations, not frameworks)
2. **Replaceable Tools** - Each tool can be replaced by external alternatives (not plugins, but complete replacements)
3. **Template-Driven** - Full control via Eta templates for transformation
4. **File-Based Interface** - Tools communicate via files/JSON, enabling easy replacement
5. **Dual Execution** - Run embedded in Backstage or as external processes

### Tool Separation & Replaceability

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   EXTRACT   │────▶│  TRANSFORM  │────▶│   PROVIDE   │
└─────────────┘     └─────────────┘     └─────────────┘
      │                    │                    │
      ▼                    ▼                    ▼
 K8s API/Files        Templates            Backstage
                    (Eta Engine)         (Plugin Only)

      OR                  OR                   OR

┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   kubectl   │────▶│   Custom    │────▶│   GitHub    │
│  get xrd    │     │   Script    │     │   Actions   │
└─────────────┘     └─────────────┘     └─────────────┘
```

**Key Design Decision**: Each tool is a complete, standalone implementation. We don't build plugin systems within the tools. Instead, the tools communicate via standard file formats (JSON/YAML), allowing users to replace any tool entirely with their own implementation or existing tools.

### Tool Interface Contracts

Each tool has a clear input/output contract, enabling replacement:

1. **Extract Output** → JSON file with structure:
   ```json
   {
     "source": "kubernetes|file|git",
     "timestamp": "ISO-8601",
     "xrd": { /* XRD object */ },
     "metadata": { /* extraction context */ }
   }
   ```

2. **Transform Input** → Extract's JSON output
   **Transform Output** → Backstage YAML/JSON entities

3. **Provide Input** → Directory of Backstage entities
   **Provide Output** → Entities in Backstage catalog

## Detailed Architecture

### 1. Extract Tool (`@openportal/xrd-extract`)

**Purpose**: Extract XRDs from various sources

**CLI Usage**:
```bash
xrd-extract --source kubernetes --cluster production --output xrds/
xrd-extract --source file --path ./my-xrd.yaml --output xrds/
xrd-extract --source git --repo https://github.com/org/templates --output xrds/
```

**Library Usage**:
```typescript
import { extract } from '@openportal/xrd-extract';

const xrds = await extract({
  source: 'kubernetes',
  cluster: 'production',
  filters: { labels: { 'backstage.io/enabled': 'true' } }
});
```

**Output Format**: JSON with XRD + metadata
```json
{
  "source": "kubernetes",
  "timestamp": "2024-01-01T00:00:00Z",
  "xrd": { /* Original XRD */ },
  "metadata": {
    "cluster": "production",
    "namespace": "crossplane-system"
  }
}
```

**Can Be Replaced With** (external tools, not plugins):
```bash
# Using kubectl instead of xrd-extract
kubectl get xrd -o json | jq '{
  source: "kubernetes",
  timestamp: now|todate,
  xrd: .,
  metadata: {cluster: "production"}
}' > xrd.json

# Using a simple shell script
#!/bin/bash
cat my-xrd.yaml | yq eval -o=json '{
  source: "file",
  timestamp: "'$(date -Iseconds)'",
  xrd: .,
  metadata: {path: "'$1'"}
}' > xrd.json
```

### 2. Transform Tool (`@openportal/xrd-transform`)

**Purpose**: Transform XRDs into Backstage templates using Eta templates

**CLI Usage**:
```bash
xrd-transform --input xrds/ --templates ./templates --output catalog/
xrd-transform --input xrd.json --template-dir ./my-templates --output catalog/
```

**Library Usage**:
```typescript
import { transform } from '@openportal/xrd-transform';

const backstageEntities = await transform({
  xrd: xrdData,
  templateDir: './templates',
  context: { /* additional context */ }
});
```

**Template Structure**:
```
templates/
├── metadata.yaml          # Template configuration
├── backstage/
│   ├── default.eta       # Default Backstage template
│   ├── simple.eta        # Simple form template
│   └── advanced.eta      # Advanced template with all features
├── wizard/
│   ├── default.eta       # Default wizard configuration
│   ├── gitops.eta        # GitOps-focused wizard
│   └── multi-cluster.eta # Multi-cluster wizard
└── steps/
    ├── default.eta       # Default steps
    ├── github-pr.eta     # GitHub PR creation
    ├── gitlab-mr.eta     # GitLab MR creation
    └── direct-apply.eta  # Direct kubectl apply

```

**Template Selection via XRD Annotation**:
```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: databases.platform.io
  annotations:
    # Select which templates to use
    backstage.io/template: advanced      # Use advanced.eta
    backstage.io/wizard: gitops          # Use gitops.eta wizard
    backstage.io/steps: github-pr        # Use github-pr.eta steps
    # Or use default if not specified
```

**Eta Template Example** (`backstage/advanced.eta`):
```eta
<%#
  Available variables:
  - xrd: The full XRD object
  - metadata: Extraction metadata
  - helpers: Utility functions
%>
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: <%= helpers.slugify(xrd.metadata.name) %>
  title: <%= helpers.extractTitle(xrd) %>
  description: <%= xrd.metadata.annotations?.['backstage.io/description'] || 'Manage ' + xrd.spec.names.kind %>
  tags:
    - crossplane
    - <%= xrd.spec.group %>
    <% if (xrd.metadata.labels) { %>
    <% Object.entries(xrd.metadata.labels).forEach(([key, value]) => { %>
    - <%= value %>
    <% }) %>
    <% } %>
spec:
  owner: <%= xrd.metadata.annotations?.['backstage.io/owner'] || 'platform-team' %>
  type: crossplane-resource

  <%# Include the wizard %>
  <%= include('wizard/' + (xrd.metadata.annotations?.['backstage.io/wizard'] || 'default')) %>

  <%# Include the steps %>
  <%= include('steps/' + (xrd.metadata.annotations?.['backstage.io/steps'] || 'default')) %>
```

**Can Be Replaced With** (external tools):
```bash
# Using jq to generate simple template
cat xrd.json | jq '
  .xrd | {
    apiVersion: "scaffolder.backstage.io/v1beta3",
    kind: "Template",
    metadata: {
      name: .metadata.name,
      title: .spec.names.kind
    },
    spec: {
      owner: "platform-team",
      type: "crossplane-resource",
      parameters: [],
      steps: []
    }
  }
' > template.yaml

# Using Python script with Jinja2
python generate-template.py --xrd xrd.json --template my-template.j2

# Using Go template CLI
gomplate -f template.gotmpl -d xrd=xrd.json -o template.yaml
```

### 3. Provide Tool (`@openportal/backstage-provider`)

**Purpose**: Backstage-specific plugin to provide templates to the catalog

**Note**: This is primarily a Backstage plugin, not a CLI tool

**Plugin Configuration**:
```yaml
# app-config.yaml
catalog:
  providers:
    xrdTemplates:
      enabled: true
      sourceDirectory: /app/generated-templates  # Where transform outputs
      watchForChanges: true
      schedule:
        frequency: { minutes: 5 }
```

**Library Usage** (within Backstage):
```typescript
import { XrdTemplateProvider } from '@openportal/backstage-provider';

// In backend plugin
export default createBackendPlugin({
  pluginId: 'catalog',
  register(env) {
    env.registerInit({
      deps: {
        catalog: catalogServiceRef,
        config: configServiceRef,
        scheduler: schedulerServiceRef
      },
      async init({ catalog, config, scheduler }) {
        const provider = new XrdTemplateProvider({
          sourceDirectory: config.getString('catalog.providers.xrdTemplates.sourceDirectory'),
          schedule: scheduler.createScheduledTaskRunner(/* ... */)
        });

        catalog.addEntityProvider(provider);
      }
    });
  }
});
```

**Can Be Replaced With** (for providing to Backstage):
```bash
# Using GitHub Actions to commit templates
git add generated-templates/
git commit -m "Update templates"
git push

# Using curl to register with Backstage API
curl -X POST http://backstage:7007/api/catalog/locations \
  -H "Content-Type: application/json" \
  -d '{"type":"url","target":"https://github.com/org/templates"}'

# Using static catalog configuration
# In app-config.yaml:
catalog:
  locations:
    - type: file
      target: /app/generated-templates/**/*.yaml
```

## Implementation Plan

### Phase 1: Core Libraries (Weeks 1-2)
1. Create three npm packages
2. Define interfaces between tools
3. Implement basic Extract (K8s + files)
4. Implement Transform with Eta
5. Implement Provide as Backstage plugin

### Phase 2: Template System (Weeks 3-4)
1. Design template directory structure
2. Create default templates
3. Implement template selection logic
4. Add helper functions for Eta
5. Create template documentation

### Phase 3: CLI Tools (Week 5)
1. Create CLI for Extract
2. Create CLI for Transform
3. Add piping support (Unix philosophy)
4. Add validation commands
5. Create examples

### Phase 4: Integration (Week 6)
1. Update existing ingestor to use new libraries
2. Migration guide
3. Performance testing
4. Documentation
5. Examples repository

## Tool Composition & Unix Philosophy

### Piping Support

The tools support Unix-style piping for composition:

```bash
# Full pipeline using our tools
xrd-extract --source kubernetes | xrd-transform --templates ./templates | backstage-provide

# Mix our tools with standard Unix tools
xrd-extract --source file --path "*.yaml" | \
  jq '.xrd' | \
  xrd-transform --templates ./templates | \
  tee generated.yaml | \
  wc -l

# Replace middle step with custom script
xrd-extract --source kubernetes | \
  python my-transformer.py | \
  backstage-provide
```

### Stdin/Stdout Support

Each tool can read from stdin and write to stdout:

```bash
# Extract reads file, outputs to stdout
xrd-extract --source file --path xrd.yaml

# Transform reads from stdin, outputs to stdout
cat xrd.json | xrd-transform --templates ./templates

# Provide reads from stdin (when not used as plugin)
cat template.yaml | backstage-provide --api-url http://backstage:7007
```

## Usage Scenarios

### Scenario 1: Development Time
```bash
# Extract XRD from file
xrd-extract --source file --path my-xrd.yaml --output temp/

# Transform with custom templates
xrd-transform --input temp/my-xrd.json \
              --templates ./my-templates \
              --output ./generated/

# Review generated template
cat ./generated/my-xrd-template.yaml
```

### Scenario 2: CI/CD Pipeline
```yaml
# .github/workflows/generate-templates.yml
- name: Extract XRDs from cluster
  run: xrd-extract --source kubernetes --output xrds/

- name: Transform to Backstage templates
  run: xrd-transform --input xrds/ --templates ./templates --output catalog/

- name: Commit templates
  run: |
    git add catalog/
    git commit -m "Update Backstage templates"
    git push
```

### Scenario 3: Kubernetes CronJob
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: xrd-template-generator
spec:
  schedule: "*/30 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: generator
            image: openportal/xrd-pipeline:latest
            command:
            - sh
            - -c
            - |
              xrd-extract --source kubernetes --output /tmp/xrds/
              xrd-transform --input /tmp/xrds/ --output /output/
              # Output mounted as volume shared with Backstage
```

### Scenario 4: Backstage Embedded
```yaml
# Standard Backstage deployment
# Provider watches directory populated by external process
catalog:
  providers:
    xrdTemplates:
      sourceDirectory: /shared/templates
```

## Template Examples

### Simple Backstage Template (`backstage/simple.eta`):
```eta
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: <%= helpers.slugify(xrd.metadata.name) %>
  title: <%= xrd.spec.names.kind %>
spec:
  owner: platform-team
  type: crossplane-resource
  parameters:
    - title: Resource Configuration
      properties:
        name:
          title: Name
          type: string
        <% helpers.extractProperties(xrd).forEach(prop => { %>
        <%= prop.name %>:
          title: <%= prop.title %>
          type: <%= prop.type %>
        <% }) %>
  steps:
    - id: create-resource
      name: Create <%= xrd.spec.names.kind %>
      action: kubernetes:apply
      input:
        manifest: |
          apiVersion: <%= xrd.spec.group %>/<%= xrd.spec.versions[0].name %>
          kind: <%= xrd.spec.names.kind %>
          metadata:
            name: ${{ parameters.name }}
          spec: ${{ parameters }}
```

### GitOps Wizard (`wizard/gitops.eta`):
```eta
parameters:
  - title: Resource Metadata
    required:
      - name
      - owner
    properties:
      name:
        title: Name
        type: string
      owner:
        title: Owner
        type: string
        ui:field: OwnerPicker

  - title: GitOps Configuration
    properties:
      repository:
        title: Target Repository
        type: string
        default: catalog-orders
      branch:
        title: Target Branch
        type: string
        default: main
      createPR:
        title: Create Pull Request
        type: boolean
        default: true

  - title: Resource Specification
    properties:
      <% helpers.extractProperties(xrd).forEach(prop => { %>
      <%= prop.name %>:
        title: <%= prop.title %>
        type: <%= prop.type %>
        <% if (prop.description) { %>
        description: <%= prop.description %>
        <% } %>
      <% }) %>
```

## Benefits of This Architecture

1. **Modularity**: Each tool does one thing well
2. **Flexibility**: Tools can be replaced/combined differently
3. **Testability**: Each tool can be tested independently
4. **Customization**: Complete control via templates
5. **Deployment Options**: Run anywhere (CI, K8s, Backstage)
6. **Developer Experience**: Simple CLI tools, clear interfaces
7. **Maintenance**: Smaller, focused codebases

## Next Discussion Points

### Immediate Decisions Needed

1. **Package Naming**:
   - Option A: `@openportal/xrd-extract`, `@openportal/xrd-transform`, `@openportal/backstage-provider`
   - Option B: More generic like `@openportal/k8s-resource-extract`, `@openportal/template-engine`, etc.

2. **Template Directory Structure**:
   - Should we have a standard directory layout that users must follow?
   - Or allow complete flexibility with configuration?

3. **Error Handling Strategy**:
   - What happens when a template has an error?
   - Should we generate a "safe" default or fail completely?

4. **Library vs CLI First**:
   - Should we build the library first and wrap with CLI?
   - Or build CLI first and extract library?

### Technical Questions

1. **Template Helpers**: What helper functions do we need in Eta?
   - `slugify()` - Convert names to valid K8s names
   - `extractProperties()` - Extract properties from XRD schema
   - `generateValidation()` - Create validation rules
   - What else?

2. **Streaming vs Batch**:
   - Should Extract output one JSON per XRD?
   - Or batch all XRDs in one JSON array?
   - How does this affect piping?

3. **Configuration**:
   - How much should be configurable vs convention?
   - Environment variables vs config files vs CLI flags?

### Future Considerations

1. **Template Marketplace**:
   - Should we plan for a template registry/marketplace?
   - How would templates be shared/discovered?

2. **Validation & Testing**:
   - How do we validate Eta templates before use?
   - Should we provide a test framework for templates?

3. **Migration Path**:
   - How do we migrate from current ingestor?
   - Can we support both architectures temporarily?

## Summary

This architecture provides:
- **Clear separation of concerns** with three independent tools
- **Complete flexibility** through tool replacement (not plugins)
- **Full template control** via Eta templates with XRD annotations
- **Multiple deployment options** (embedded, external, CI/CD)
- **Unix philosophy** with piping and file-based interfaces

The key insight is that by making tools completely independent and communicating via files, we enable maximum flexibility without the complexity of a plugin system. Users can mix and match our tools with their own scripts, existing tools, or completely custom solutions.