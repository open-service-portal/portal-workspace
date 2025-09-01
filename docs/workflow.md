# Open Service Portal Workflow Documentation

## Overview

The Open Service Portal orchestrates multiple workflows that enable teams to develop, release, and consume infrastructure and service templates. This document explains the complete platform workflow - from initial template development through automated release processes (including GitHub Actions) to GitOps deployment and resource provisioning via Backstage.

## High-Level Platform Workflow

The platform operates through three main workflow phases:

```mermaid
graph LR
    subgraph "1. Development Phase"
        D1[Create Template]
        D2[Test Locally]
        D3[Submit PR]
    end
    
    subgraph "2. Release Phase"
        R1[Merge to Main]
        R2[Tag Version]
        R3[GitHub Actions]
        R4[Publish to Catalog]
    end
    
    subgraph "3. Operations Phase"
        O1[GitOps Sync]
        O2[Discover in Backstage]
        O3[Developer Orders Resource]
        O4[Deploy via GitOps]
    end
    
    D3 --> R1
    R2 --> R3
    R4 --> O1
    O2 --> O3
    O3 --> O4
    
    style D1 fill:#e1f5fe
    style D2 fill:#e1f5fe
    style D3 fill:#e1f5fe
    style R1 fill:#fff3e0
    style R2 fill:#fff3e0
    style R3 fill:#fff3e0
    style R4 fill:#fff3e0
    style O1 fill:#e8f5e9
    style O2 fill:#e8f5e9
    style O3 fill:#e8f5e9
    style O4 fill:#e8f5e9
```

## Architecture Components

### Repository Structure

```mermaid
graph TB
    subgraph "Template Development"
        TR[template-* repositories<br/>Infrastructure Templates]
        SR[service-*-template repos<br/>Service Templates]
    end
    
    subgraph "GitOps Repositories"
        CAT[catalog repository<br/>Template Registry]
        ORD[catalog-orders repository<br/>Resource Instances]
    end
    
    subgraph "Platform"
        BS[Backstage<br/>app-portal]
        K8S[Kubernetes Cluster]
        XP[Crossplane]
    end
    
    subgraph "GitOps Engine"
        FLUX[Flux CD]
    end
    
    TR -->|Release| CAT
    SR -->|GitHub Discovery| BS
    CAT -->|Flux Sync| K8S
    K8S -->|K8s Ingestor| BS
    BS -->|Create Resources| ORD
    ORD -->|Flux Sync| K8S
    K8S --> XP
    
    style TR fill:#e1f5fe
    style SR fill:#e1f5fe
    style CAT fill:#fff3e0
    style ORD fill:#fff3e0
    style BS fill:#f3e5f5
    style K8S fill:#e8f5e9
    style XP fill:#e8f5e9
    style FLUX fill:#ffebee
```

## Development Workflows

### Local Development Workflow

```mermaid
stateDiagram-v2
    [*] --> Setup: Clone repository
    Setup --> Develop: Write code
    Develop --> Test: Local testing
    Test --> Develop: Fix issues
    Test --> Commit: Tests pass
    Commit --> Push: Push branch
    Push --> PR: Open pull request
    PR --> Review: Code review
    Review --> Develop: Changes requested
    Review --> Merge: Approved
    Merge --> [*]: Complete
```

### Template Development Process

Developers follow this process for creating new templates:

1. **Infrastructure Templates** (`template-*`)
   - Write XRD (API definition)
   - Create Composition (implementation)
   - Add examples and documentation
   - Test with local Crossplane

2. **Service Templates** (`service-*-template`)
   - Create Backstage template.yaml
   - Add scaffolding content
   - Configure GitHub Actions
   - Test with local Backstage

## Release Workflows

### GitHub Actions Automation

