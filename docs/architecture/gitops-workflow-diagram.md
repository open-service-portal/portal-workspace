# GitOps Workflow: Pull-Based Deployment with Backstage, Flux, and Crossplane

## Overview

This document illustrates how developers use Backstage to create full-stack applications that are automatically deployed via Flux using a pull-based GitOps model.

## Architecture Diagram

```mermaid
graph TB
    %% Actors - Using GitLab Personas
    %% https://handbook.gitlab.com/handbook/product/personas/
    Sasha["👩‍💻 Sasha<br/>Software Developer<br/>Builds Features"]
    Priyanka["🏗️ Priyanka<br/>Platform Engineer<br/>Creates Infrastructure"]
    Rachel["📦 Rachel<br/>Release Manager<br/>Ships to Production"]
    Sidney["🔧 Sidney<br/>Systems Admin<br/>Maintains Clusters"]
    Amy["🔒 Amy<br/>Security Engineer<br/>Ensures Compliance"]
    
    %% Backstage Layer
    subgraph Backstage["🎭 Backstage Portal"]
        Catalog["Software Catalog"]
        Scaffolder["Scaffolder Engine"]
        NodeTemplate["📦 Node Development<br/>Template"]
        K8sPlugin["🔍 Kubernetes Plugin<br/>Resource Monitor"]
    end
    
    %% Simone's Templates
    subgraph Templates["Platform Templates"]
        FrontendTpl["Frontend App<br/>Template"]
        BackendTpl["Backend API<br/>Template"]
        PostgresTpl["PostgreSQL<br/>Template"]
        Composition["🎯 Composition:<br/>Node Development<br/>Frontend + Backend + DB"]
    end
    
    %% GitHub Repositories
    subgraph GitHub["📂 GitHub Organization"]
        subgraph AppRepos["Application Repositories"]
            FrontendRepo["dashboard-frontend<br/>React App"]
            BackendRepo["dashboard-backend<br/>Node.js API"]
        end
        
        DeployRepo["🚀 dashboard-deploy<br/>Flux Manifests<br/>✅ flux-managed"]
    end
    
    %% Flux GitOps
    subgraph FluxGitOps["🔄 Flux - Pull-Based GitOps"]
        GitController["Source Controller<br/>Polls every 1min"]
        Kustomization["Kustomization Controller"]
        Note["⚡ PULL not PUSH<br/>Flux pulls from Git"]
    end
    
    %% Environments
    subgraph Environments["🌍 Multi-Environment Infrastructure"]
        subgraph DevEnv["Development Environment"]
            subgraph CrossplaneDev["🎯 Crossplane Dev"]
                XRDDev["XNodeApp<br/>Custom Resource"]
                CompDefDev["Composition Definition"]
                ResourcesDev["Managed Resources"]
            end
            
            subgraph K8sDev["☸️ Kubernetes Dev Cluster"]
                subgraph NamespaceDev["dashboard-dev namespace"]
                    FrontendDev["Frontend<br/>Deployment"]
                    BackendDev["Backend<br/>Deployment"]
                    PostgresDev["PostgreSQL<br/>StatefulSet"]
                end
            end
        end
        
        subgraph QAEnv["QA Environment"]
            subgraph CrossplaneQA["🎯 Crossplane QA"]
                XRDQA["XNodeApp<br/>Custom Resource"]
                CompDefQA["Composition Definition"]
                ResourcesQA["Managed Resources"]
            end
            
            subgraph K8sQA["☸️ Kubernetes QA Cluster"]
                subgraph NamespaceQA["dashboard-qa namespace"]
                    FrontendQA["Frontend<br/>Deployment"]
                    BackendQA["Backend<br/>Deployment"]
                    PostgresQA["PostgreSQL<br/>StatefulSet"]
                end
            end
        end
        
        subgraph ProdEnv["Production Environment"]
            subgraph CrossplaneProd["🎯 Crossplane Prod"]
                XRDProd["XNodeApp<br/>Custom Resource"]
                CompDefProd["Composition Definition"]
                ResourcesProd["Managed Resources"]
            end
            
            subgraph K8sProd["☸️ Kubernetes Prod Cluster"]
                subgraph NamespaceProd["dashboard namespace"]
                    FrontendProd["Frontend<br/>Deployment"]
                    BackendProd["Backend<br/>Deployment"]
                    PostgresProd["PostgreSQL<br/>StatefulSet"]
                    ServiceProd["Services"]
                    IngressProd["Ingress"]
                end
            end
        end
    end
    
    %% Priyanka's Flow (Platform Engineering)
    Priyanka -->|"Step 1: Creates Templates"| Templates
    FrontendTpl --> Composition
    BackendTpl --> Composition
    PostgresTpl --> Composition
    Composition -->|"Step 2: Registers"| NodeTemplate
    
    %% Sasha's Flow (Developer Experience)
    Sasha -->|"Step 3: Browse Catalog"| Catalog
    Catalog -->|"Step 4: Select Template"| NodeTemplate
    NodeTemplate -->|"Step 5: Fill Parameters"| Scaffolder
    Scaffolder -->|"Step 6a: Create Frontend Repo"| FrontendRepo
    Scaffolder -->|"Step 6b: Create Backend Repo"| BackendRepo
    Scaffolder -->|"Step 6c: Create Deploy Repo"| DeployRepo
    
    %% Amy's Security Review
    Amy -->|"Reviews Security"| DeployRepo
    Amy -.->|"Security Policies"| Kustomization
    
    %% Rachel's Release Management
    Rachel -->|"Manages Releases"| DeployRepo
    Rachel -.->|"Approves Prod Deploy"| ProdEnv
    
    %% Sidney's Operations
    Sidney -->|"Monitors Infrastructure"| K8sPlugin
    Sidney -.->|"Manages Clusters"| Environments
    
    %% GitOps Pull Flow
    DeployRepo -.->|"Step 7: PULL Changes<br/>Not Push!"| GitController
    GitController -->|"Step 8: Fetch Manifests"| Kustomization
    Kustomization -->|"Step 9: Apply to Dev"| XRDDev
    Kustomization -->|"Step 9: Apply to QA"| XRDQA
    Kustomization -->|"Step 9: Apply to Prod"| XRDProd
    
    %% Crossplane Provisioning - Dev
    XRDDev -->|"Step 10: Use Composition"| CompDefDev
    CompDefDev -->|"Step 11: Create Resources"| ResourcesDev
    ResourcesDev -->|"Step 12: Deploy Frontend"| FrontendDev
    ResourcesDev -->|"Step 13: Deploy Backend"| BackendDev
    ResourcesDev -->|"Step 14: Deploy Database"| PostgresDev
    
    %% Crossplane Provisioning - QA
    XRDQA --> CompDefQA
    CompDefQA --> ResourcesQA
    ResourcesQA --> FrontendQA
    ResourcesQA --> BackendQA
    ResourcesQA --> PostgresQA
    
    %% Crossplane Provisioning - Prod
    XRDProd --> CompDefProd
    CompDefProd --> ResourcesProd
    ResourcesProd --> FrontendProd
    ResourcesProd --> BackendProd
    ResourcesProd --> PostgresProd
    ResourcesProd --> ServiceProd
    ResourcesProd --> IngressProd
    
    %% Backstage Monitoring
    K8sPlugin -.->|"Reads Resource Status"| ResourcesDev
    K8sPlugin -.->|"Reads Resource Status"| ResourcesQA
    K8sPlugin -.->|"Reads Resource Status"| ResourcesProd
    K8sPlugin -.->|"Syncs to Catalog"| Catalog
    
    
    %% Styling
    classDef actor fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef backstage fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef template fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef repo fill:#f5f5f5,stroke:#424242,stroke-width:2px
    classDef deploy fill:#e8f5e9,stroke:#1b5e20,stroke-width:3px
    classDef flux fill:#c8e6c9,stroke:#2e7d32,stroke-width:2px
    classDef crossplane fill:#fce4ec,stroke:#880e4f,stroke-width:2px
    classDef k8s fill:#e3f2fd,stroke:#0d47a1,stroke-width:2px
    classDef environment fill:#fff9c4,stroke:#f57f17,stroke-width:3px
    classDef monitor fill:#e1bee7,stroke:#6a1b9a,stroke-width:2px
    
    class Sasha,Priyanka,Rachel,Sidney,Amy actor
    class Catalog,Scaffolder,NodeTemplate backstage
    class K8sPlugin monitor
    class FrontendTpl,BackendTpl,PostgresTpl,Composition template
    class FrontendRepo,BackendRepo repo
    class DeployRepo deploy
    class GitController,Kustomization,Note flux
    class XRDDev,XRDProd,XRDQA,CompDefDev,CompDefQA,CompDefProd,ResourcesDev,ResourcesQA,ResourcesProd crossplane
    class FrontendDev,BackendDev,PostgresDev,FrontendQA,BackendQA,PostgresQA,FrontendProd,BackendProd,PostgresProd,ServiceProd,IngressProd,NamespaceDev,NamespaceQA,NamespaceProd k8s
    class DevEnv,QAEnv,ProdEnv environment
```

