# Backstage RBAC Plugin Analysis

**Date:** 2025-10-31
**Repository:** https://github.com/backstage/community-plugins
**Location:** `workspaces/rbac/plugins/`
**Package Names:**
- `@backstage-community/plugin-rbac-backend` (Backend)
- `@backstage-community/plugin-rbac` (Frontend UI)
- `@backstage-community/plugin-rbac-common` (Shared types)
- `@backstage-community/plugin-rbac-node` (Node utilities)

**Previous Package Names (Deprecated):**
- `@spotify/backstage-plugin-rbac-backend`
- `@spotify/backstage-plugin-permission-backend-module-rbac`

## Executive Summary

The RBAC plugin is a **comprehensive, production-ready authorization system** that extends Backstage's permission framework with role-based access control. It provides:

✅ **User-friendly policy management** - Manage permissions via UI or config files (no coding required)
✅ **Catalog entity filtering** - Filter catalog resources by annotations, labels, metadata, ownership, and kind
✅ **Kubernetes cluster-based filtering** - Can filter entities by cluster origin using annotations
✅ **Conditional policies** - Fine-grained access control with conditional rules
✅ **REST API** - Programmatic policy management
✅ **Database storage** - Policies stored in PostgreSQL or SQLite
✅ **Group hierarchy support** - Multi-level group membership
✅ **Audit logging** - Track permission decisions
✅ **Dynamic policy updates** - Hot-reload CSV files without restart

## Architecture Overview

### Plugin Components

```
workspaces/rbac/plugins/
├── rbac-backend/          # Backend plugin - Policy engine & REST API
│   ├── src/
│   │   ├── service/       # REST API endpoints
│   │   ├── policies/      # Policy evaluation engine
│   │   ├── database/      # Database schema & migrations
│   │   ├── conditional-aliases/  # $currentUser, $ownerRefs support
│   │   ├── role-manager/  # Role hierarchy management
│   │   ├── file-permissions/     # CSV/YAML policy loading
│   │   ├── admin-permissions/    # Admin access control
│   │   ├── auditor/       # Audit logging
│   │   └── providers/     # Third-party RBAC integrations
│   └── docs/
│       ├── apis.md        # REST API documentation
│       ├── permissions.md # Available permissions
│       ├── conditions.md  # Conditional policy guide
│       ├── group-hierarchy.md
│       ├── audit-log.md
│       ├── providers.md
│       └── multitenancy.md
│
├── rbac/                  # Frontend plugin - Admin UI
│   └── src/
│       ├── components/    # Role & policy management UI
│       └── routes/        # /rbac page
│
├── rbac-common/           # Shared types between frontend/backend
│   └── src/
│       └── types/         # Role, Policy, Condition types
│
└── rbac-node/             # Node utilities for backend modules
    └── src/
        └── permissions/   # Permission helper functions
```

### Integration with Backstage Permission Framework

The RBAC plugin **replaces** the default permission policy (`allow-all-policy`) with a dynamic policy engine:

```typescript
// OLD: packages/backend/src/index.ts
backend.add(import('@backstage/plugin-permission-backend-module-allow-all-policy'));

// NEW: With RBAC
backend.add(import('@backstage-community/plugin-rbac-backend'));
```

**How it works:**
1. Plugin requests authorization from `/api/permission/authorize`
2. RBAC backend evaluates policies against user's roles
3. Returns: ALLOW, DENY, or CONDITIONAL
4. If CONDITIONAL: Plugin evaluates condition and makes final decision

## Key Features

### 1. Role-Based Access Control

**Roles** are first-class entities that can be assigned to users and groups:

```yaml
# CSV format (rbac-policy.csv)
p, role:default/team_a, catalog-entity, read, allow
p, role:default/team_a, catalog.entity.create, create, allow

g, user:default/bob, role:default/team_a
g, group:default/team_b, role:default/team_a
```

**Role Features:**
- Hierarchical roles (roles can be assigned to other roles)
- Source tracking (CSV, REST API, Configuration, Legacy)
- Metadata support (descriptions)
- Member management (users and groups)

### 2. Permission Policies

**Two types of permissions:**

