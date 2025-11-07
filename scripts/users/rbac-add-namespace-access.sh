#!/usr/bin/env bash
#
# Add Namespace-Scoped Access for User
# Purpose: Grant a user permissions to a specific namespace
#
# Usage:
#   ./scripts/rbac-add-namespace-access.sh <user-email> <namespace> [role]
#
# Examples:
#   ./scripts/rbac-add-namespace-access.sh user@example.com myapp
#   ./scripts/rbac-add-namespace-access.sh john@example.com dev view
#   ./scripts/rbac-add-namespace-access.sh jane@example.com prod admin
#
# Roles:
#   view  - Read-only access (default if not specified: edit)
#   edit  - Read/write access to most resources
#   admin - Full namespace control including RBAC

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="${SCRIPT_DIR}/../manifests/users/rbac-namespace-access.template.yaml"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

USER_EMAIL="${1:-}"
NAMESPACE="${2:-}"
ROLE="${3:-edit}"

log_info() { echo -e "${BLUE}ℹ${NC} $*"; }
log_success() { echo -e "${GREEN}✓${NC} $*"; }
log_error() { echo -e "${RED}✗${NC} $*"; }

# Validate
if [[ -z "$USER_EMAIL" ]] || [[ -z "$NAMESPACE" ]]; then
  log_error "User email and namespace are required"
  echo "Usage: $0 <user-email> <namespace> [role]"
  exit 1
fi

if [[ ! "$USER_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
  log_error "Invalid email format: $USER_EMAIL"
  exit 1
fi

if [[ ! "$NAMESPACE" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]]; then
  log_error "Invalid namespace format: $NAMESPACE"
  exit 1
fi

if [[ ! "$ROLE" =~ ^(view|edit|admin)$ ]]; then
  log_error "Invalid role: $ROLE (must be: view, edit, or admin)"
  exit 1
fi

if [[ ! -f "$TEMPLATE_FILE" ]]; then
  log_error "Template file not found: $TEMPLATE_FILE"
  exit 1
fi

# Generate binding name
# Convert full email to Kubernetes-compatible label (replace @ with -at-, lowercase, max 63 chars)
USERNAME=$(echo "$USER_EMAIL" | tr '[:upper:]' '[:lower:]')  # Convert to lowercase
USERNAME="${USERNAME/@/-at-}"        # Replace @ with -at-
USERNAME="${USERNAME//./-}"          # Replace dots with dashes
USERNAME="${USERNAME:0:50}"          # Truncate to leave room for role suffix
BINDING_NAME="${USERNAME}-${ROLE}-binding"

# Check if exists
if kubectl get rolebinding "$BINDING_NAME" -n "$NAMESPACE" &> /dev/null 2>&1; then
  log_info "RoleBinding '${BINDING_NAME}' already exists in namespace '${NAMESPACE}'"
  exit 0
fi

# Generate manifest using envsubst (creates namespace if not exists)
export USER_EMAIL NAMESPACE ROLE BINDING_NAME USERNAME
export CREATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

envsubst < "$TEMPLATE_FILE" | kubectl apply -f -
log_success "Namespace '${NAMESPACE}' ready"
log_success "RoleBinding '${BINDING_NAME}' created for ${USER_EMAIL} with role '${ROLE}'"
echo ""
log_info "To remove access:"
echo "  kubectl delete rolebinding ${BINDING_NAME} -n ${NAMESPACE}"
