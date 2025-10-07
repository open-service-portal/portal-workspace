# Ownership Guidelines for Open Service Portal

## Philosophy

GitHub Teams are the **single source of truth** for ownership in the Open Service Portal. This ensures consistency between access control, team membership, and resource ownership across all platform components.

## GitHub Teams Structure

The Open Service Portal uses GitHub Teams to define ownership and responsibilities:

- **`platform-team`**: Core infrastructure and platform capabilities
- **`service-provider`**: Service templates and applications
- Additional teams can be created for specific service provider groups (e.g., `service-provider-payments`, `service-provider-analytics`)

## Ownership Model

### Platform Team Responsibilities

The Platform Team (`group:default/platform-team`) owns and maintains:

#### Core Infrastructure Components
- **Namespaces**: `managednamespaces.openportal.dev`
- **DNS Management**: `dnsrecords.openportal.dev`, `cloudflarednsrecords.openportal.dev`
- **Cluster Management**: Future cluster provisioning XRDs
- **Networking**: Load balancers, ingress, service mesh
- **Security**: Policies, RBAC, secrets management
- **Storage**: Persistent volumes, backup strategies

#### Platform Services
- Crossplane configuration and providers
- GitOps tooling (Flux)
- Monitoring and observability stack
- CI/CD pipelines and scaffolding

### Service Provider Responsibilities

Service Provider teams (`group:default/service-provider`) own and maintain:

#### Application Templates
- Service scaffolding templates (e.g., `service-nodejs-template`, `service-mongodb-template`)
- Application-specific XRDs that build on core components
- Service compositions combining multiple resources

#### Custom Services
- Business applications as XRDs
- Composite services (e.g., `whoamiservices.openportal.dev`)
- API definitions and implementations
- Database-as-a-Service offerings

## Catalog Repository Structure

The ownership model is reflected in the catalog repository structure:

```
catalog/
├── core/                           # Owner: platform-team
│   ├── namespace/                  # Namespace management XRDs
│   ├── dns/                        # DNS management XRDs
│   ├── cluster/                    # Cluster provisioning XRDs
│   └── security/                   # Security policy XRDs
│
├── services/                       # Owner: service-provider teams
│   ├── applications/               # Application XRDs
│   ├── databases/                  # Database service XRDs
│   ├── messaging/                  # Message queue XRDs
│   └── apis/                       # API gateway XRDs
│
└── templates/                      # Mixed ownership
    ├── core/                       # Platform team templates
    └── services/                   # Service provider templates
```

## Multi-Team Scenarios

As the platform grows, additional service provider teams can be added:

```yaml
# Example multi-team structure
teams:
  - name: platform-team
    owns: 
      - Core infrastructure
      - Platform services
      - Security policies
  
  - name: service-provider-payments
    owns:
      - Payment processing services
      - Transaction APIs
      - Payment-related XRDs
  
  - name: service-provider-analytics
    owns:
      - Analytics platform
      - Data pipeline XRDs
      - Reporting services
  
  - name: service-provider-frontend
    owns:
      - Frontend applications
      - UI component libraries
      - Static site hosting
```

## Implementation in Backstage

### Template Ownership

Templates automatically discovered from GitHub should specify their owner:

```yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: service-nodejs-template
spec:
  owner: group:default/service-provider  # GitHub team reference
  type: service
```

### XRD Ownership

XRDs published to the catalog should include ownership metadata:

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: managednamespaces.openportal.dev
  annotations:
    backstage.io/owner: group:default/platform-team
```

### Automatic Owner Assignment

For auto-discovered resources, ownership can be inferred:

1. **By Repository Pattern**: 
   - `template-*` repos → platform-team (core infrastructure)
   - `service-*-template` repos → service-provider

2. **By XRD Category**:
   - Core resources (namespace, dns, cluster) → platform-team
   - Application resources → service-provider teams

## Benefits

- **Clear Accountability**: Every resource has a defined owner
- **Self-Service**: Service teams can create and manage their own XRDs
- **Scalability**: New teams can be onboarded easily
- **GitOps Integration**: Ownership is version-controlled and auditable
- **Backstage Integration**: Seamless filtering and discovery by team

## Migration Path

1. **Phase 1**: Document ownership model (this document)
2. **Phase 2**: Update existing templates with correct ownership
3. **Phase 3**: Configure automatic ownership assignment
4. **Phase 4**: Enforce ownership policies in CI/CD

## References

- [Backstage Ownership Model](https://backstage.io/docs/features/software-catalog/descriptor-format#specowner-required)
- [GitHub Teams Documentation](https://docs.github.com/en/organizations/organizing-members-into-teams)
- [Crossplane RBAC](https://docs.crossplane.io/latest/concepts/rbac/)