**A. Basic Named Permissions** (simple actions):
```csv
p, role:default/developer, catalog.location.read, read, allow
p, role:default/developer, scaffolder.task.create, create, allow
```

**B. Resource Permissions** (with conditional rules):
```csv
# Can use either permission name OR resource type
p, role:default/developer, catalog.entity.read, read, allow
p, role:default/developer, catalog-entity, read, allow  # Same as above
```

### 3. Conditional Policies (🔥 Most Powerful Feature)

Filter catalog entities based on **6 built-in rules**:

#### Built-in Catalog Rules

| Rule | Description | Example Use Case |
|------|-------------|------------------|
| `HAS_ANNOTATION` | Filter by annotation | Show only entities from specific cluster |
| `HAS_LABEL` | Filter by label | Show only entities with `team=backend` |
| `HAS_METADATA` | Filter by metadata field | Show only entities with specific namespace |
| `HAS_SPEC` | Filter by spec field | Show only entities with `type: service` |
| `IS_ENTITY_KIND` | Filter by entity kind | Show only `Component` or `API` entities |
| `IS_ENTITY_OWNER` | Filter by ownership | Show only entities owned by user's team |

#### Example: Kubernetes Cluster Filtering

**Scenario:** Users should only see resources from their assigned cluster

**Step 1:** Store cluster in annotation during ingestion
```yaml
apiVersion: backstage.io/v1alpha1
kind: Template
metadata:
  name: my-xrd-template
  annotations:
    backstage.io/source-cluster: cluster-a  # ⬅️ Set during ingestion
```

**Step 2:** Create conditional policy
```json
{
  "result": "CONDITIONAL",
  "roleEntityRef": "role:default/team-a-developers",
  "pluginId": "catalog",
  "resourceType": "catalog-entity",
  "permissionMapping": ["read"],
  "conditions": {
    "rule": "HAS_ANNOTATION",
    "resourceType": "catalog-entity",
    "params": {
      "annotation": "backstage.io/source-cluster",
      "value": "cluster-a"
    }
  }
}
```

**Result:** Users in `role:default/team-a-developers` only see templates from `cluster-a`

#### Complex Conditional Policies

**Nested conditions with criteria:**

```json
{
  "result": "CONDITIONAL",
  "roleEntityRef": "role:default/developer",
  "pluginId": "catalog",
  "resourceType": "catalog-entity",
  "permissionMapping": ["read", "update"],
  "conditions": {
    "anyOf": [
      {
        "rule": "IS_ENTITY_OWNER",
        "resourceType": "catalog-entity",
        "params": { "claims": ["$currentUser"] }
      },
      {
        "rule": "HAS_ANNOTATION",
        "resourceType": "catalog-entity",
        "params": {
          "annotation": "backstage.io/source-cluster",
          "value": "dev-cluster"
        }
      }
    ]
  }
}
```

**Supported criteria:**
- `anyOf` - OR logic (match any condition)
- `allOf` - AND logic (match all conditions)
- `not` - Negation (match if condition is false)

### 4. Policy Aliases (Dynamic Values)

**Built-in aliases:**
- `$currentUser` - Replaced with user entity reference (e.g., `user:default/tom`)
- `$ownerRefs` - Replaced with user + parent groups (e.g., `['user:default/tom', 'group:default/team-a']`)

**Example:** Users can only delete their own catalog entities
```json
{
  "conditions": {
    "rule": "IS_ENTITY_OWNER",
    "params": { "claims": ["$currentUser"] }
  }
}
```

### 5. Policy Administration

**Three admin levels:**

**A. Policy Admins** (manage RBAC policies)
```yaml
permission:
  rbac:
    admin:
      users:
        - name: user:default/alice
        - name: group:default/admins
```

**B. Super Users** (unrestricted access to everything)
```yaml
permission:
  rbac:
    admin:
      superUsers:
        - name: user:default/root
```

**C. Configuration-based Admin Role** (cannot be modified via API)
```yaml
# This role is auto-created and managed via config only
permission:
  rbac:
    admin:
      users:
        - name: user:default/alice  # Gets role:default/rbac_admin
```

### 6. REST API

**Full CRUD operations for roles and policies:**

