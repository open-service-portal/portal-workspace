# Kubernetes Identity and Authorization Flow

This document provides visual representations of how users, groups, and permissions work in Kubernetes.

## The Complete Picture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    OIDC Provider (Auth0/Keycloak)                   │
│                                                                     │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐         │
│  │ User: john    │  │ User: jane    │  │ User: admin   │         │
│  │ @example.com  │  │ @example.com  │  │ @example.com  │         │
│  └───────┬───────┘  └───────┬───────┘  └───────┬───────┘         │
│          │                   │                   │                  │
│          │ Member of         │ Member of         │ Member of        │
│          ▼                   ▼                   ▼                  │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐          │
│  │   Group:     │   │   Group:     │   │   Group:     │          │
│  │  developers  │   │  developers  │   │   admins     │          │
│  └──────────────┘   └──────────────┘   └──────────────┘          │
│                                                                     │
│  This mapping (User → Group) lives HERE, not in Kubernetes!       │
└─────────────────────────────────┬───────────────────────────────────┘
                                  │
                                  │ Issues token with groups
                                  ▼
                    ┌──────────────────────────┐
                    │     OIDC ID Token        │
                    │ ──────────────────────── │
                    │ user: john@example.com   │
                    │ groups: [developers]     │
                    └────────────┬─────────────┘
                                 │
                                 │ kubectl uses token
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Kubernetes API Server                            │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │ 1. Authentication: Extract identity from token               │  │
│  │    → Username: oidc:john@example.com                        │  │
│  │    → Groups: [oidc:developers]                              │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                              ▼                                      │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │ 2. Authorization: Check RBAC rules                          │  │
│  │                                                             │  │
│  │    ClusterRoleBinding: developers-access                   │  │
│  │    subjects:                                                │  │
│  │      - kind: Group                                          │  │
│  │        name: oidc:developers ✓ MATCH!                      │  │
│  │    roleRef:                                                 │  │
│  │        name: edit                                           │  │
│  │                                                             │  │
│  │    → Grant "edit" permissions                              │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                              ▼                                      │
│                       ┌──────────┐                                 │
│                       │  ALLOW   │                                 │
│                       └──────────┘                                 │
└─────────────────────────────────────────────────────────────────────┘
```

## Authentication vs Authorization

```
┌──────────────────────────────────────────────────────────────┐
│  AUTHENTICATION (Who are you?)                               │
│  ─────────────────────────────────────────────────────────  │
│                                                              │
│  Handled by: External Identity Provider                     │
│              (OIDC, Certificates, etc.)                     │
│                                                              │
│  Kubernetes receives:                                        │
│  • Username: "oidc:john@example.com"                        │
│  • Groups: ["oidc:developers", "oidc:team-backend"]        │
│                                                              │
│  Kubernetes does NOT store or manage this information!      │
│  It just extracts it from the authentication token/cert.    │
│                                                              │
└──────────────────────────────────────────────────────────────┘
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  AUTHORIZATION (What can you do?)                            │
│  ─────────────────────────────────────────────────────────  │
│                                                              │
│  Handled by: Kubernetes RBAC                                │
│                                                              │
│  Kubernetes checks:                                          │
│  • RoleBindings/ClusterRoleBindings                         │
│  • Does username or any group have a binding?               │
│  • What role does that binding reference?                   │
│  • What permissions does that role grant?                   │
│                                                              │
│  Kubernetes DOES store and manage this information!         │
│  These are actual Kubernetes resources.                     │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## What's Stored Where?

```
┌────────────────────────────────────────────────────────────────────┐
│                     OIDC Provider Storage                          │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  Users:                                                            │
│  ├─ john@example.com                                              │
│  │  ├─ Password: (hashed)                                         │
│  │  ├─ Email: john@example.com                                    │
│  │  └─ Groups: [developers, team-backend]        ← USER-TO-GROUP │
│  │                                                   MAPPING HERE  │
│  ├─ jane@example.com                                              │
│  │  ├─ Password: (hashed)                                         │
│  │  └─ Groups: [developers, team-frontend]       ← USER-TO-GROUP │
│  │                                                   MAPPING HERE  │
│  └─ admin@example.com                                             │
│     └─ Groups: [platform-admins]                  ← USER-TO-GROUP │
│                                                       MAPPING HERE │
│  Groups:                                                           │
│  ├─ developers                                                     │
│  │  └─ Members: [john, jane]                                      │
│  ├─ team-backend                                                   │
│  │  └─ Members: [john]                                            │
│  └─ platform-admins                                                │
│     └─ Members: [admin]                                            │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────┐
│                    Kubernetes Storage (etcd)                       │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  NO Users stored ✗                                                │
│  NO Groups stored ✗                                               │
│  NO User-to-Group mapping ✗                                       │
│                                                                    │
│  ClusterRoleBindings: (Group → Role mapping)                      │
│  ├─ developers-access                                             │
│  │  ├─ Subject: Group "oidc:developers"   ← JUST A STRING!       │
│  │  └─ RoleRef: ClusterRole "edit"        ← PERMISSIONS HERE     │
│  ├─ backend-team-access                                           │
│  │  ├─ Subject: Group "oidc:team-backend"                        │
│  │  └─ RoleRef: ClusterRole "edit"                               │
│  └─ admins-access                                                 │
│     ├─ Subject: Group "oidc:platform-admins"                      │
│     └─ RoleRef: ClusterRole "cluster-admin"                       │
│                                                                    │
│  ClusterRoles: (Permissions definition)                           │
│  ├─ edit                                                          │
│  │  └─ Rules: [create/update/delete pods, deployments, etc.]     │
│  └─ cluster-admin                                                 │
│     └─ Rules: [* all permissions *]                               │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

## Timeline: Adding a User to a Group

```
Time →

