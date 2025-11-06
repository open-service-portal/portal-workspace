# @backstage/plugin-permission-backend - Comprehensive Analysis

## Executive Summary

The Backstage permission backend is a flexible, policy-driven authorization framework that enables fine-grained access control across Backstage entities and actions. It supports both basic permissions (e.g., "can delete catalog") and resource-based permissions (e.g., "can delete catalog entities that I own") with conditional authorization.

**Key Finding**: The permission system CAN be used to control access to catalog entities based on their origin (e.g., Kubernetes clusters), but it requires implementing custom permission rules and policies. It is **not** built specifically for this use case out-of-the-box.

---

## Plugin Architecture & Components

### Core Components

```
@backstage/plugin-permission-backend
├── Main Router: /api/permission/authorize
├── Integration Endpoint: /.well-known/backstage/permissions/apply-conditions
├── Health Check: /health
└── Extension Point: PolicyExtensionPoint
```

### Related Packages

1. **@backstage/plugin-permission-common**
   - Shared types and PermissionClient for isomorphic use
   - Permission, BasicPermission, ResourcePermission types
   - AuthorizeResult enum (ALLOW, DENY, CONDITIONAL)

2. **@backstage/plugin-permission-node**
   - Backend utilities for plugin authors
   - PermissionPolicy interface
   - PermissionRule and PermissionRuleset types
   - Condition factory and transformation utilities
   - ServerPermissionClient for backend-to-backend authorization

3. **@backstage/plugin-catalog-backend**
   - Real-world example implementation
   - Built-in permission rules (6 total)
   - Integration with permission framework

---

## How It Works: Authorization Flow

### 1. Permission Request
```typescript
// A plugin sends an authorization request
const decision = await permissions.authorize(
  [{ 
    permission: catalogEntityReadPermission,
    resourceRef: 'component:default/my-component'  // Optional
  }],
  { credentials }
);
```

### 2. Backend Routes Authorization Request
```
POST /api/permission/authorize
Body: {
  items: [{
    id: 'request-1',
    permission: {
      name: 'catalog.entity.read',
      type: 'resource',              // or 'basic'
      resourceType: 'catalog-entity',
      attributes: { action: 'read' }
    },
    resourceRef: 'component:default/my-component'  // For resource permissions
  }]
}
```

### 3. Policy Makes Decision
The permission backend delegates to the configured permission policy:

```typescript
class PermissionPolicy {
  async handle(
    request: PolicyQuery,
    user?: PolicyQueryUser
  ): Promise<PolicyDecision>
}
```

The policy can return:
- **ALLOW**: User has access
- **DENY**: User does not have access  
- **CONDITIONAL**: Policy needs resource characteristics to decide
  - Returns conditions to evaluate (rules with params)
  - Delegates evaluation to the resource owner plugin

### 4. Conditional Evaluation (Resource-Based)
If policy returns CONDITIONAL:

```
POST /.well-known/backstage/permissions/apply-conditions
Body: {
  items: [{
    id: 'request-1',
    resourceRef: 'component:default/my-component',
    resourceType: 'catalog-entity',
    conditions: {
      rule: 'IS_ENTITY_OWNER',
      resourceType: 'catalog-entity',
      params: { claims: ['user:john@company.com'] }
    }
  }]
}
```

The resource owner plugin (catalog) then:
1. Loads the resource from its data store
2. Applies the rule's `apply()` function to test the resource in-memory
3. Returns ALLOW or DENY

### 5. Final Response
```typescript
{
  items: [{
    id: 'request-1',
    result: AuthorizeResult.ALLOW  // or DENY
  }]
}
```

---

## Permission Types

### Basic Permissions
```typescript
export const todoListCreatePermission = createPermission({
  name: 'todo.list.create',
  attributes: { action: 'create' }
  // No resourceType = cannot have resourceRef
});
```

**Use Cases**: Global actions that don't apply to specific resources
- Create new entities
- Access dashboard
- Configure settings

### Resource Permissions
```typescript
export const todoListUpdatePermission = createPermission({
  name: 'todo.list.update',
  attributes: { action: 'update' },
  resourceType: 'todo-item'  // REQUIRED
});
```

**Use Cases**: Actions on specific resources that can be evaluated per-resource
- Read, update, delete specific entities
- Execute templates on specific components
- Manage specific DNS records

---

## Permission Rules: The Key to Resource-Based Control

### What is a Rule?
A **PermissionRule** has two responsibilities:

