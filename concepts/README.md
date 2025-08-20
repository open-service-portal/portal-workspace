# Platform Concepts & Architecture Decisions

## Current Architecture (2025-08-14)

### 📍 [Platform Architecture Proposal](./2025-08-14-platform-architecture-decision.md)
**The main architecture document** - Start here!
- Proposed stack: FluxCD + Backstage + Crossplane
- Implementation guide with MongoDB example
- Industry validation from vRabbi and DevOpsToolkit

### 📊 [Supporting Analysis](./2025-08-14-platform-architecture-supporting-analysis.md)
Detailed analysis and evidence:
- Expert opinions breakdown
- Cost-benefit analysis
- Risk assessment
- Implementation roadmap

### 🔍 [Architecture Options: Detailed Analysis](./2025-08-14-architecture-options-detailed-analysis.md)
In-depth evaluation of all options:
- Option 1: Direct Apply (rejected)
- Option 2: Pure GitOps (accepted)
- Option 3A-D: Various enhancements and alternatives
- Decision matrix and rationale

## Quick Summary

**Our Stack:**
- **GitOps**: FluxCD (not ArgoCD) - Pure CRDs, 3x lighter
- **Portal**: Backstage (self-hosted) - With TeraSky plugins
- **Infrastructure**: Crossplane v2 - With auto-template generation
- **Pattern**: Option 2 (GitOps) + Option 3A (Immediate Feedback)

**Key Innovation**: 
Auto-generated templates from XRDs - no more manual template maintenance!

## Architecture Diagram

See [GitOps Workflow](../docs/architecture/2025-08-14-gitops-workflow-fluxcd.md) for visual representation.

---

*All previous scattered documents have been consolidated here for clarity.*