GitHub Actions serves as the automation engine for the release process:

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GH as GitHub
    participant GA as GitHub Actions
    participant Reg as Container Registry
    participant Cat as Catalog Repo
    
    Dev->>GH: 1. Push tag (v1.0.0)
    GH->>GA: 2. Trigger release workflow
    
    rect rgb(240, 248, 255)
        Note over GA: Automated Release Process
        GA->>GA: 3. Checkout code
        GA->>GA: 4. Build artifacts (.xpkg)
        GA->>Reg: 5. Push to ghcr.io
        GA->>GA: 6. Add version labels
        GA->>GH: 7. Create GitHub Release
        GA->>Cat: 8. Open PR to catalog
    end
    
    Dev->>Cat: 9. Review & merge PR
    Cat->>Cat: 10. Template available for GitOps
```

The GitHub Actions workflow (`/.github/workflows/release.yaml`) handles:
- Building Crossplane configuration packages
- Publishing container images
- Versioning templates
- Creating releases
- Updating the catalog repository

## GitOps Deployment Workflows

### 1. Template Release Flow

This flow shows how infrastructure templates are developed, released, and made available in the cluster.

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant Repo as template-* Repo
    participant GHA as GitHub Actions
    participant Reg as GitHub Registry
    participant Cat as Catalog Repo
    participant Flux as Flux CD
    participant K8s as Kubernetes
    participant Cross as Crossplane
    participant Back as Backstage

    Dev->>Repo: 1. Develop template<br/>(XRD + Composition)
    Dev->>Repo: 2. Create git tag v1.0.0
    Repo->>GHA: 3. Trigger release workflow
    
    rect rgb(240, 248, 255)
        Note over GHA: Release Process
        GHA->>GHA: 4. Build crossplane.xpkg
        GHA->>Reg: 5. Push to ghcr.io
        GHA->>GHA: 6. Add version label to XRD
        GHA->>Cat: 7. Open PR with versioned template
    end
    
    Dev->>Cat: 8. Merge PR
    
    rect rgb(255, 243, 224)
        Note over Flux,K8s: GitOps Sync
        Flux->>Cat: 9. Detect changes (polling/webhook)
        Flux->>K8s: 10. Apply XRD + Composition
        K8s->>Cross: 11. Register new CRD
    end
    
    rect rgb(243, 229, 245)
        Note over K8s,Back: Discovery
        Back->>K8s: 12. Kubernetes Ingestor polls
        K8s-->>Back: 13. Return XRDs with labels
        Back->>Back: 14. Generate Template entity<br/>Add source:kubernetes tag
        Back->>Back: 15. Display in /create catalog
    end
```

### 2. Resource Ordering Flow

This flow shows how developers use Backstage to create infrastructure resources that are deployed via GitOps.

```mermaid
sequenceDiagram
    participant User as Developer
    participant UI as Backstage UI
    participant Scaff as Scaffolder
    participant Git as GitHub API
    participant Orders as catalog-orders
    participant Flux as Flux CD
    participant K8s as Kubernetes
    participant Cross as Crossplane
    participant Prov as Providers

    User->>UI: 1. Browse /create catalog
    UI->>UI: 2. Show templates with versions<br/>(from K8s Ingestor)
    User->>UI: 3. Select template<br/>(e.g., DNSRecord v1.0.2)
    UI->>UI: 4. Generate form from XRD schema
    User->>UI: 5. Fill form and submit
    
    rect rgb(240, 248, 255)
        Note over Scaff,Git: Scaffolder Action
        UI->>Scaff: 6. Execute template action
        Scaff->>Scaff: 7. Generate XR YAML<br/>from template + inputs
        Scaff->>Git: 8. Create PR to catalog-orders<br/>Path: /namespaces/$NS/$TYPE/
        Scaff->>Git: 9. Auto-merge PR (if configured)
    end
    
    rect rgb(255, 243, 224)
        Note over Orders,K8s: GitOps Deployment
        Flux->>Orders: 10. Detect new XR files
        Flux->>K8s: 11. Apply XR to namespace
        K8s->>Cross: 12. XR triggers Composition
    end
    
    rect rgb(232, 245, 233)
        Note over Cross,Prov: Resource Creation
        Cross->>Cross: 13. Run composition pipeline<br/>(functions)
        Cross->>Prov: 14. Create managed resources<br/>(via providers)
        Prov->>Prov: 15. Provision actual resources<br/>(K8s objects, cloud resources)
        Prov-->>Cross: 16. Update status
        Cross-->>K8s: 17. Update XR status
    end
    
    K8s-->>UI: 18. Show resource status<br/>(via K8s plugin)
```

