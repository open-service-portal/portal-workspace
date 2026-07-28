# Manage the cluster baseplate with Flux GitOps

**Date:** 2026-07-07
**Status:** Proposed — reopens Q1 from #139, needs team sign-off
**Relates to:** [#139](https://github.com/open-service-portal/open-service-portal/issues/139), [2026-07-01-ingress-to-gateway-api.md](./2026-07-01-ingress-to-gateway-api.md)

## Context

#139 asks us to make the cluster baseplate reproducible from git: the Gateway
API networking stack (Traefik v3 + Gateway API + cert-manager wildcard TLS +
External-DNS) currently exists only as live state on the Hetzner cluster, and
`cluster-setup.sh` still installs the retired `ingress-nginx`.

The scoping discussion settled on **T1 = fold the stack into `cluster-setup.sh`
inline** (imperative `helm upgrade --install`), and **Q1 ("Helm-via-Flux vs
inline") leaned inline** to match how cert-manager/external-dns are installed
today. Pascal's note was *"the rest is fine as it is."*

This record proposes the **other branch of Q1**: manage the baseplate with
**Flux** instead of imperative bash, as the first step toward a fully
GitOps-managed cluster where `cluster-setup.sh` shrinks to a one-time
`flux bootstrap`. It is deliberately raised as a proposal, not a fait accompli.

## Decision (proposed)

Manage the cluster baseplate declaratively with Flux. Git is the source of
truth; Flux continuously reconciles and self-heals drift. Layout follows the
canonical Flux monorepo pattern, kept **in this public repo** (honouring D1's
"alles an einem Ort"):

```
clusters/openportal/     # Flux Kustomizations: infra-crds → infra-controllers → infra-configs
infrastructure/
  crds/                  # Gateway API CRDs (vendored, pinned v1.2.1)
  controllers/           # HelmReleases (this slice: Traefik / GatewayClass)
  configs/               # wildcard Certificate, Gateway, gateway-config
```

### Why Flux over inline

- **Reproducible + self-healing:** the baseplate is desired-state in git; drift
  is auto-corrected, not just re-run.
- **Consistent with where the platform is going:** the catalog/catalog-orders
  layer is already Flux-driven; this extends the same model down to the
  baseplate.
- **Declarative ordering:** `dependsOn` + `wait` replace imperative sequencing.

### Why this might be wrong (the counter-case, for the reviewers)

- **Consistency today favours inline:** every other baseplate component is
  installed imperatively by `cluster-setup.sh`. This introduces a second
  paradigm until the migration completes.
- **Scope:** full GitOps is bigger than #139. This is why the change is sliced.
- It reopens a decision (Q1/T1) the team had already leaned on.

## Scope of the first slice (this PR)

- **Flux-managed:** Gateway API CRDs, Traefik (GatewayClass `traefik`), the
  wildcard Gateway, the wildcard Certificate, and the `gateway-config`
  EnvironmentConfig.
- **`cluster-setup.sh`:** `install_nginx_ingress` removed; a new
  `bootstrap_flux_infrastructure()` creates the `platform` GitRepository +
  root Kustomization pointing at `clusters/openportal`.
- **External-DNS:** source switched to `gateway-httproute` (+ Gateway API RBAC).
- **Kept imperative for now:** cert-manager, External-DNS, Crossplane, providers,
  functions, valkey-operator, environment-configs, SA tokens.

## Migration path (later slices)

1. cert-manager + ClusterIssuer → Flux (with **SOPS**-encrypted Cloudflare token;
   `.sops.yaml` + age key bootstrapped in Layer 0). Resolves D2.
2. External-DNS → Flux HelmRelease.
3. Crossplane + providers + functions + valkey-operator + environment-configs
   → Flux.
4. Retire the imperative install functions; `cluster-setup.sh` → thin
   `flux bootstrap` + secret seeding only.

## Open items / caveats

- **Unverified pins:** Traefik chart `33.2.1`, Gateway API `v1.2.1` are drafts —
  reconcile with the live Hetzner cluster before merge.
- **Ordering:** `infra-configs` (wildcard Certificate) depends on the
  imperatively-installed cert-manager; if it reconciles first, Flux retries
  until cert-manager is up. Clean once cert-manager moves to Flux (slice 1).
- **Untested on a fresh cluster:** the k3s 8000/8443 listener ports are not
  exercised on non-k3s dev clusters.
- **Pre-merge testing:** the bootstrap GitRepository defaults to `main`, but
  `clusters/openportal` only exists on `main` after this PR merges. To try it
  from the branch, set `PLATFORM_REPO_BRANCH=feat/gitops-baseplate`.
- **Decision needed:** proceed with GitOps (this proposal) or stay inline (T1)?