1. **In-Memory Evaluation** (`apply()`): Test if a resource in memory matches criteria
2. **Database Query** (`toQuery()`): Convert criteria to database query syntax

```typescript
export type PermissionRule<TResource, TQuery, TResourceType> = {
  name: string;
  description: string;
  resourceType: TResourceType;
  paramsSchema?: z.ZodSchema<TParams>;
  
  // Test a resource already loaded
  apply(resource: TResource, params: TParams): boolean;
  
  // Convert to database query for efficient filtering
  toQuery(params: TParams): PermissionCriteria<TQuery>;
};
```

### Example: Catalog Plugin Rules

```typescript
// IS_ENTITY_OWNER: Check if user owns the entity
export const isEntityOwner = createPermissionRule({
  name: 'IS_ENTITY_OWNER',
  description: 'Allow entities owned by a specified claim',
  resourceRef: catalogEntityPermissionResourceRef,
  paramsSchema: z.object({
    claims: z.array(z.string()).describe('User entity refs to match'),
  }),
  
  // In-memory test
  apply: (resource: Entity, { claims }) => {
    if (!resource.relations) return false;
    return resource.relations
      .filter(r => r.type === 'ownedBy')
      .some(r => claims.includes(r.targetRef));
  },
  
  // Database query
  toQuery: ({ claims }) => ({
    key: 'relations.ownedBy',
    values: claims,  // WHERE relations.ownedBy IN (claims)
  }),
});
```

### Built-in Catalog Rules

| Rule | Description | Use Case |
|------|-------------|----------|
| `isEntityOwner` | User owns the entity | Access by ownership |
| `hasAnnotation` | Entity has specific annotation | Fine-grained tagging |
| `hasLabel` | Entity has specific label | Categorization filtering |
| `hasMetadata` | Entity metadata matches | Complex attribute checks |
| `hasSpec` | Entity spec field matches | Kind/type-based filtering |
| `isEntityKind` | Entity is specific kind | Kind-based permissions |

---

## Can It Filter by Kubernetes Origin?

### Theoretical Answer: **YES**

You can create a custom rule to filter by cluster origin:

```typescript
// Example: Custom rule for cluster origin
export const isFromCluster = createPermissionRule({
  name: 'IS_FROM_CLUSTER',
  description: 'Filter entities from a specific Kubernetes cluster',
  resourceRef: catalogEntityPermissionResourceRef,
  paramsSchema: z.object({
    clusterName: z.string().describe('K8s cluster name'),
  }),
  
  // In-memory evaluation
  apply: (resource: Entity, { clusterName }) => {
    const originLocation = 
      resource.metadata.annotations?.['backstage.io/origin-location'];
    // Would need to parse cluster name from location
    return originLocation?.includes(clusterName) ?? false;
  },
  
  // Database query
  toQuery: ({ clusterName }) => ({
    key: 'metadata.annotations.backstage.io/origin-location',
    values: [clusterName],
  }),
});
```

### Practical Constraints

1. **Annotation Dependency**: You need to store cluster origin in entity metadata/annotations
   - The ingestor plugin must populate this when discovering resources
   - Example: `annotation: 'kubernetes.io/cluster-name': 'prod-cluster'`

2. **Policy Implementation**: You must write a custom policy that uses this rule
   ```typescript
   class ClusterAwarePolicy implements PermissionPolicy {
     async handle(request: PolicyQuery, user?: PolicyQueryUser) {
       if (isResourcePermission(request.permission, 'catalog-entity')) {
         return createCatalogConditionalDecision(
           request.permission,
           isFromCluster({ clusterName: 'prod-cluster' })
         );
       }
       return { result: AuthorizeResult.ALLOW };
     }
   }
   ```

3. **Rule Registration**: Rules must be registered with the catalog plugin
   ```typescript
   permissionsRegistry.addPermissionRules([isFromCluster]);
   ```

### Real-World Implementation Steps

1. **Modify Ingestor Plugin**
   - Add cluster metadata when discovering Kubernetes resources
   - Store in entity annotations during ingestion

2. **Create Permission Rules**
   - Define rules for different cluster access patterns
   - Implement both `apply()` and `toQuery()` methods

3. **Write Permission Policy**
   - Check resource permissions against cluster rules
   - Return CONDITIONAL decisions with cluster conditions

4. **Register Rules**
   - Add to PermissionsRegistry service in catalog backend

---

## Integration with Catalog System

### How Catalog Integrates with Permissions