### 3. Multi-Repository Pattern

```mermaid
graph LR
    subgraph "Template Repositories"
        T1[template-dns-record]
        T2[template-cloudflare-dnsrecord]
        T3[template-whoami]
        T4[template-namespace]
    end
    
    subgraph "Catalog Repository"
        direction TB
        C1[templates/<br/>├── dns-record/<br/>│   ├── xrd.yaml<br/>│   └── composition.yaml<br/>├── cloudflare-dnsrecord/<br/>│   ├── xrd.yaml<br/>│   └── composition.yaml<br/>└── ...]
    end
    
    subgraph "Catalog-Orders Repository"
        direction TB
        O1[namespaces/<br/>├── team-alpha/<br/>│   ├── dns-records/<br/>│   │   ├── api-dns.yaml<br/>│   │   └── web-dns.yaml<br/>│   └── applications/<br/>│       └── frontend.yaml<br/>├── team-beta/<br/>│   └── dns-records/<br/>       └── backend-dns.yaml]
    end
    
    subgraph "Kubernetes Cluster"
        direction TB
        K1[XRDs<br/>(API Definitions)]
        K2[Compositions<br/>(Implementations)]
        K3[XRs<br/>(Resource Instances)]
    end
    
    T1 -->|Release| C1
    T2 -->|Release| C1
    T3 -->|Release| C1
    T4 -->|Release| C1
    
    C1 -->|Flux Sync| K1
    C1 -->|Flux Sync| K2
    O1 -->|Flux Sync| K3
    
    style T1 fill:#e1f5fe
    style T2 fill:#e1f5fe
    style T3 fill:#e1f5fe
    style T4 fill:#e1f5fe
    style C1 fill:#fff3e0
    style O1 fill:#fff3e0
    style K1 fill:#e8f5e9
    style K2 fill:#e8f5e9
    style K3 fill:#e8f5e9
```

## Detailed Component Interactions

### Backstage Integration Points

```mermaid
graph TB
    subgraph "Backstage Components"
        SC[Software Catalog]
        SF[Scaffolder]
        KI[Kubernetes Ingestor]
        KP[Kubernetes Plugin]
        TC[Template Cards UI]
    end
    
    subgraph "External Systems"
        GH[GitHub API]
        K8S[Kubernetes API]
        XRD[Crossplane XRDs]
    end
    
    subgraph "Data Flow"
        KI -->|Discover XRDs| K8S
        K8S -->|Return XRDs| KI
        KI -->|Create Templates| SC
        SC -->|Display| TC
        TC -->|User Selection| SF
        SF -->|Create PR| GH
        KP -->|Monitor Resources| K8S
    end
    
    style SC fill:#f3e5f5
    style SF fill:#f3e5f5
    style KI fill:#f3e5f5
    style KP fill:#f3e5f5
    style TC fill:#f3e5f5
```

### Flux GitOps Watchers

```mermaid
graph LR
    subgraph "Flux Sources"
        S1[catalog GitRepository]
        S2[catalog-orders GitRepository]
    end
    
    subgraph "Flux Kustomizations"
        K1[catalog-sync<br/>path: ./templates]
        K2[orders-sync<br/>path: ./namespaces]
    end
    
    subgraph "Applied Resources"
        R1[XRDs & Compositions<br/>(Template Definitions)]
        R2[XRs<br/>(Resource Instances)]
    end
    
    S1 -->|Watch| K1
    S2 -->|Watch| K2
    K1 -->|Apply| R1
    K2 -->|Apply| R2
    
    style S1 fill:#ffebee
    style S2 fill:#ffebee
    style K1 fill:#ffebee
    style K2 fill:#ffebee
```