```bash
# List all roles
GET /api/permission/roles

# Create role
POST /api/permission/roles
{
  "name": "role:default/cluster-a-users",
  "memberReferences": ["group:default/team-a"],
  "metadata": { "description": "Users with access to cluster A" }
}

# List all policies
GET /api/permission/policies

# Create policy
POST /api/permission/policies

# Create conditional policy
POST /api/permission/policies/:kind/:namespace/:name/conditions

# Get conditional rules schema
GET /api/permission/plugins/condition-rules
```

**Response includes source tracking:**
```json
{
  "name": "role:default/test",
  "metadata": {
    "source": "csv-file",  // or "rest-api", "configuration", "legacy"
    "description": "Test role"
  }
}
```

### 7. Database Storage

**Supports:**
- **SQLite** (development)
- **PostgreSQL** (production)

**Database tables:**
- `role_metadata` - Role definitions
- `group_policies` - Role membership (g, user, role)
- `casbin_rule` - Permission policies (p, role, resource, action, effect)
- `conditional_policies` - Conditional rules

**Migrations:** Automatic schema migrations via Knex

### 8. File-Based Configuration

**Two file formats:**

**A. CSV Policies** (`rbac-policy.csv`)
```csv
# Permission policies (p, role, resource, action, effect)
p, role:default/team_a, catalog-entity, read, allow
p, role:default/team_a, catalog.entity.create, create, deny

# Role membership (g, user/group, role)
g, user:default/bob, role:default/team_a
g, group:default/team_b, role:default/team_a
```

**B. YAML Conditional Policies** (`conditional-policies.yaml`)
```yaml
---
result: CONDITIONAL
roleEntityRef: role:default/developer
pluginId: catalog
resourceType: catalog-entity
permissionMapping:
  - read
  - update
conditions:
  rule: IS_ENTITY_OWNER
  resourceType: catalog-entity
  params:
    claims:
      - $currentUser
```

**Configuration:**
```yaml
permission:
  rbac:
    policies-csv-file: /path/to/rbac-policy.csv
    conditionalPoliciesFile: /path/to/conditional-policies.yaml
    policyFileReload: true  # Hot reload without restart
```

### 9. Group Hierarchy Support

**Multi-level group membership:**

```yaml
# Users in subgroups inherit parent group permissions
- user:default/alice → group:default/team-a → group:default/engineering
```

**Max depth configuration:**
```yaml
permission:
  rbac:
    maxDepth: 3  # Limit hierarchy traversal depth
```

### 10. Audit Logging

**Tracks permission decisions:**
- User requesting access
- Resource being accessed
- Permission evaluated
- Decision (ALLOW/DENY/CONDITIONAL)
- Timestamp

### 11. Frontend Admin UI

**Features:**
- ✅ Role management (create, edit, delete)
- ✅ Permission assignment
- ✅ Conditional policy builder
- ✅ User/group assignment
- ✅ Policy testing interface
- ✅ Permission discovery from installed plugins

**Access:** `/rbac` route

**Sidebar integration:**
```tsx
import { Administration } from '@backstage-community/plugin-rbac';

<Sidebar>
  <Administration />
</Sidebar>
```

## Available Permissions by Plugin

### Catalog

| Permission | Resource Type | Policy | Description |
|-----------|---------------|--------|-------------|
| `catalog.entity.read` | `catalog-entity` | read | Read catalog entities |
| `catalog.entity.create` | - | create | Create catalog entities |
| `catalog.entity.refresh` | `catalog-entity` | update | Refresh entities |
| `catalog.entity.delete` | `catalog-entity` | delete | Delete entities |
| `catalog.location.read` | - | read | Read catalog locations |
| `catalog.location.create` | - | create | Create locations |
| `catalog.location.delete` | - | delete | Delete locations |

### Kubernetes

| Permission | Resource Type | Policy | Description |
|-----------|---------------|--------|-------------|
| `kubernetes.clusters.read` | - | read | Read cluster info |
| `kubernetes.resources.read` | - | read | Read K8s resources |
| `kubernetes.proxy` | - | use | Access proxy endpoint (pod logs) |