```
1. Client requests /api/catalog/entities
2. Catalog backend calls PermissionsService.authorize()
3. Permission backend checks policy
4. If CONDITIONAL:
   - Catalog calls backend's apply-conditions endpoint
   - Returns filtered list of allowed entities
5. Catalog returns ONLY authorized entities to client
```

### Key Files

- `@backstage/plugin-catalog-backend/src/permissions/`
  - `rules/`: Built-in rules (6 files)
  - `conditionExports.ts`: Exported conditions for policies
  - `index.ts`: Public API

- `@backstage/plugin-catalog-backend/src/service/createRouter.ts`
  - Lines 159-256: Entity listing with permission checks
  - Lines 268-300: Query entities with pagination
  - Passes `credentials` to entitiesCatalog methods

### Permissions Service Integration

```typescript
// Catalog backend integration
const permissionsService = env.service(coreServices.permissions);

// In router handlers
const credentials = await httpAuth.credentials(req);
const { entities, pageInfo } = await entitiesCatalog.entities({
  filter,
  fields,
  credentials,  // <-- Permission filtering happens here
});
```

---

## Configuration

### Enable Permissions

```yaml
# app-config.yaml
permission:
  enabled: true  # Required to activate permission checks
```

### Default Policy

By default, Backstage ships with an "Allow All" policy:

```typescript
import { permissionModuleAllowAllPolicy } 
  from '@backstage/plugin-permission-backend-module-allow-all-policy';

// This ALLOWS all requests (permissive by default)
backend.add(permissionModuleAllowAllPolicy);
```

To enforce permissions, replace with custom policy:

```typescript
// Remove allow-all
// backend.add(permissionModuleAllowAllPolicy);

// Add custom policy
backend.add(import('./modules/customPermissionPolicy'));
```

---

## Conditional Decisions & Filtering

### How Conditional Filtering Works

The framework distinguishes between **policy decisions** and **enforcement**:

- **Policy** (permission-backend): "Only if condition is met"
- **Enforcement** (resource owner): "Check if condition is actually met"

This separation enables:
1. **Efficiency**: Database queries filter at source
2. **Decoupling**: Policies don't need resource schemas
3. **Flexibility**: Plugins implement complex logic

### Example Flow

```
Policy says: "CONDITIONAL: Must be entity owner"
    ↓
Permission backend sends to Catalog:
  "Apply rule: isEntityOwner with claims=[user:john]"
    ↓
Catalog plugin:
  - Loads all entities
  - Tests each with rule.apply(entity, { claims })
  - Filters results to only matching entities
    ↓
Returns filtered entity list to user
```

### Batching & Performance

The framework uses **DataLoader** for efficiency:

```typescript
const applyConditionsLoaderFor = memoize((pluginId: string) => {
  return new DataLoader<ApplyConditionsRequestEntry, ApplyConditionsResponseEntry>(
    batch => permissionIntegrationClient.applyConditions(pluginId, credentials, batch)
  );
});
```

Multiple permission checks are batched into single API calls.

---

## Writing Custom Policies

### Basic Policy Structure

```typescript
import { createBackendModule } from '@backstage/backend-plugin-api';
import { PermissionPolicy, PolicyQuery, PolicyQueryUser } 
  from '@backstage/plugin-permission-node';
import { PolicyDecision, AuthorizeResult, isResourcePermission } 
  from '@backstage/plugin-permission-common';
import { policyExtensionPoint } from '@backstage/plugin-permission-node/alpha';

class CustomPermissionPolicy implements PermissionPolicy {
  async handle(
    request: PolicyQuery,
    user?: PolicyQueryUser
  ): Promise<PolicyDecision> {
    // Check permission name
    if (request.permission.name === 'catalog.entity.delete') {
      return { result: AuthorizeResult.DENY };
    }
    
    // Resource-based checks
    if (isResourcePermission(request.permission, 'catalog-entity')) {
      // Can use user info for conditional decisions
      return createCatalogConditionalDecision(
        request.permission,
        catalogConditions.isEntityOwner({
          claims: user?.info.ownershipEntityRefs ?? [],
        })
      );
    }
    
    return { result: AuthorizeResult.ALLOW };
  }
}

export default createBackendModule({
  pluginId: 'permission',
  moduleId: 'permission-policy',
  register(reg) {
    reg.registerInit({
      deps: { policy: policyExtensionPoint },
      async init({ policy }) {
        policy.setPolicy(new CustomPermissionPolicy());
      },
    });
  },
});
```