## End-to-End Workflow Examples

### Example 1: Creating a DNS Record

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant BS as Backstage
    participant GH as GitHub
    participant Flux as Flux CD
    participant K8s as Kubernetes
    participant CP as Crossplane
    participant CF as Cloudflare
    
    Dev->>BS: 1. Browse /create catalog
    BS->>Dev: 2. Show DNS Record template v1.0.2
    Dev->>BS: 3. Fill form (name, type, value)
    BS->>GH: 4. Create PR to catalog-orders
    GH->>GH: 5. Auto-merge PR
    Flux->>GH: 6. Detect new XR file
    Flux->>K8s: 7. Apply DNSRecord XR
    K8s->>CP: 8. Trigger composition
    CP->>CF: 9. Create DNS record
    CF->>CP: 10. Confirm creation
    CP->>K8s: 11. Update XR status
    K8s->>BS: 12. Show ready status
```

### Example 2: Deploying an Application

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant BS as Backstage
    participant Scaff as Scaffolder
    participant GH as GitHub
    participant Flux as Flux CD
    participant K8s as Kubernetes
    participant Helm as Helm Provider
    
    Dev->>BS: 1. Select Whoami App template
    BS->>Dev: 2. Show configuration form
    Dev->>BS: 3. Configure (replicas, domain)
    BS->>Scaff: 4. Execute scaffolder action
    Scaff->>GH: 5. Create app repository
    Scaff->>GH: 6. Create XR in catalog-orders
    Flux->>GH: 7. Sync both repositories
    Flux->>K8s: 8. Apply app manifests
    K8s->>Helm: 9. Deploy helm chart
    Helm->>K8s: 10. Create pods, services
    K8s->>BS: 11. Show deployment status
```

## Configuration Examples

### Flux Configuration for Catalog

```yaml
# Flux GitRepository for catalog
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: catalog
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/open-service-portal/catalog
  ref:
    branch: main

---
# Flux Kustomization for syncing templates
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: catalog-sync
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: catalog
  path: "./templates"
  prune: true
```

### Flux Configuration for Orders

```yaml
# Flux GitRepository for catalog-orders
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: catalog-orders
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/open-service-portal/catalog-orders
  ref:
    branch: main

---
# Flux Kustomization for syncing XRs
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: orders-sync
  namespace: flux-system
spec:
  interval: 1m
  sourceRef:
    kind: GitRepository
    name: catalog-orders
  path: "./namespaces"
  prune: false  # Don't auto-delete user resources
```

### Backstage Scaffolder Template

```yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: crossplane-resource-order
  title: Order Crossplane Resource
spec:
  type: crossplane-xr
  steps:
    - id: generate
      name: Generate XR
      action: fetch:template
      input:
        url: ./content
        values:
          name: ${{ parameters.name }}
          namespace: ${{ parameters.namespace }}
          spec: ${{ parameters.spec }}
          
    - id: publish
      name: Publish to GitOps
      action: publish:github:pr
      input:
        repoUrl: github.com?owner=open-service-portal&repo=catalog-orders
        branchName: order-${{ parameters.name }}-${{ Date.now() }}
        title: "New resource: ${{ parameters.name }}"
        description: |
          Creating ${{ parameters.kind }} resource
          Namespace: ${{ parameters.namespace }}
        targetPath: namespaces/${{ parameters.namespace }}/${{ parameters.type }}
```

## Versioning Strategy

### Template Versioning Flow

```mermaid
graph TB
    subgraph "Version Sources"
        GT[Git Tag<br/>v1.2.3]
        GR[GitHub Release<br/>Release Notes]
    end
    
    subgraph "Version Propagation"
        XRD[XRD Label<br/>openportal.dev/version: 1.2.3]
        PKG[Package Version<br/>ghcr.io/template:v1.2.3]
        CAT[Catalog Entry<br/>With version label]
    end
    
    subgraph "Version Display"
        ING[K8s Ingestor<br/>Reads label]
        UI[Backstage UI<br/>Shows "Template v1.2.3"]
    end
    
    GT --> GR
    GR --> XRD
    GR --> PKG
    XRD --> CAT
    CAT --> ING
    ING --> UI
    
    style GT fill:#e1f5fe
    style GR fill:#e1f5fe
    style XRD fill:#fff3e0
    style PKG fill:#fff3e0
    style CAT fill:#fff3e0
    style ING fill:#f3e5f5
    style UI fill:#f3e5f5
```