### Scaffolder

| Permission | Resource Type | Policy | Description |
|-----------|---------------|--------|-------------|
| `scaffolder.action.execute` | `scaffolder-action` | use | Execute template action |
| `scaffolder.template.parameter.read` | `scaffolder-template` | read | Read template parameters |
| `scaffolder.template.step.read` | `scaffolder-template` | read | Read template steps |
| `scaffolder.task.create` | - | create | Create scaffolder task |
| `scaffolder.task.read` | - | read | Read task status |
| `scaffolder.task.cancel` | - | use | Cancel running task |
| `scaffolder.template.management` | - | use | Edit/preview templates |

### RBAC (Self-management)

| Permission | Resource Type | Policy | Description |
|-----------|---------------|--------|-------------|
| `policy.entity.read` | `policy-entity` | read | Read policies/roles |
| `policy.entity.create` | `policy-entity` | create | Create policies/roles |
| `policy.entity.update` | `policy-entity` | update | Update policies/roles |
| `policy.entity.delete` | `policy-entity` | delete | Delete policies/roles |

## Kubernetes Cluster-Based Filtering - Implementation Guide

### Use Case

**Requirement:** Different teams should only see Crossplane templates (XRDs) from their assigned Kubernetes clusters.

**Example:**
- Team A: See templates from `cluster-a` only
- Team B: See templates from `cluster-b` only
- Admins: See templates from all clusters

### Implementation Steps

#### Step 1: Store Cluster Metadata During Ingestion

**In your ingestor plugin**, add cluster annotation to discovered entities:

```typescript
// app-portal/plugins/ingestor/src/lib/EntityBuilder.ts

const entity: TemplateEntityV1beta3 = {
  apiVersion: 'backstage.io/v1beta3',
  kind: 'Template',
  metadata: {
    name: xrd.metadata.name,
    annotations: {
      'backstage.io/source-cluster': clusterName,  // ⬅️ Add this
      // ... other annotations
    },
  },
  // ... rest of template
};
```

#### Step 2: Create Roles per Cluster

**CSV Policy File** (`rbac-policy.csv`):
```csv
# Create roles for each cluster
p, role:default/cluster-a-users, catalog-entity, read, allow
p, role:default/cluster-b-users, catalog-entity, read, allow

# Assign users to roles
g, group:default/team-a, role:default/cluster-a-users
g, group:default/team-b, role:default/cluster-b-users
```

#### Step 3: Create Conditional Policies

**Conditional Policies File** (`conditional-policies.yaml`):
```yaml
---
# Team A: Only see cluster-a templates
result: CONDITIONAL
roleEntityRef: role:default/cluster-a-users
pluginId: catalog
resourceType: catalog-entity
permissionMapping:
  - read
conditions:
  rule: HAS_ANNOTATION
  resourceType: catalog-entity
  params:
    annotation: backstage.io/source-cluster
    value: cluster-a
---
# Team B: Only see cluster-b templates
result: CONDITIONAL
roleEntityRef: role:default/cluster-b-users
pluginId: catalog
resourceType: catalog-entity
permissionMapping:
  - read
conditions:
  rule: HAS_ANNOTATION
  resourceType: catalog-entity
  params:
    annotation: backstage.io/source-cluster
    value: cluster-b
```

#### Step 4: Configure Backstage

**app-config.yaml:**
```yaml
permission:
  enabled: true
  rbac:
    policies-csv-file: /path/to/rbac-policy.csv
    conditionalPoliciesFile: /path/to/conditional-policies.yaml
    policyFileReload: true
    admin:
      users:
        - name: user:default/admin
```

#### Step 5: Verify

**As Team A member:**
- Navigate to `/catalog?filters[kind]=template`
- Should only see templates with `backstage.io/source-cluster: cluster-a`

**As Admin:**
- See all templates (no conditional policy applied)

### Advanced: Multi-Cluster Access

**Allow users to see templates from multiple clusters:**