T0: Initial State
─────────────────────────────────────────────────────────────────
OIDC Provider:
  jane@example.com → groups: [developers]

Kubernetes:
  ClusterRoleBinding "backend-team-access":
    Subject: Group "oidc:team-backend"
    Role: edit

Jane's Token:
  groups: [developers]

Jane's Access:
  ✓ Can use "edit" role (via developers group)
  ✗ Cannot use "edit" role (not in team-backend group)


T1: Admin adds Jane to team-backend in OIDC Provider
─────────────────────────────────────────────────────────────────
OIDC Provider:
  jane@example.com → groups: [developers, team-backend]  ← CHANGED

Kubernetes:
  ClusterRoleBinding "backend-team-access":
    Subject: Group "oidc:team-backend"
  (No change in Kubernetes - it doesn't know yet!)

Jane's Token:
  groups: [developers]  ← OLD TOKEN STILL VALID

Jane's Access:
  ✓ Can use "edit" role (via developers group)
  ✗ Still cannot use team-backend access (old token doesn't have it)


T2: Jane logs out and logs back in (gets new token)
─────────────────────────────────────────────────────────────────
OIDC Provider:
  jane@example.com → groups: [developers, team-backend]

Kubernetes:
  ClusterRoleBinding "backend-team-access":
    Subject: Group "oidc:team-backend"

Jane's Token:
  groups: [developers, team-backend]  ← NEW TOKEN WITH NEW GROUP

Jane's Access:
  ✓ Can use "edit" role (via developers group)
  ✓ Can now use "edit" role (via team-backend group)
```

## The "String Reference" Problem

```
┌────────────────────────────────────────────────────────┐
│  ClusterRoleBinding in Kubernetes                     │
│  ───────────────────────────────────────────────────  │
│                                                        │
│  subjects:                                             │
│  - kind: Group                                         │
│    name: "oidc:developers"      ← This is just text!  │
│    apiGroup: rbac.authorization.k8s.io                │
│                                                        │
│  There is NO corresponding "Group" resource!          │
│  Kubernetes does NOT validate that this group exists! │
│  It's just a string that will be matched against      │
│  groups in authentication tokens.                     │
│                                                        │
└────────────────────────────────────────────────────────┘

This means:

❌ You can create a binding to a group that doesn't exist:
   kubectl create clusterrolebinding test \
     --clusterrole=edit \
     --group=oidc:nonexistent-group
   # This succeeds! No validation!

✓ The binding only works when someone authenticates
  with that group in their token:

  If token says: groups: ["nonexistent-group"]
  → Kubernetes will match it and grant permissions

✗ If no users have that group in their token:
  → The binding does nothing (but exists)
```

## Comparison with Traditional Systems

```
┌──────────────────────────────────────────────────────────┐
│         Traditional OS (Linux/Windows)                   │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  /etc/passwd       ← Users stored in OS                 │
│  /etc/group        ← Groups stored in OS                │
│  /etc/group:       ← User-to-group mapping in OS        │
│    developers:x:1001:john,jane                          │
│                                                          │
│  File permissions: ← Authorization rules in filesystem  │
│    -rw-rw-r-- 1 root developers /app/config.yml        │
│                                                          │
│  Everything in ONE system!                              │
│                                                          │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│                  Kubernetes                              │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  OIDC Provider     ← Users stored externally            │
│  OIDC Provider     ← Groups stored externally           │
│  OIDC Provider     ← User-to-group mapping external     │
│    developers: [john, jane]                             │
│                                                          │
│  RoleBindings:     ← Authorization rules in k8s         │
│    Group: developers → Role: edit                       │
│                                                          │
│  Split across TWO systems!                              │
│  Bridge: Authentication tokens carry group info         │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

## Common Scenarios

### Scenario 1: User Can't Access Despite Being in Group (OIDC)

```
Problem: Jane is in "developers" group but can't access pods

Diagnosis:
┌─────────────────────────────────────────┐
│ 1. Check OIDC provider                  │
│    jane@example.com in "developers"? ✓  │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ 2. Check Jane's current token           │
│    kubectl auth whoami                   │
│    Shows: oidc:developers? ✗            │
│                                          │
│    → Jane has OLD token!                │
│    → Solution: Log out and back in      │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ 3. Check Kubernetes RBAC                │
│    Group "oidc:developers" has binding? │
│    kubectl get clusterrolebinding | grep dev │
│    → developers-access exists ✓         │
└─────────────────────────────────────────┘
```

### Scenario 2: Created Group Binding But No Users Have Access

```
Problem: Created binding for group "backend-team" but nobody can access

Steps to check:

1. Verify Kubernetes binding exists:
   ┌──────────────────────────────────────────┐
   │ kubectl get clusterrolebinding           │
   │   backend-team-access                    │
   │ subjects:                                │
   │   - Group: oidc:backend-team             │
   │ roleRef: edit                            │
   └──────────────────────────────────────────┘
   ✓ Binding exists in Kubernetes

2. Check OIDC provider:
   ┌──────────────────────────────────────────┐
   │ Log in to Auth0/Keycloak                 │
   │ Search for group: "backend-team"         │
   │                                          │
   │ Found? ✗ NO!                             │
   │                                          │
   │ → Group doesn't exist in OIDC provider! │
   │ → Create the group there first          │
   └──────────────────────────────────────────┘

3. After creating group in OIDC and adding users:
   ┌──────────────────────────────────────────┐
   │ Users log out and back in                │
   │ New tokens include "backend-team" group  │
   │ Kubernetes matches group → grants access │
   └──────────────────────────────────────────┘
   ✓ Now it works!
```

### Scenario 3: Removed User from Group But They Still Have Access

```
Problem: Removed John from "developers" group but he can still access

Timeline:
┌─────────────────────────────────────────────────────┐
│ T0: Admin removes John from developers group        │
│     in OIDC provider                                │
│                                                     │
│     OIDC: john@example.com → groups: []             │
│     John's token (still valid): groups: [developers]│
│                                                     │
│     → John STILL has access! (old token)           │
└─────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────┐
│ T1: Token expires or John logs out                  │
│                                                     │
│     John gets new token: groups: []                 │
│     Kubernetes checks: "developers" group in token? │
│     → NO                                            │
│     → Access denied ✓                               │
└─────────────────────────────────────────────────────┘

Solutions:
1. Wait for token to expire (typically 1 hour)
2. Force John to log out/in (gets new token immediately)
3. Use short token lifetimes (e.g., 15 minutes) for faster revocation
4. Implement token revocation in OIDC provider (if supported)
```

## Key Differences from Service Accounts

Service Accounts are special - they're the ONLY case where Kubernetes manages group membership:

```
┌────────────────────────────────────────────────────┐
│  Service Account (Kubernetes-managed)              │
├────────────────────────────────────────────────────┤
│                                                    │
│  kubectl create sa myapp -n mynamespace            │
│                                                    │
│  Kubernetes automatically assigns groups:          │
│  • system:serviceaccounts (all SAs)               │
│  • system:serviceaccounts:mynamespace (NS SAs)    │
│  • system:authenticated (all authenticated)        │
│                                                    │
│  This is hardcoded - you cannot change it!        │
│                                                    │
└────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────┐
│  OIDC User (Externally-managed)                    │
├────────────────────────────────────────────────────┤
│                                                    │
│  User already exists in OIDC provider              │
│                                                    │
│  OIDC provider assigns groups based on:           │
│  • Directory groups (LDAP/AD)                     │
│  • Manual assignment (Auth0/Keycloak)             │
│  • SSO claims (SAML)                              │
│  • Custom logic (roles, attributes, etc.)         │
│                                                    │
│  Kubernetes receives groups from token             │
│  Kubernetes does NOT manage group membership!     │
│                                                    │
└────────────────────────────────────────────────────┘
```

## Summary Diagram

```
    ┌─────────────┐
    │ Your OIDC   │      "John is in developers group"
    │  Provider   │ ────────────────────────────────────────────┐
    │ (Auth0 etc) │                                             │
    └─────────────┘                                             │
                                                               │
                                                               │
    ┌─────────────┐                                             │
    │ Kubernetes  │      "Developers group gets edit perms"   │
    │    RBAC     │ ────────────────────────────────────────┐ │
    └─────────────┘                                         │ │
                                                            │ │
                                                            │ │
    ┌─────────────────────────────────────────────────────┐ │ │
    │  When John makes a kubectl request:                 │ │ │
    │                                                     │ │ │
    │  1. John authenticates → gets token with groups    │◄┘ │
    │     Token says: groups = [developers]              │   │
    │                                                     │   │
    │  2. Kubernetes checks RBAC → finds binding         │◄──┘
    │     Binding says: developers → edit                 │
    │                                                     │
    │  3. Grant edit permissions ✓                       │
    └─────────────────────────────────────────────────────┘

    The two pieces of information come from DIFFERENT sources
    and are joined together at authentication time!
```

---

**The Bottom Line**: Kubernetes is NOT an identity management system. It's an authorization system that trusts an external identity provider to tell it who you are and what groups you're in.

---

**Generated**: 2025-10-31
