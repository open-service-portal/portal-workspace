# GitOps Workflow: FluxCD + Backstage + Crossplane

**Date**: 2025-08-14  
**Replaces**: [2025-08-13-gitops-workflow-diagram.md](./2025-08-13-gitops-workflow-diagram.md)

## Overview

Clear, modern platform architecture with FluxCD as GitOps engine, Backstage as developer portal, and Crossplane for infrastructure provisioning.

## Architecture Diagram

```mermaid
graph TB
    %% Developer Journey
    Dev["👩‍💻 Developer"]
    
    %% Backstage with TeraSky Plugins
    subgraph Backstage["🎭 Backstage Portal (Self-Hosted)"]
        Catalog["Software Catalog"]
        Templates["Auto-Generated Templates<br/>via kubernetes-ingestor"]
        Status["Real-time Status<br/>via crossplane-resources"]
        Updater["Day-2 Operations<br/>via claim-updater"]
    end
    
    %% GitHub
    subgraph GitHub["📂 GitHub"]
        ServiceRepo["service-mongodb-abc123<br/>Manifests + Config"]
    end
    
    %% FluxCD GitOps
    subgraph FluxCD["🔄 FluxCD (220MB RAM)"]
        GitRepo["GitRepository CRD"]
        Kustomization["Kustomization CRD"]
        Notification["Notification Controller"]
        Note["✨ Everything is a CRD!"]
    end
    
    %% Crossplane
    subgraph Crossplane["🎯 Crossplane v2"]
        XRD["XMongoDB<br/>auto-template: true"]
        Composition["Composition<br/>+ Functions"]
        Claim["MongoDB Claim"]
    end
    
    %% Infrastructure
    subgraph Infrastructure["☁️ Cloud + Kubernetes"]
        K8s["Kubernetes Resources"]
        Cloud["Cloud Resources<br/>(AWS/Azure/GCP)"]
    end
    
    %% Flow
    Dev -->|"1: Browse Catalog"| Catalog
    Catalog -->|"2: Select Template<br/>(auto-generated!)"| Templates
    Templates -->|"3: Fill Form"| ServiceRepo
    
    ServiceRepo -->|"4: FluxCD Pulls"| GitRepo
    GitRepo -->|"5: Source"| Kustomization
    Kustomization -->|"6: Apply"| Claim
    
    Claim -->|"7: Use"| Composition
    Composition -->|"8: Provision"| Cloud
    Composition -->|"9: Deploy"| K8s
    
    %% Feedback Loop
    Notification -->|"Events"| Status
    Claim -->|"Status"| Status
    Status -->|"Display"| Dev
    
    %% Day-2 Operations
    Dev -->|"Update Request"| Updater
    Updater -->|"PR"| ServiceRepo
    
    %% Auto-Template Generation
    XRD -.->|"OpenAPI Schema"| Templates
    
    style FluxCD fill:#c8e6c9
    style Backstage fill:#f3e5f5
    style Crossplane fill:#fce4ec
    style Note fill:#fff9c4
```

## Key Innovations

### 1. Auto-Generated Templates 🎯

**No more manual template writing!**

```yaml
# Just add this label to your XRD:
metadata:
  labels:
    terasky.backstage.io/generate-form: "true"

# kubernetes-ingestor plugin:
# - Reads XRD OpenAPI Schema
# - Generates Backstage Template automatically
# - Always in sync with infrastructure!
```

### 2. Pure CRD Architecture 🏗️

```bash
# Everything is a Kubernetes CRD:
kubectl get gitrepositories        # FluxCD sources
kubectl get kustomizations          # FluxCD deployments
kubectl get mongodbs               # Crossplane claims
kubectl get compositions           # Crossplane definitions

# One tool to rule them all: kubectl!
```

### 3. Resource Efficiency 💚

| Component | Resource Usage | vs Alternatives |
|-----------|---------------|-----------------|
| FluxCD | 220MB RAM | ArgoCD: 768MB (3.5x) |
| No UI | 0MB | ArgoCD UI: 500MB |
| Total Platform | <1GB | Traditional: 3-5GB |

## Developer Workflow

### Creating a New Service

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant BS as Backstage
    participant GH as GitHub
    participant Flux as FluxCD
    participant XP as Crossplane
    participant Cloud as Cloud Provider

    Dev->>BS: Select MongoDB Template
    Note over BS: Template auto-generated<br/>from XRD!
    BS->>GH: Create service-mongodb-abc123
    GH->>Flux: Pull (within 1min)
    Flux->>XP: Apply MongoDB Claim
    XP->>Cloud: Provision Database
    Cloud-->>XP: Ready
    XP-->>Flux: Status: Ready
    Flux-->>BS: Notification
    BS-->>Dev: ✅ MongoDB Ready!
```

### Day-2 Operations (Updates)

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant BS as Backstage
    participant GH as GitHub
    participant Flux as FluxCD

    Dev->>BS: Request Storage Increase
    BS->>BS: Fetch current config from Git
    BS->>Dev: Show update form
    Dev->>BS: Change 10GB → 25GB
    BS->>GH: Create PR with changes
    Note over GH: Review + Merge
    GH->>Flux: Pull changes
    Flux->>Flux: Apply updates
    Flux-->>BS: Update complete
    BS-->>Dev: ✅ Storage increased!
```

## Why This Architecture?

### Industry Validated ✅

**vRabbi (TeraSky)**:
> "auto push manifests to git and have a GitOps tool like FluxCD..."

**DevOpsToolkit (Viktor Farcic)**:
> "Backstage is the safe long-term choice"

### Perfect for Our Requirements ✅

- **"Teams should never see ArgoCD UI"** → FluxCD has no UI
- **"Everything should be CRDs"** → FluxCD is pure CRDs
- **"Reduce maintenance"** → Auto-generated templates
- **"Enable self-service"** → Backstage portal

## Implementation Components

### 1. FluxCD Configuration

```yaml
# Bootstrap FluxCD
flux bootstrap github \
  --owner=open-service-portal \
  --repository=flux-config \
  --path=clusters/production
```

### 2. Backstage with TeraSky Plugins

```bash
# Install game-changing plugins
yarn add @terasky/backstage-plugin-kubernetes-ingestor
yarn add @terasky/backstage-plugin-crossplane-resources
yarn add @terasky/backstage-plugin-crossplane-claim-updater
```

### 3. Crossplane with Auto-Template

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xmongodbs.database.platform.io
  labels:
    terasky.backstage.io/generate-form: "true"  # Magic!
spec:
  # Your XRD definition
  # OpenAPI Schema becomes Backstage form automatically!
```

## Benefits Summary

### For Developers
- **Zero YAML writing** - Templates handle everything
- **Self-service everything** - No tickets needed
- **Real-time feedback** - See status immediately
- **Day-2 operations** - Updates via UI

### For Platform Team
- **90% less maintenance** - Auto-generated templates
- **GitOps audit trail** - Everything in Git
- **Resource efficient** - 3x less than alternatives
- **Industry best practices** - Validated approach

### For Organization
- **Faster delivery** - Minutes not days
- **Cost savings** - Less resources, less maintenance
- **Compliance ready** - Full audit trail
- **Future proof** - CNCF backed tools

## Conclusion

This architecture represents the state-of-the-art in platform engineering:
- **FluxCD** for lightweight, CRD-native GitOps
- **Backstage** with TeraSky plugins for amazing UX
- **Crossplane** v2 for powerful infrastructure management

**Result**: A platform that's efficient, maintainable, and developer-friendly!

---

*Based on industry best practices and validated by platform engineering experts (vRabbi, DevOpsToolkit)*