```yaml
---
result: CONDITIONAL
roleEntityRef: role:default/multi-cluster-users
pluginId: catalog
resourceType: catalog-entity
permissionMapping:
  - read
conditions:
  anyOf:
    - rule: HAS_ANNOTATION
      resourceType: catalog-entity
      params:
        annotation: backstage.io/source-cluster
        value: cluster-a
    - rule: HAS_ANNOTATION
      resourceType: catalog-entity
      params:
        annotation: backstage.io/source-cluster
        value: cluster-b
```

### Testing Conditional Policies

**Use the REST API to test policies:**

```bash
# Get conditional rules schema
curl -X GET "http://localhost:7007/api/permission/plugins/condition-rules" \
  -H "Authorization: Bearer $TOKEN" | jq

# Create conditional policy via API
curl -X POST "http://localhost:7007/api/permission/policies/role/default/test-role/conditions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "result": "CONDITIONAL",
    "roleEntityRef": "role:default/test-role",
    "pluginId": "catalog",
    "resourceType": "catalog-entity",
    "permissionMapping": ["read"],
    "conditions": {
      "rule": "HAS_ANNOTATION",
      "resourceType": "catalog-entity",
      "params": {
        "annotation": "backstage.io/source-cluster",
        "value": "test-cluster"
      }
    }
  }'
```

## Comparison: RBAC Plugin vs Core Permission Backend

| Feature | Core Permission Backend | RBAC Plugin |
|---------|------------------------|-------------|
| **Permission evaluation** | ✅ Yes | ✅ Yes |
| **Policy definition** | ⚠️ Code-based only | ✅ CSV, YAML, API, UI |
| **Role management** | ❌ Manual | ✅ Built-in roles |
| **Conditional policies** | ⚠️ Manual implementation | ✅ Built-in rules |
| **User interface** | ❌ No | ✅ Admin UI |
| **REST API** | ❌ No | ✅ Full CRUD |
| **Database storage** | ❌ No | ✅ PostgreSQL/SQLite |
| **Audit logging** | ❌ No | ✅ Yes |
| **Hot reload** | ❌ Restart required | ✅ CSV hot reload |
| **Group hierarchy** | ⚠️ Basic | ✅ Multi-level |
| **Policy testing** | ❌ No | ✅ Policy tester UI |
| **Catalog filtering** | ⚠️ Custom rules | ✅ 6 built-in rules |

### When to Use RBAC Plugin

✅ **Use RBAC Plugin when:**
- You need role-based access control
- You want to manage permissions via UI
- You need catalog entity filtering (e.g., by cluster)
- You want conditional policies without coding
- You need to delegate policy management to non-developers
- You need audit logging
- You want database-backed policies

❌ **Use Core Permission Backend when:**
- You need simple, static permission policies
- You prefer code-based policy definition
- You have very simple authorization requirements
- You don't need UI-based policy management

## Configuration Examples

### Basic Setup

**app-config.yaml:**
```yaml
permission:
  enabled: true
  rbac:
    # Admin users
    admin:
      users:
        - name: user:default/admin
      superUsers:
        - name: user:default/root

    # File-based policies
    policies-csv-file: /etc/backstage/rbac-policy.csv
    conditionalPoliciesFile: /etc/backstage/conditional-policies.yaml
    policyFileReload: true

    # Plugins with permissions
    pluginsWithPermission:
      - catalog
      - scaffolder
      - kubernetes
      - permission

    # Group hierarchy
    maxDepth: 3

    # Policy decision precedence
    policyDecisionPrecedence: conditional  # or "basic"
```

### Policy Files

**rbac-policy.csv:**
```csv
# Admin role
p, role:default/admin, catalog-entity, read, allow
p, role:default/admin, catalog.entity.create, create, allow
p, role:default/admin, policy-entity, read, allow
p, role:default/admin, policy-entity, create, allow

# Developer role
p, role:default/developer, catalog-entity, read, allow
p, role:default/developer, scaffolder.task.create, create, allow

# Role assignments
g, user:default/alice, role:default/admin
g, group:default/developers, role:default/developer
```

**conditional-policies.yaml:**
```yaml
---
# Developers can only see their own templates
result: CONDITIONAL
roleEntityRef: role:default/developer
pluginId: catalog
resourceType: catalog-entity
permissionMapping:
  - read
  - update
conditions:
  rule: IS_ENTITY_OWNER
  resourceType: catalog-entity
  params:
    claims:
      - $ownerRefs
```