### Policy Query Information

```typescript
interface PolicyQuery {
  permission: Permission;  // The permission being requested
}

interface PolicyQueryUser {
  identity: {
    type: 'user';
    userEntityRef: string;
    ownershipEntityRefs: string[];  // Groups, teams owned by user
  };
  token: string;  // For downstream API calls
  credentials: BackstageCredentials;
  info: UserInfo;
}
```

---

## RBAC Integration

### Role-Based Access Control

The permission framework is **policy-agnostic** - it doesn't enforce RBAC.

However, RBAC can be implemented via:

1. **Community RBAC Plugin** (`@backstage/plugin-rbac-backend`)
   - Provides role-based policy implementation
   - Manages role definitions and assignments
   - Integrates with permission framework

2. **Custom Policy**
   ```typescript
   class RBACPolicy implements PermissionPolicy {
     async handle(request: PolicyQuery, user?: PolicyQueryUser) {
       const userRoles = await this.getRolesForUser(user?.identity.userEntityRef);
       
       if (userRoles.includes('admin')) {
         return { result: AuthorizeResult.ALLOW };
       }
       
       // Check specific role permissions...
       return { result: AuthorizeResult.DENY };
     }
   }
   ```

---

## Frontend Integration

### Frontend Authorization Check

```typescript
import { usePermission } from '@backstage/plugin-permission-react';

export function DeleteButton() {
  const { loading, allowed } = usePermission({
    permission: catalogEntityDeletePermission,
    resourceRef: 'component:default/my-app',
  });
  
  if (loading) return <Skeleton />;
  
  return (
    <Button 
      disabled={!allowed}
      onClick={handleDelete}
    >
      Delete
    </Button>
  );
}
```

### How Frontend Authorization Works

1. Frontend queries permission backend
2. Gets decision (ALLOW/DENY/CONDITIONAL)
3. If CONDITIONAL: Shows/hides UI elements based on decision
4. Backend still enforces on API calls

---

## Limitations & Considerations

### Current Limitations

1. **No Built-in Cluster Filtering**
   - Requires custom rules to filter by origin
   - Depends on metadata being populated during ingestion

2. **Policy is Global**
   - Single policy for entire Backstage instance
   - Cannot have per-plugin policies
   - Should be centralized in configuration

3. **Resource Ref Format**
   - Must match entity refs (e.g., `component:default/name`)
   - Cannot pass arbitrary identifiers

4. **Conditional Decisions Only for Resources**
   - Basic permissions must return ALLOW/DENY
   - Cannot conditionally allow basic permissions

### Considerations

1. **Performance**
   - Batching via DataLoader helps
   - Still adds latency to catalog queries
   - Should profile before enabling globally

2. **Policy Complexity**
   - Custom rules require both `apply()` and `toQuery()`
   - Mismatch between two can cause bugs
   - Needs testing strategy

3. **External Integration**
   - Can call external authorization systems from policy
   - But blocks requests while waiting for response
   - Consider caching for performance

---

## Code Examples

### Example: Kubernetes Cluster-Based Access

```typescript
// Define custom rule
import { createPermissionRule } from '@backstage/plugin-permission-node';
import { catalogEntityPermissionResourceRef } 
  from '@backstage/plugin-catalog-node/alpha';

export const isFromAuthorizedCluster = createPermissionRule({
  name: 'IS_FROM_AUTHORIZED_CLUSTER',
  description: 'Only entities from authorized clusters',
  resourceRef: catalogEntityPermissionResourceRef,
  paramsSchema: z.object({
    allowedClusters: z.array(z.string()),
  }),
  
  apply: (entity: Entity, { allowedClusters }) => {
    const clusterName = entity.metadata.annotations?.['kubernetes.io/cluster'];
    return clusterName && allowedClusters.includes(clusterName);
  },
  
  toQuery: ({ allowedClusters }) => ({
    key: 'metadata.annotations["kubernetes.io/cluster"]',
    values: allowedClusters,
  }),
});

// Register rule
import { createBackendModule } from '@backstage/backend-plugin-api';
import { catalogPermissionExtensionPoint } 
  from '@backstage/plugin-catalog-node/alpha';

export default createBackendModule({
  pluginId: 'catalog',
  moduleId: 'permission-rules',
  register(reg) {
    reg.registerInit({
      deps: { permissionsRegistry: coreServices.permissionsRegistry },
      async init({ permissionsRegistry }) {
        permissionsRegistry.addPermissionRules([isFromAuthorizedCluster]);
      },
    });
  },
});

// Use in policy
class ClusterAwarePolicy implements PermissionPolicy {
  async handle(
    request: PolicyQuery,
    user?: PolicyQueryUser
  ): Promise<PolicyDecision> {
    if (isResourcePermission(request.permission, 'catalog-entity')) {
      return createCatalogConditionalDecision(
        request.permission,
        isFromAuthorizedCluster({
          allowedClusters: ['production', 'staging']
        })
      );
    }
    
    return { result: AuthorizeResult.ALLOW };
  }
}
```

