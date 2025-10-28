#!/usr/bin/env bash
#
# Add Cluster Admin User
# Purpose: Grant cluster-admin permissions to a specific OIDC user
#
# Usage:
#   ./scripts/rbac-add-admin.sh <user-email>
#
# Examples:
#   ./scripts/rbac-add-admin.sh john.doe@example.com
#   ./scripts/rbac-add-admin.sh jane@example.com

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="${SCRIPT_DIR}/manifests-setup-cluster/rbac-admin.template.yaml"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

USER_EMAIL="${1:-}"

log_info() { echo -e "${BLUE}ℹ${NC} $*"; }
log_success() { echo -e "${GREEN}✓${NC} $*"; }
log_error() { echo -e "${RED}✗${NC} $*"; }

# Validate
if [[ -z "$USER_EMAIL" ]]; then
  log_error "User email is required"
  echo "Usage: $0 <user-email>"
  exit 1
fi

if [[ ! "$USER_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
  log_error "Invalid email format: $USER_EMAIL"
  exit 1
fi

if [[ ! -f "$TEMPLATE_FILE" ]]; then
  log_error "Template file not found: $TEMPLATE_FILE"
  exit 1
fi

# Generate binding name
username="${USER_EMAIL%%@*}"
username="${username//./-}"
BINDING_NAME="admin-${username}"

# Check if exists
if kubectl get clusterrolebinding "$BINDING_NAME" &> /dev/null; then
  log_info "ClusterRoleBinding '${BINDING_NAME}' already exists"
  exit 0
fi

# Generate manifest using envsubst
export USER_EMAIL BINDING_NAME
export CREATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

envsubst < "$TEMPLATE_FILE" | kubectl apply -f -
log_success "ClusterRoleBinding '${BINDING_NAME}' created for ${USER_EMAIL}"
echo ""
log_info "To remove access:"
echo "  kubectl delete clusterrolebinding ${BINDING_NAME}"