## User Stories

> We use [GitLab's documented personas](https://handbook.gitlab.com/handbook/product/personas/) to represent typical users of our platform. These personas are based on extensive user research and help us design better experiences.

### 🏗️ Priyanka's Story: Building the Platform

**[Priyanka (Platform Engineer)](https://handbook.gitlab.com/handbook/product/personas/#priyanka-platform-engineer)** is responsible for building and maintaining the platform that development teams use. Priyanka creates reusable templates, manages Kubernetes clusters, and provides self-service infrastructure.

#### What Priyanka Creates:

1. **Individual Component Templates:**
   - **Frontend Template**: React app with TypeScript, routing, and state management
   - **Backend Template**: Node.js API with Express, authentication, and database connection
   - **PostgreSQL Template**: Database with persistent storage and backups

2. **Composition: Node Development**
   - Combines all three components into one deployable unit
   - Uses Crossplane Composition to define infrastructure
   - Creates Frontend Deployment, Backend Deployment, and PostgreSQL database
   - Example composition structure:
     ```yaml
     apiVersion: apiextensions.crossplane.io/v1
     kind: Composition
     metadata:
       name: node-development
     spec:
       compositeTypeRef:
         apiVersion: platform.io/v1
         kind: XNodeApp
       resources:
         - name: frontend
           base:
             apiVersion: apps/v1
             kind: Deployment
         - name: backend
           base:
             apiVersion: apps/v1
             kind: Deployment
         - name: database
           base:
             apiVersion: postgresql.cnpg.io/v1
             kind: Cluster
     ```

3. **Backstage Template Registration:**
   - Creates `template-node-development` repository
   - Backstage auto-discovers and adds to catalog
   - Developers can now self-serve complete stacks

### 👩‍💻 Sasha's Story: Creating a Dashboard

**[Sasha (Software Developer)](https://handbook.gitlab.com/handbook/product/personas/#sasha-software-developer)** is a software developer who wants to ship features as quickly and reliably as possible. Sasha needs to create a metrics dashboard for the team.

#### Sasha's Journey:

1. **Discovery**
   - Opens Backstage portal
   - Browses Software Catalog
   - Finds "Node Development" template

2. **Configuration**
   - Fills in the form:
     - Project name: `dashboard`
     - Team: `platform-team`
     - Database name: `metrics`
     - API port: `3001`
     - Enable monitoring: `true`

3. **Magic Happens** ✨
   - Backstage creates **THREE repositories**:
     - `dashboard-frontend` - React application code
     - `dashboard-backend` - Node.js API code  
     - `dashboard-deploy` - Deployment manifests (marked with `flux-managed`)

4. **Automatic Deployment**
   - Flux detects the new `dashboard-deploy` repository
   - Pulls the manifests (within 1 minute)
   - Applies Crossplane XR (XNodeApp)
   - Crossplane provisions all resources
   - Full stack is running in Kubernetes!

### 🔒 Amy's Story: Securing the Platform

**[Amy (Application Security Engineer)](https://handbook.gitlab.com/handbook/product/personas/#amy-application-security-engineer)** ensures that applications meet security standards and compliance requirements.

#### Amy's Security Workflow:

1. **Template Security Review**
   - Reviews Priyanka's templates for security best practices
   - Ensures secrets management is properly configured
   - Validates network policies and RBAC settings

2. **Deployment Manifest Scanning**
   - Automatically scans `dashboard-deploy` repository
   - Checks for exposed secrets or misconfigurations
   - Enforces security policies via OPA/Gatekeeper

3. **Runtime Security**
   - Monitors running workloads for vulnerabilities
   - Sets up security policies in Crossplane compositions
   - Ensures compliance with industry standards

### 📦 Rachel's Story: Managing Releases

**[Rachel (Release Manager)](https://handbook.gitlab.com/handbook/product/personas/#rachel-release-manager)** coordinates releases across environments and ensures smooth deployments.

#### Rachel's Release Process:

1. **Environment Promotion**
   - Reviews changes in Dev environment
   - Approves promotion to QA
   - Coordinates production releases

2. **GitOps Workflow**
   - Uses Git tags for release versions
   - Manages Kustomize overlays for each environment
   - Controls Flux sync policies

3. **Rollback Strategy**
   - Can quickly revert via Git
   - Flux automatically applies rollback
   - Zero-downtime deployments

### 🔧 Sidney's Story: Operating the Infrastructure

**[Sidney (Systems Administrator)](https://handbook.gitlab.com/handbook/product/personas/#sidney-systems-administrator)** maintains the Kubernetes clusters and ensures platform reliability.

#### Sidney's Operations:

1. **Cluster Management**
   - Monitors cluster health via Backstage Kubernetes Plugin
   - Manages node scaling and upgrades
   - Configures cluster-level resources

2. **Observability**
   - Sets up monitoring and alerting
   - Uses Backstage to visualize resource usage
   - Troubleshoots issues across environments

3. **Disaster Recovery**
   - Implements backup strategies
   - Tests failover procedures
   - Maintains runbooks in TechDocs

## Key Concepts

### Pull vs Push GitOps

| Aspect | Pull-Based (Flux) ✅ | Push-Based (CI/CD) ❌ |
|--------|---------------------|---------------------|
| **Direction** | Flux pulls from Git | CI pushes to cluster |
| **Security** | No external cluster access | Cluster credentials in CI |
| **Network** | Cluster never exposed | Requires ingress/API access |
| **Source of Truth** | Git only | Multiple sources |
| **Reconciliation** | Automatic | Manual triggers |

### Repository Structure

```
dashboard-frontend/          # Application code
├── .github/
│   └── workflows/
│       ├── ci.yaml        # Test & build
│       └── release.yaml   # Build & push image
├── src/
├── package.json
└── Dockerfile

dashboard-backend/           # Application code
├── .github/
│   └── workflows/
│       ├── ci.yaml        # Test & build
│       └── release.yaml   # Build & push image
├── src/
├── package.json
└── Dockerfile

dashboard-deploy/           # GitOps manifests
├── base/
│   ├── frontend-deployment.yaml
│   ├── backend-deployment.yaml
│   └── postgres-xr.yaml
├── overlays/
│   ├── dev/
│   └── prod/
└── kustomization.yaml
```

### Benefits

#### For Developers (Sasha)
- **One-click deployment** - Complete stack from a form
- **No YAML wrestling** - Templates handle complexity
- **Separation of concerns** - Code separate from deployment
- **Fast iteration** - Push code, Flux deploys automatically

#### For Platform Engineers (Simone)
- **Standardization** - All teams use same patterns
- **Reusability** - Write once, use many times
- **Governance** - Control via templates and compositions
- **Self-service** - Reduces support tickets

#### For Operations
- **GitOps** - Everything tracked in Git
- **Security** - No cluster credentials outside
- **Rollback** - Simple `git revert`
- **Observability** - Flux provides metrics and alerts

## How It Works

1. **Template Selection** → Developer picks template in Backstage
2. **Repository Creation** → Backstage creates app + deploy repos
3. **Code Development** → Developers work in app repos
4. **Manifest Management** → Deploy repo contains all K8s resources
5. **Flux Polling** → Flux continuously pulls from deploy repo
6. **Crossplane Magic** → Compositions create actual resources
7. **Kubernetes Reality** → Everything running in the cluster

## Summary

This architecture provides:
- **Pull-based security** - Cluster pulls, never exposed
- **Developer productivity** - Self-service everything
- **Platform scalability** - Templates reduce support burden
- **GitOps benefits** - Version control, audit, rollback
- **Multi-repo pattern** - Clean separation of code and config

## About the Personas

We use GitLab's well-researched personas to ensure our platform meets real user needs. Each persona represents real users based on extensive research:

### Core Personas in Our Workflow

#### [Sasha - Software Developer](https://handbook.gitlab.com/handbook/product/personas/#sasha-software-developer)
- **Goal**: Ship features quickly and reliably
- **Challenges**: Complex infrastructure, slow deployment processes
- **How we help**: Self-service templates, automated GitOps deployments

#### [Priyanka - Platform Engineer](https://handbook.gitlab.com/handbook/product/personas/#priyanka-platform-engineer)
- **Goal**: Build and maintain scalable platform infrastructure
- **Challenges**: Supporting diverse teams, ensuring consistency
- **How we help**: Crossplane compositions, Backstage templates

#### [Rachel - Release Manager](https://handbook.gitlab.com/handbook/product/personas/#rachel-release-manager)
- **Goal**: Coordinate smooth releases across environments
- **Challenges**: Managing dependencies, ensuring quality
- **How we help**: GitOps workflows, environment promotion

#### [Sidney - Systems Administrator](https://handbook.gitlab.com/handbook/product/personas/#sidney-systems-administrator)
- **Goal**: Maintain reliable infrastructure
- **Challenges**: Monitoring multiple clusters, incident response
- **How we help**: Backstage Kubernetes Plugin, centralized observability

#### [Amy - Application Security Engineer](https://handbook.gitlab.com/handbook/product/personas/#amy-application-security-engineer)
- **Goal**: Ensure applications meet security standards
- **Challenges**: Shift-left security, compliance requirements
- **How we help**: Security policies in templates, automated scanning

### Additional GitLab Personas

The complete [GitLab persona framework](https://handbook.gitlab.com/handbook/product/personas/) includes many other roles that interact with our platform:

- **[Parker - Product Manager](https://handbook.gitlab.com/handbook/product/personas/#parker-product-manager)**: Defines requirements and priorities
- **[Delaney - Development Team Lead](https://handbook.gitlab.com/handbook/product/personas/#delaney-development-team-lead)**: Manages development teams
- **[Presley - Product Designer](https://handbook.gitlab.com/handbook/product/personas/#presley-product-designer)**: Designs user experiences
- **[Allison - Application Ops](https://handbook.gitlab.com/handbook/product/personas/#allison-application-ops)**: Manages application operations
- **[Cameron - Compliance Manager](https://handbook.gitlab.com/handbook/product/personas/#cameron-compliance-manager)**: Ensures regulatory compliance

These personas help us build a platform that serves the entire organization's needs.