#!/usr/bin/env bash
#
# Create OIDC Group with RBAC Permissions
# Purpose: Create a ClusterRoleBinding for an OIDC group
#
# IMPORTANT: Groups are NOT created in Kubernetes!
# Groups must be managed in your OIDC provider (Auth0, Keycloak, etc.)
# This script creates the RBAC binding that grants permissions to the group.
#
# Usage:
#   ./scripts/rbac-create-group.sh <group-name> [role] [namespace]
#
# Examples:
#   ./scripts/rbac-create-group.sh developers
#   ./scripts/rbac-create-group.sh developers edit
#   ./scripts/rbac-create-group.sh backend-team edit backend-ns
#   ./scripts/rbac-create-group.sh platform-admins cluster-admin
#
# Roles:
#   cluster-admin - Full cluster access (default, no namespace)
#   admin         - Full namespace control including RBAC (requires namespace)
#   edit          - Read/write access to namespace (requires namespace)
#   view          - Read-only access to namespace (requires namespace)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

GROUP_NAME="${1:-}"
ROLE="${2:-cluster-admin}"
NAMESPACE="${3:-}"

log_info() { echo -e "${BLUE}ℹ${NC} $*"; }
log_success() { echo -e "${GREEN}✓${NC} $*"; }
log_error() { echo -e "${RED}✗${NC} $*"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $*"; }

# Validate
if [[ -z "$GROUP_NAME" ]]; then
  log_error "Group name is required"
  echo "Usage: $0 <group-name> [role] [namespace]"
  echo ""
  echo "Examples:"
  echo "  $0 developers                    # cluster-admin access"
  echo "  $0 developers edit backend-ns    # edit access in backend-ns"
  echo "  $0 admins cluster-admin          # explicit cluster-admin"
  exit 1
fi

# Validate role
if [[ ! "$ROLE" =~ ^(cluster-admin|admin|edit|view)$ ]]; then
  log_error "Invalid role: $ROLE"
  echo "Valid roles: cluster-admin, admin, edit, view"
  exit 1
fi

# Validate namespace requirement
if [[ "$ROLE" != "cluster-admin" ]] && [[ -z "$NAMESPACE" ]]; then
  log_error "Namespace is required for role: $ROLE"
  echo "Usage: $0 <group-name> $ROLE <namespace>"
  exit 1
fi

if [[ "$ROLE" == "cluster-admin" ]] && [[ -n "$NAMESPACE" ]]; then
  log_warning "Namespace ignored for cluster-admin role"
  NAMESPACE=""
fi

# Validate namespace format
if [[ -n "$NAMESPACE" ]] && [[ ! "$NAMESPACE" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]]; then
  log_error "Invalid namespace format: $NAMESPACE"
  exit 1
fi

# Generate binding name
SAFE_GROUP_NAME=$(echo "$GROUP_NAME" | tr '[:upper:]' '[:lower:]' | tr '_' '-' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')
if [[ -n "$NAMESPACE" ]]; then
  BINDING_NAME="group-${SAFE_GROUP_NAME}-${ROLE}-${NAMESPACE}"
else
  BINDING_NAME="group-${SAFE_GROUP_NAME}-${ROLE}"
fi

# Truncate if too long (Kubernetes limit is 253 chars for binding names)
BINDING_NAME="${BINDING_NAME:0:253}"

# Select template
if [[ -n "$NAMESPACE" ]]; then
  TEMPLATE_FILE="${SCRIPT_DIR}/../manifests/users/rbac-group-namespace.template.yaml"
else
  TEMPLATE_FILE="${SCRIPT_DIR}/../manifests/users/rbac-group.template.yaml"
fi

if [[ ! -f "$TEMPLATE_FILE" ]]; then
  log_error "Template file not found: $TEMPLATE_FILE"
  exit 1
fi

echo ""
log_warning "IMPORTANT: Groups must be managed in your OIDC provider!"
echo "  This script only creates the Kubernetes RBAC binding."
echo "  Ensure the group '${GROUP_NAME}' exists in your OIDC provider (Auth0, Keycloak, etc.)"
echo ""

# Check if binding exists
if [[ -n "$NAMESPACE" ]]; then
  if kubectl get rolebinding "$BINDING_NAME" -n "$NAMESPACE" &> /dev/null 2>&1; then
    log_info "RoleBinding '${BINDING_NAME}' already exists in namespace '${NAMESPACE}'"
    exit 0
  fi
else
  if kubectl get clusterrolebinding "$BINDING_NAME" &> /dev/null; then
    log_info "ClusterRoleBinding '${BINDING_NAME}' already exists"
    exit 0
  fi
fi

# Generate description
if [[ -n "$NAMESPACE" ]]; then
  DESCRIPTION="${ROLE} access for OIDC group '${GROUP_NAME}' in namespace '${NAMESPACE}'"
else
  DESCRIPTION="${ROLE} access for OIDC group '${GROUP_NAME}'"
fi

# Generate manifest using envsubst
export GROUP_NAME BINDING_NAME ROLE NAMESPACE DESCRIPTION
export CREATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

envsubst < "$TEMPLATE_FILE" | kubectl apply -f -

if [[ -n "$NAMESPACE" ]]; then
  log_success "Namespace '${NAMESPACE}' ready"
  log_success "RoleBinding '${BINDING_NAME}' created for group '${GROUP_NAME}' with role '${ROLE}'"
else
  log_success "ClusterRoleBinding '${BINDING_NAME}' created for group '${GROUP_NAME}' with role '${ROLE}'"
fi

echo ""
log_info "Group details:"
echo "  OIDC Group: ${GROUP_NAME}"
echo "  Kubernetes Subject: oidc:${GROUP_NAME}"
echo "  Role: ${ROLE}"
if [[ -n "$NAMESPACE" ]]; then
  echo "  Scope: Namespace '${NAMESPACE}'"
else
  echo "  Scope: Cluster-wide"
fi
echo ""

log_info "To add users to this group:"
echo "  1. Log in to your OIDC provider admin console"
echo "  2. Add users to the '${GROUP_NAME}' group"
echo "  3. Users will automatically get these permissions on next login"
echo ""

log_info "To verify group membership from Kubernetes:"
echo "  # User authenticates via OIDC, then check:"
echo "  kubectl auth whoami"
echo "  kubectl auth can-i --list --as=oidc:user@example.com"
echo ""

log_info "To remove this group's access:"
if [[ -n "$NAMESPACE" ]]; then
  echo "  kubectl delete rolebinding ${BINDING_NAME} -n ${NAMESPACE}"
else
  echo "  kubectl delete clusterrolebinding ${BINDING_NAME}"
fi
echo ""