## Namespace Organization

### catalog-orders Repository Structure

```mermaid
graph TB
    subgraph "catalog-orders/"
        ROOT[namespaces/]
        
        subgraph "Team Namespaces"
            NS1[team-alpha/]
            NS2[team-beta/]
            NS3[platform-team/]
        end
        
        subgraph "Resource Types"
            RT1[dns-records/]
            RT2[applications/]
            RT3[databases/]
            RT4[certificates/]
        end
        
        subgraph "XR Files"
            XR1[api-dns.yaml]
            XR2[web-app.yaml]
            XR3[postgres-prod.yaml]
        end
    end
    
    ROOT --> NS1
    ROOT --> NS2
    ROOT --> NS3
    NS1 --> RT1
    NS1 --> RT2
    RT1 --> XR1
    RT2 --> XR2
    NS2 --> RT3
    RT3 --> XR3
    
    style ROOT fill:#fff3e0
    style NS1 fill:#e1f5fe
    style NS2 fill:#e1f5fe
    style NS3 fill:#e1f5fe
```

## Crossplane v2 Architecture

### Namespaced XR Flow (No Claims)

```mermaid
graph LR
    subgraph "Developer Experience"
        DEV[Developer]
        XR[XR<br/>(Direct Resource)]
    end
    
    subgraph "Crossplane Processing"
        COMP[Composition]
        FUNC[Pipeline Functions]
        MR[Managed Resources]
    end
    
    subgraph "Infrastructure"
        PROV[Providers]
        RES[Actual Resources]
    end
    
    DEV -->|Creates| XR
    XR -->|Triggers| COMP
    COMP -->|Runs| FUNC
    FUNC -->|Generates| MR
    MR -->|Instructs| PROV
    PROV -->|Creates| RES
    
    style XR fill:#e8f5e9
    style COMP fill:#e8f5e9
    style FUNC fill:#e8f5e9
    
    Note1[No Claim needed!<br/>Direct XR in namespace]
    Note1 -.-> XR
    
    style Note1 fill:#ffffcc
```

## Error Handling and Recovery

### GitOps Error Recovery Flow

```mermaid
stateDiagram-v2
    [*] --> Applied: Resource applied
    Applied --> Error: Validation fails
    Applied --> Success: Validation passes
    
    Error --> Investigation: Check logs
    Investigation --> Fix: Identify issue
    Fix --> Retry: Update resource
    Retry --> Applied
    
    Success --> Monitoring: Continuous watch
    Monitoring --> Drift: Detect changes
    Drift --> Reconcile: Flux reapplies
    Reconcile --> Success
    
    state Error {
        [*] --> FluxError: Flux sync error
        [*] --> CrossplaneError: Composition error
        [*] --> ProviderError: Provider error
    }
    
    state Fix {
        [*] --> UpdateTemplate: Fix template
        [*] --> UpdateXR: Fix XR spec
        [*] --> UpdateConfig: Fix config
    }
```

## Monitoring and Observability

### Status Flow

```mermaid
graph TB
    subgraph "Status Sources"
        PS[Provider Status]
        CS[Composition Status]
        XS[XR Status]
        FS[Flux Status]
    end
    
    subgraph "Aggregation"
        CA[Crossplane Aggregates]
        BA[Backstage Aggregates]
    end
    
    subgraph "Display"
        UI[Backstage UI]
        KC[kubectl]
        FX[flux CLI]
    end
    
    PS --> CA
    CS --> CA
    XS --> CA
    CA --> BA
    BA --> UI
    XS --> KC
    FS --> FX
    
    style PS fill:#e8f5e9
    style CS fill:#e8f5e9
    style XS fill:#e8f5e9
    style FS fill:#ffebee
```

