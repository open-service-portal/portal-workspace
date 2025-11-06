# Kubernetes RBAC Inventory

This document provides a comprehensive inventory of all Role-Based Access Control (RBAC) configurations in the Kubernetes cluster as of 2025-10-31.

## Table of Contents

- [Overview](#overview)
- [ClusterRoles](#clusterroles)
- [ClusterRoleBindings](#clusterrolebindings)
- [Namespace-scoped Roles](#namespace-scoped-roles)
- [Namespace-scoped RoleBindings](#namespace-scoped-rolebindings)

## Overview

This cluster contains:
- **114 ClusterRoles** (cluster-wide permission sets)
- **62 ClusterRoleBindings** (cluster-wide permission assignments)
- **17 Roles** (namespace-scoped permission sets)
- **23 RoleBindings** (namespace-scoped permission assignments)

## ClusterRoles

### Platform Administration

#### admin
- **Type**: Aggregated role (aggregate-to-admin label)
- **Permissions**: Full CRUD on namespaced resources
- **Key Resources**:
  - Cert-manager certificates, issuers, CRs
  - Flux toolkit resources (all API groups)
  - Pods, secrets, services, deployments
  - RBAC roles and rolebindings within namespace
  - Can impersonate service accounts

#### cluster-admin
- **Type**: Super-user role
- **Permissions**: Full access to all resources cluster-wide
- **Created**: 2025-09-08 (bootstrap)

#### edit
- **Type**: Standard editing role
- **Permissions**: Edit most resources in namespace
- **Excludes**: RBAC resources (roles/rolebindings)

#### view
- **Type**: Read-only role
- **Permissions**: View most resources in namespace
- **Excludes**: Secrets

### Calico Networking

#### calico-cni-plugin
- **Owner**: Installation/default (Tigera operator)
- **Finalizer**: tigera.io/cni-protector
- **Permissions**:
  - Get/patch pods and pod status
  - CRUD on IPAM resources (blocks, handles, affinities)
  - Get nodes, namespaces, IP pools

#### calico-node
- **Owner**: Installation/default (Tigera operator)
- **Finalizer**: tigera.io/cni-protector
- **Permissions**:
  - Watch/list networking policies
  - Update node status
  - Manage Calico CRDs (BGP, Felix, network policies)
  - Create service account tokens for calico-cni-plugin

#### calico-kube-controllers
- **Owner**: Installation/default (Tigera operator)
- **Permissions**:
  - Watch nodes, services, endpoints, pods
  - Manage IPAM resources
  - Manage cluster information and host endpoints

#### calico-typha
- **Owner**: Installation/default (Tigera operator)
- **Permissions**: Similar to calico-node
- **Purpose**: Scalability layer between datastore and Felix

#### calico-crds
- **Owner**: APIServer/default (Tigera operator)
- **Permissions**: Full CRUD on all Calico CRDs
- **Resources**: Network policies, BGP configs, IP pools, etc.

### Cert-Manager

#### cert-manager-controller-certificates
- **Helm Release**: cert-manager/cert-manager
- **Permissions**:
  - Manage certificates and certificate requests
  - Create/manage secrets for TLS
  - Create ACME orders

#### cert-manager-controller-clusterissuers
- **Permissions**: Manage cluster-wide certificate issuers
- **Resources**: ClusterIssuers, secrets (for issuer credentials)

#### cert-manager-controller-issuers
- **Permissions**: Manage namespace-scoped issuers
- **Resources**: Issuers, secrets

#### cert-manager-controller-challenges
- **Permissions**: ACME challenge management
- **Resources**: Create pods, services, ingresses for validation

#### cert-manager-controller-orders
- **Permissions**: ACME order management
- **Resources**: Orders, challenges

#### cert-manager-controller-ingress-shim
- **Permissions**: Automatic certificate creation from ingress annotations
- **Resources**: Ingresses, certificates

#### cert-manager-cainjector
- **Permissions**: Inject CA bundles into webhooks and API services
- **Resources**: ValidatingWebhookConfigurations, MutatingWebhookConfigurations, APIServices, CRDs

### Crossplane

#### crossplane
- **Helm Release**: crossplane/crossplane-system
- **Version**: 2.0.0
- **Permissions**: Manage Crossplane core resources
- **Resources**: XRDs, Compositions, CompositeResources, ProviderConfigs

#### crossplane-admin
- **Permissions**: Administrative access to Crossplane
- **Group**: crossplane:masters

#### crossplane-rbac-manager
- **Permissions**: Manage RBAC for Crossplane providers and compositions
- **Service Account**: rbac-manager/crossplane-system

#### crossplane:provider:provider-kubernetes-*
- **Dynamic**: Created per provider revision
- **Permissions**: Provider-specific Kubernetes resource management

#### crossplane:provider:provider-helm-*
- **Dynamic**: Created per provider revision
- **Permissions**: Helm release management

### Flux GitOps

#### crd-controller
- **Instance**: flux-system
- **Permissions**: Manage Flux CRDs
- **Service Accounts**: All Flux controllers

#### cluster-reconciler
- **Instance**: flux-system
- **Permissions**: Cluster-admin for reconciliation
- **Service Accounts**: kustomize-controller, helm-controller

### Ingress NGINX

#### ingress-nginx
- **Helm Release**: ingress-nginx/ingress-nginx
- **Version**: 1.13.2
- **Permissions**:
  - Watch/list ingresses, services, endpoints
  - Update ingress status
  - Manage leader election

#### ingress-nginx-admission
- **Permissions**: Admission webhook operations
- **Resources**: ValidatingWebhookConfigurations

### External-DNS

#### external-dns
- **Permissions**:
  - Watch services, ingresses, nodes
  - Read DNSEndpoint CRDs
  - Update DNS records via provider APIs

### Custom RBAC (OpenPortal)

#### namespace-user-*
- **Pattern**: Dynamically created per namespace
- **Permissions**: User access within specific namespaces
- **Management**: rbac-add-namespace-access scripts

## ClusterRoleBindings

### Platform Administration

#### cluster-admin
- **Subjects**: Group `system:masters`
- **Role**: cluster-admin
- **Bootstrap**: Core Kubernetes RBAC

#### admin-fboehm-ext
- **Annotations**: rbac.openportal.dev/managed-by=rbac-add-admin
- **Subject**: User `oidc:fboehm.ext@cloudpunks.de`
- **Role**: cluster-admin
- **Created**: 2025-10-27T14:16:05Z

#### admin-mbrueckner
- **Annotations**: rbac.openportal.dev/managed-by=rbac-add-admin
- **Subject**: User `oidc:mbrueckner@cloudpunks.de`
- **Role**: cluster-admin
- **Created**: 2025-10-27T14:15:07Z

#### cloudspace-admin-role
- **Subject**: Group `oidc:org_zOuCBHiyF1yG8d1D`
- **Role**: cluster-admin
- **Created**: 2025-10-27T21:18:02Z

### Service Accounts

#### backstage-k8s-sa-binding
- **Subject**: ServiceAccount `backstage-k8s-sa/default`
- **Role**: cluster-admin
- **Purpose**: Backstage Kubernetes plugin access

#### gha-app-portal-deploy-k8s-sa-binding
- **Subject**: ServiceAccount `gha-app-portal-deploy-k8s-sa/default`
- **Role**: cluster-admin
- **Purpose**: GitHub Actions deployment

#### felixadmin-admin
- **Subject**: ServiceAccount `felixadmin/default`
- **Role**: cluster-admin
- **Created**: 2025-10-27T14:07:19Z

### Calico Networking

#### calico-cni-plugin
- **Subject**: ServiceAccount `calico-cni-plugin/calico-system`
- **Role**: calico-cni-plugin
- **Finalizer**: tigera.io/cni-protector

#### calico-node
- **Subject**: ServiceAccount `calico-node/calico-system`
- **Role**: calico-node
- **Finalizer**: tigera.io/cni-protector

#### calico-typha
- **Subject**: ServiceAccount `calico-typha/calico-system`
- **Role**: calico-typha

#### calico-kube-controllers
- **Subject**: ServiceAccount `calico-kube-controllers/calico-system`
- **Role**: calico-kube-controllers

#### calico-apiserver-*
- **Multiple bindings**: For API server functionality
- **Roles**: calico-crds, auth-delegator, webhook-reader

### Cert-Manager

All cert-manager ClusterRoleBindings bind to service accounts in the `cert-manager` namespace:

- **cert-manager-cainjector** → cert-manager-cainjector SA
- **cert-manager-controller-*** → cert-manager SA (multiple for different controllers)
- **cert-manager-webhook:subjectaccessreviews** → cert-manager-webhook SA

### Crossplane

#### crossplane
- **Subject**: ServiceAccount `crossplane/crossplane-system`
- **Role**: crossplane

#### crossplane-admin
- **Subject**: Group `crossplane:masters`
- **Role**: crossplane-admin

#### crossplane-rbac-manager
- **Subject**: ServiceAccount `rbac-manager/crossplane-system`
- **Role**: crossplane-rbac-manager

#### crossplane:provider:provider-*
- **Dynamic**: Per provider revision
- **Subject**: Provider-specific service accounts

### Flux

#### cluster-reconciler
- **Subjects**:
  - ServiceAccount `kustomize-controller/flux-system`
  - ServiceAccount `helm-controller/flux-system`
- **Role**: cluster-admin

#### crd-controller
- **Subjects**: All Flux controller service accounts
- **Role**: crd-controller

### Ingress & DNS

#### ingress-nginx
- **Subject**: ServiceAccount `ingress-nginx/ingress-nginx`
- **Role**: ingress-nginx

#### ingress-nginx-admission
- **Subject**: ServiceAccount `ingress-nginx-admission/ingress-nginx`
- **Role**: ingress-nginx-admission

#### external-dns
- **Subject**: ServiceAccount `external-dns/external-dns`
- **Role**: external-dns

### Other Components

#### metrics-server
- **Subject**: ServiceAccount `metrics-server/kube-system`
- **Role**: system:metrics-server

#### kubernetes-dashboard
- **Subject**: ServiceAccount `kubernetes-dashboard/kubernetes-dashboard`
- **Role**: kubernetes-dashboard

#### tigera-operator
- **Subject**: ServiceAccount `tigera-operator/tigera-operator`
- **Role**: tigera-operator

## Namespace-scoped Roles

### cert-manager Namespace

#### cert-manager:leaderelection
- **Permissions**: Leader election coordination
- **Resources**: Leases in coordination.k8s.io

#### cert-manager-cainjector:leaderelection
- **Permissions**: Leader election for CA injector
- **Resources**: Specific lease resources

#### cert-manager-webhook:dynamic-serving
- **Permissions**: Manage webhook TLS certificates
- **Resources**: Secret `cert-manager-webhook-ca`

#### cert-manager-tokenrequest
- **Permissions**: Create service account tokens
- **Resources**: cert-manager service account tokens

### ingress-nginx Namespace

#### ingress-nginx
- **Permissions**:
  - Read configmaps, pods, secrets, endpoints, services
  - Update ingress status
  - Leader election

### kube-system Namespace

#### extension-apiserver-authentication-reader
- **Bootstrap**: Core Kubernetes
- **Permissions**: Read extension-apiserver-authentication ConfigMap

#### system::leader-locking-kube-controller-manager
- **Bootstrap**: Core Kubernetes
- **Permissions**: Leader election for kube-controller-manager

#### system::leader-locking-kube-scheduler
- **Bootstrap**: Core Kubernetes
- **Permissions**: Leader election for kube-scheduler

#### system:controller:bootstrap-signer
- **Bootstrap**: Core Kubernetes
- **Permissions**: Manage bootstrap tokens

#### system:controller:cloud-provider
- **Bootstrap**: Core Kubernetes
- **Permissions**: Cloud provider integration

#### system:controller:token-cleaner
- **Bootstrap**: Core Kubernetes
- **Permissions**: Clean up expired tokens

#### kubeadm:kubelet-config
- **Purpose**: Kubelet configuration access
- **Permissions**: Read kubelet-config ConfigMap

#### kubeadm:nodes-kubeadm-config
- **Purpose**: Node configuration access
- **Permissions**: Read kubeadm-config ConfigMap

#### rxt-kube-proxy
- **Owner**: ClusterProfile/proxy-addons (Sveltos)
- **Permissions**: Read kube-proxy configuration

### kube-public Namespace

#### kubeadm:bootstrap-signer-clusterinfo
- **Purpose**: Cluster discovery
- **Permissions**: Read cluster-info ConfigMap

#### system:controller:bootstrap-signer
- **Purpose**: Bootstrap token signing
- **Permissions**: Manage bootstrap ConfigMaps

### kubernetes-dashboard Namespace

#### kubernetes-dashboard
- **Helm Release**: kubernetes-dashboard/kubernetes-dashboard
- **Permissions**:
  - Manage dashboard secrets and configmaps
  - Proxy to metrics services

## Namespace-scoped RoleBindings

### cert-manager Namespace

- **cert-manager:leaderelection** → cert-manager SA
- **cert-manager-cainjector:leaderelection** → cert-manager-cainjector SA
- **cert-manager-webhook:dynamic-serving** → cert-manager-webhook SA
- **cert-manager-cert-manager-tokenrequest** → cert-manager SA

### demo Namespace

#### test-at-felixboehm-it-edit-binding
- **Annotations**: rbac.openportal.dev/managed-by=rbac-add-namespace-access
- **Subject**: User `oidc:test@felixboehm.it`
- **Role**: edit (ClusterRole)
- **Created**: 2025-10-27T14:46:47Z

#### test-edit-binding
- **Annotations**: rbac.openportal.dev/managed-by=rbac-add-namespace-access
- **Subject**: User `oidc:test@felixboehm.it`
- **Role**: edit (ClusterRole)
- **Created**: 2025-10-27T14:31:05Z

### team-felix Namespace

#### test-at-felixboehm-it-edit-binding
- **Annotations**: rbac.openportal.dev/managed-by=rbac-add-namespace-access
- **Subject**: User `oidc:test@felixboehm.it`
- **Role**: edit (ClusterRole)
- **Created**: 2025-10-27T14:46:27Z

### ingress-nginx Namespace

#### ingress-nginx
- **Subject**: ServiceAccount `ingress-nginx/ingress-nginx`
- **Role**: ingress-nginx

### kube-public Namespace

#### kubeadm:bootstrap-signer-clusterinfo
- **Subject**: User `system:anonymous`
- **Role**: kubeadm:bootstrap-signer-clusterinfo
- **Purpose**: Public cluster discovery

#### system:controller:bootstrap-signer
- **Subject**: ServiceAccount `bootstrap-signer/kube-system`
- **Role**: system:controller:bootstrap-signer

### kube-system Namespace

#### calico-apiserver-auth-reader
- **Subject**: ServiceAccount `calico-apiserver/calico-apiserver`
- **Role**: extension-apiserver-authentication-reader

#### kubeadm:kubelet-config
- **Subjects**: Groups `system:nodes`, `system:bootstrappers:kubeadm:default-node-token`
- **Role**: kubeadm:kubelet-config

#### kubeadm:nodes-kubeadm-config
- **Subjects**: Groups `system:bootstrappers:kubeadm:default-node-token`, `system:nodes`
- **Role**: kubeadm:nodes-kubeadm-config

#### metrics-server-auth-reader
- **Subject**: ServiceAccount `metrics-server/kube-system`
- **Role**: extension-apiserver-authentication-reader

#### rxt-kube-proxy
- **Subject**:
  - Group `system:bootstrappers:kubeadm:default-node-token`
  - ServiceAccount `rxt-kube-proxy`
- **Role**: rxt-kube-proxy

#### system::* (multiple)
- **Bootstrap**: Core Kubernetes system bindings
- **Purpose**: Controller manager, scheduler, cloud provider access

### kubernetes-dashboard Namespace

#### kubernetes-dashboard
- **Subject**: ServiceAccount `kubernetes-dashboard/kubernetes-dashboard`
- **Role**: kubernetes-dashboard

## Key Patterns and Conventions

### OpenPortal RBAC Management

The cluster uses custom scripts and annotations for RBAC management:

- **Cluster Admins**: Managed via `rbac-add-admin` script
  - Annotation: `rbac.openportal.dev/managed-by: rbac-add-admin`
  - Label: `rbac.openportal.dev/type: explicit-admin`

- **Namespace Access**: Managed via `rbac-add-namespace-access` script
  - Annotation: `rbac.openportal.dev/managed-by: rbac-add-namespace-access`
  - Label: `rbac.openportal.dev/type: namespace-scoped`

- **OIDC Users**: Authentication via OIDC provider
  - User format: `oidc:<email>`
  - Group format: `oidc:<org_id>`

### Service Account Patterns

- **Backstage**: `backstage-k8s-sa/default` → cluster-admin
- **GitHub Actions**: `gha-app-portal-deploy-k8s-sa/default` → cluster-admin
- **Crossplane Providers**: Dynamic service accounts per revision
- **System Components**: Namespace-specific service accounts

### Bootstrap Roles

Kubernetes creates several bootstrap roles for:
- Node bootstrapping (`system:bootstrappers:kubeadm:default-node-token`)
- Controller manager and scheduler leader election
- Cloud provider integration
- Token management

### Operator-Managed RBAC

Several operators manage their own RBAC:
- **Tigera Operator**: Manages all Calico RBAC
- **Crossplane**: Manages provider-specific RBAC
- **Flux**: Manages GitOps controller RBAC
- **Sveltos**: Manages add-on RBAC (ProjectSveltos ClusterProfiles)

## Security Considerations

### High-Privilege Bindings

The following service accounts have cluster-admin:
1. **backstage-k8s-sa** - Backstage platform access
2. **gha-app-portal-deploy-k8s-sa** - CI/CD deployment
3. **felixadmin** - Administrative account
4. **kustomize-controller, helm-controller** - Flux GitOps

### OIDC Users with Cluster Admin

- fboehm.ext@cloudpunks.de
- mbrueckner@cloudpunks.de
- Group: org_zOuCBHiyF1yG8d1D (full org access)

### Recommendations

1. **Audit cluster-admin bindings**: Consider reducing scope where possible
2. **Use namespace-scoped access**: Prefer RoleBindings over ClusterRoleBindings
3. **Regular RBAC review**: Audit RBAC configurations periodically
4. **Service account rotation**: Implement token rotation for service accounts
5. **OIDC group management**: Use groups for organizational access patterns

## Management Scripts

The cluster uses these scripts for RBAC management:

- **`scripts/rbac-add-admin.sh`**: Add cluster admin access for users
- **`scripts/rbac-add-namespace-access.sh`**: Grant namespace-level access
- **`scripts/rbac-list-users.sh`**: List current RBAC assignments
- **`scripts/rbac-remove-access.sh`**: Remove RBAC assignments

See the respective scripts in the `scripts/` directory for usage details.

---

**Generated**: 2025-10-31
**Cluster Context**: (current kubectl context)
**Total Resources**: 216 RBAC resources (114 ClusterRoles, 62 ClusterRoleBindings, 17 Roles, 23 RoleBindings)