### Example: Checking User Roles

```typescript
import { ServerPermissionClient } 
  from '@backstage/plugin-permission-node';

class RoleBasedPolicy implements PermissionPolicy {
  constructor(
    private serverPermissionClient: ServerPermissionClient
  ) {}
  
  async handle(
    request: PolicyQuery,
    user?: PolicyQueryUser
  ): Promise<PolicyDecision> {
    if (!user) {
      return { result: AuthorizeResult.DENY };
    }
    
    // Check if user is admin
    const isAdmin = user.info.ownershipEntityRefs
      .some(ref => ref === 'group:default/admins');
    
    if (isAdmin && isResourcePermission(request.permission, 'catalog-entity')) {
      // Admins can access all entities
      return { result: AuthorizeResult.ALLOW };
    }
    
    // Regular users need conditional check
    return createCatalogConditionalDecision(
      request.permission,
      catalogConditions.isEntityOwner({
        claims: user.info.ownershipEntityRefs,
      })
    );
  }
}
```

---

## File Structure Reference

```
backstage/plugins/permission-backend/
├── src/
│   ├── plugin.ts              # Main plugin definition
│   ├── index.ts               # Public exports
│   ├── alpha.ts               # Alpha APIs
│   └── service/
│       ├── router.ts          # Request handler (275 lines)
│       ├── PermissionIntegrationClient.ts  # Client for apply-conditions
│       └── index.ts
├── README.md
└── package.json

backstage/plugins/permission-node/
├── src/
│   ├── types.ts               # PermissionRule types
│   ├── index.ts
│   ├── alpha.ts
│   ├── ServerPermissionClient.ts
│   └── integration/
│       ├── createPermissionRule.ts
│       ├── createPermissionResourceRef.ts
│       ├── createPermissionIntegrationRouter.ts
│       ├── createConditionFactory.ts
│       ├── createConditionTransformer.ts
│       └── util.ts
└── README.md

backstage/plugins/permission-common/
├── src/
│   ├── types/
│   │   ├── permission.ts      # Permission types
│   │   ├── api.ts
│   │   ├── integration.ts
│   │   └── discovery.ts
│   ├── PermissionClient.ts    # Isomorphic client
│   └── permissions/
│       └── createPermission.ts
└── README.md

backstage/plugins/catalog-backend/
├── src/permissions/
│   ├── index.ts               # Public API
│   ├── rules/                 # 6 built-in rules
│   │   ├── isEntityOwner.ts
│   │   ├── hasAnnotation.ts
│   │   ├── hasLabel.ts
│   │   ├── isEntityKind.ts
│   │   ├── hasMetadata.ts
│   │   └── hasSpec.ts
│   └── conditionExports.ts    # Rule factories
└── src/service/createRouter.ts  # Integration point
```

---

## Key Takeaways

### Capabilities ✓
- Fine-grained resource-based access control
- Flexible policy implementation (code-driven)
- Conditional evaluation with custom rules
- Integration with resource owner plugins
- Can filter catalog entities per-request
- Support for complex conditions (AND, OR, NOT)

### Limitations ✗
- No out-of-the-box cluster origin filtering
- Single global policy
- Requires custom rule development
- Policy enforcement depends on plugin integration
- Backend only - frontend check is informational

### For Kubernetes Origin Filtering
**Feasibility**: Possible with custom implementation
**Requirements**:
1. Metadata population during ingestion
2. Custom permission rule with apply() and toQuery()
3. Custom permission policy
4. Rule registration with catalog backend

**Effort**: Medium (2-3 days of development)

---

## References

- **Documentation Root**: `/backstage/backstage/docs/permissions/`
- **Plugin Source**: `/backstage/backstage/plugins/permission-*`
- **Examples**: Catalog backend implementation
- **Community RBAC**: `/backstage/community-plugins/workspaces/rbac/`