## Best Practices

### 1. Template Development
- Always use Crossplane v2 with namespaced XRs
- Include comprehensive examples
- Add proper RBAC permissions
- Use semantic versioning

### 2. GitOps Repository Management
- Keep catalog organized by template type
- Use clear directory structure in catalog-orders
- Enable branch protection on main
- Set up automated PR validation

### 3. Backstage Integration
- Ensure XRDs have required labels
- Keep Kubernetes Ingestor polling interval reasonable
- Cache template data appropriately
- Provide clear template descriptions

### 4. Production Considerations
- Pin provider versions in production
- Implement proper RBAC for namespaces
- Set up monitoring and alerting
- Plan for disaster recovery

## Troubleshooting Guide

### Common Issues

1. **Template not appearing in Backstage**
   - Check XRD has `terasky.backstage.io/generate-form: "true"` label
   - Verify Flux has synced the template
   - Check Kubernetes Ingestor logs
   - Ensure XRD is valid and applied

2. **Resource creation fails**
   - Check Flux sync status: `flux get all`
   - Verify XR syntax is correct
   - Check Crossplane composition logs
   - Ensure providers are healthy

3. **Version not showing**
   - Verify `openportal.dev/version` label on XRD
   - Check release workflow completed
   - Ensure catalog has latest version
   - Force refresh in Backstage

## Workflow Integration Points

### How Workflows Connect

```mermaid
graph TB
    subgraph "Development"
        DW[Developer Workflow]
        TW[Template Creation]
    end
    
    subgraph "Automation"
        GHA[GitHub Actions]
        REL[Release Process]
    end
    
    subgraph "GitOps"
        FLUX[Flux CD]
        SYNC[Continuous Sync]
    end
    
    subgraph "Platform"
        BS[Backstage Portal]
        K8S[Kubernetes]
        XP[Crossplane]
    end
    
    DW --> TW
    TW --> GHA
    GHA --> REL
    REL --> FLUX
    FLUX --> SYNC
    SYNC --> K8S
    K8S --> BS
    BS --> XP
    XP --> K8S
    
    style DW fill:#e1f5fe
    style TW fill:#e1f5fe
    style GHA fill:#fff3e0
    style REL fill:#fff3e0
    style FLUX fill:#ffebee
    style SYNC fill:#ffebee
    style BS fill:#f3e5f5
    style K8S fill:#e8f5e9
    style XP fill:#e8f5e9
```

## Summary

The Open Service Portal workflow orchestrates multiple processes to deliver a complete platform experience:

### 1. **Development Workflows**
   - Local development with immediate feedback
   - Template creation following standards
   - PR-based collaboration and review
   - Testing before release

### 2. **Release Automation**
   - GitHub Actions automate the release pipeline
   - Semantic versioning throughout
   - Automatic catalog updates
   - Container registry publishing

### 3. **GitOps Deployment**
   - Flux ensures desired state
   - Two-repository pattern (catalog + orders)
   - Continuous reconciliation
   - Drift detection and correction

### 4. **Platform Integration**
   - Backstage provides the developer portal
   - Kubernetes hosts all resources
   - Crossplane manages infrastructure
   - Everything connected via APIs

### Key Benefits

1. **Developer Experience**
   - Self-service infrastructure provisioning
   - Visual forms generated from templates
   - Real-time status monitoring
   - No direct kubectl needed

2. **Operational Excellence**
   - Every change tracked in Git
   - Automated deployment pipeline
   - Consistent environments
   - Rollback capabilities

3. **Governance & Compliance**
   - Template approval process
   - RBAC at every level
   - Audit trail in Git history
   - Policy enforcement via Crossplane

4. **Scalability**
   - Multi-team support via namespaces
   - Template reusability
   - Automated processes reduce toil
   - GitOps scales with Git

This comprehensive workflow enables teams to move fast while maintaining safety and control, bridging the gap between development velocity and operational stability.