## Installation

### Backend Plugin

```bash
yarn workspace backend add @backstage-community/plugin-rbac-backend
```

**packages/backend/src/index.ts:**
```typescript
// Remove allow-all policy
- backend.add(import('@backstage/plugin-permission-backend-module-allow-all-policy'));

// Add RBAC plugin
+ backend.add(import('@backstage-community/plugin-rbac-backend'));
```

### Frontend Plugin

```bash
yarn workspace app add @backstage-community/plugin-rbac
```

**packages/app/src/App.tsx:**
```tsx
import { RbacPage } from '@backstage-community/plugin-rbac';

<Route path="/rbac" element={<RbacPage />} />
```

**packages/app/src/components/Root/Root.tsx:**
```tsx
import { Administration } from '@backstage-community/plugin-rbac';

<Sidebar>
  <Administration />
</Sidebar>
```

## Key Takeaways

### ✅ Answers to Your Questions

**1. Can we use RBAC backend to configure permissions for catalog resources from K8s cluster?**

**YES!** Use the `HAS_ANNOTATION` conditional rule with `backstage.io/source-cluster` annotation:

```json
{
  "conditions": {
    "rule": "HAS_ANNOTATION",
    "params": {
      "annotation": "backstage.io/source-cluster",
      "value": "cluster-a"
    }
  }
}
```

**2. What features does the plugin provide?**

**Core Features:**
- ✅ Role-based access control with hierarchy
- ✅ Conditional policies (6 built-in catalog rules)
- ✅ Catalog entity filtering (annotations, labels, metadata, ownership)
- ✅ REST API for policy management
- ✅ Admin UI for non-technical users
- ✅ Database storage (PostgreSQL/SQLite)
- ✅ CSV/YAML policy files with hot reload
- ✅ Audit logging
- ✅ Group hierarchy support
- ✅ Policy testing interface
- ✅ Dynamic aliases (`$currentUser`, `$ownerRefs`)

**3. Implementation Effort for Cluster Filtering?**

**Estimated Time:** 1-2 days

**Steps:**
1. Add cluster annotation in ingestor (30 min)
2. Install RBAC plugin (1 hour)
3. Create roles and conditional policies (2 hours)
4. Test and verify (2 hours)
5. Documentation and training (2 hours)

## Additional Resources

### Documentation

- **Plugin README:** `workspaces/rbac/plugins/rbac-backend/README.md`
- **API Docs:** `workspaces/rbac/plugins/rbac-backend/docs/apis.md`
- **Permissions:** `workspaces/rbac/plugins/rbac-backend/docs/permissions.md`
- **Conditional Policies:** `workspaces/rbac/plugins/rbac-backend/docs/conditions.md`
- **Group Hierarchy:** `workspaces/rbac/plugins/rbac-backend/docs/group-hierarchy.md`
- **Audit Log:** `workspaces/rbac/plugins/rbac-backend/docs/audit-log.md`
- **Providers:** `workspaces/rbac/plugins/rbac-backend/docs/providers.md`

### GitHub Repository

- **Main Repo:** https://github.com/backstage/community-plugins
- **RBAC Workspace:** `workspaces/rbac/`
- **Issues:** https://github.com/backstage/community-plugins/issues

### Related Plugins

- **Core Permission Backend:** `@backstage/plugin-permission-backend`
- **Permission Common:** `@backstage/plugin-permission-common`
- **Permission Node:** `@backstage/plugin-permission-node`

## Conclusion

The RBAC plugin is a **mature, production-ready solution** for managing permissions in Backstage. It provides:

- ✅ **User-friendly management** - No coding required
- ✅ **Kubernetes cluster filtering** - Built-in support via annotations
- ✅ **Flexible policy definition** - UI, API, CSV, YAML
- ✅ **Enterprise-ready features** - Audit logs, database storage, group hierarchy

**Recommendation:** Use RBAC plugin for production deployments, especially if you need catalog entity filtering by cluster origin.

**Effort:** Low to Medium - Plugin is well-documented and provides clear migration paths from core permission backend.
