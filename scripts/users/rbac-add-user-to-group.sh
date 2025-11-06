#!/usr/bin/env bash
#
# Add User to OIDC Group (Documentation Helper)
# Purpose: Provide instructions for adding users to groups in OIDC provider
#
# IMPORTANT: This is a documentation/helper script only!
# Kubernetes does NOT manage group membership - your OIDC provider does.
#
# This script:
# 1. Shows you where to add users (in your OIDC provider)
# 2. Verifies the group has RBAC bindings in Kubernetes
# 3. Provides test commands to verify access
#
# Usage:
#   ./scripts/rbac-add-user-to-group.sh <user-email> <group-name>
#
# Examples:
#   ./scripts/rbac-add-user-to-group.sh john@example.com developers
#   ./scripts/rbac-add-user-to-group.sh jane@example.com platform-admins

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

USER_EMAIL="${1:-}"
GROUP_NAME="${2:-}"

log_info() { echo -e "${BLUE}ℹ${NC} $*"; }
log_success() { echo -e "${GREEN}✓${NC} $*"; }
log_error() { echo -e "${RED}✗${NC} $*"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $*"; }
log_step() { echo -e "${CYAN}▸${NC} $*"; }

# Validate
if [[ -z "$USER_EMAIL" ]] || [[ -z "$GROUP_NAME" ]]; then
  log_error "User email and group name are required"
  echo "Usage: $0 <user-email> <group-name>"
  echo ""
  echo "Examples:"
  echo "  $0 john@example.com developers"
  echo "  $0 jane@example.com platform-admins"
  exit 1
fi

if [[ ! "$USER_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
  log_error "Invalid email format: $USER_EMAIL"
  exit 1
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  Adding User to OIDC Group"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "  User:  ${USER_EMAIL}"
echo "  Group: ${GROUP_NAME}"
echo ""

# Check if group has any bindings in Kubernetes
SAFE_GROUP_NAME=$(echo "$GROUP_NAME" | tr '[:upper:]' '[:lower:]' | tr '_' '-' | sed 's/[^a-z0-9-]/-/g')
GROUP_BINDINGS=$(kubectl get clusterrolebindings -o json | jq -r --arg group "oidc:${GROUP_NAME}" '.items[] | select(.subjects != null) | select(.subjects[].name == $group) | .metadata.name' 2>/dev/null || echo "")
NAMESPACE_BINDINGS=$(kubectl get rolebindings -A -o json | jq -r --arg group "oidc:${GROUP_NAME}" '.items[] | select(.subjects != null) | select(.subjects[].name == $group) | "\(.metadata.namespace)/\(.metadata.name)"' 2>/dev/null || echo "")

if [[ -z "$GROUP_BINDINGS" ]] && [[ -z "$NAMESPACE_BINDINGS" ]]; then
  log_warning "No RBAC bindings found for group '${GROUP_NAME}' in Kubernetes!"
  echo ""
  echo "The group doesn't have any permissions yet. Create bindings first:"
  echo "  ./scripts/rbac-create-group.sh ${GROUP_NAME} cluster-admin"
  echo "  ./scripts/rbac-create-group.sh ${GROUP_NAME} edit my-namespace"
  echo ""
  exit 1
fi

log_success "Found RBAC bindings for group '${GROUP_NAME}'"
echo ""

if [[ -n "$GROUP_BINDINGS" ]]; then
  echo "Cluster-wide bindings:"
  echo "$GROUP_BINDINGS" | while read -r binding; do
    ROLE=$(kubectl get clusterrolebinding "$binding" -o jsonpath='{.roleRef.name}' 2>/dev/null || echo "unknown")
    echo "  • ${binding} → ${ROLE}"
  done
  echo ""
fi

if [[ -n "$NAMESPACE_BINDINGS" ]]; then
  echo "Namespace bindings:"
  echo "$NAMESPACE_BINDINGS" | while read -r binding; do
    NAMESPACE=$(echo "$binding" | cut -d'/' -f1)
    BINDING_NAME=$(echo "$binding" | cut -d'/' -f2)
    ROLE=$(kubectl get rolebinding "$BINDING_NAME" -n "$NAMESPACE" -o jsonpath='{.roleRef.name}' 2>/dev/null || echo "unknown")
    echo "  • ${NAMESPACE}/${BINDING_NAME} → ${ROLE}"
  done
  echo ""
fi

echo "────────────────────────────────────────────────────────────────"
echo ""

log_warning "IMPORTANT: Kubernetes does NOT manage group membership!"
echo ""
echo "Groups are managed by your OIDC provider. You need to add the user"
echo "to the group in your OIDC provider's admin console."
echo ""

log_step "Step-by-step instructions:"
echo ""
echo "1. Identify your OIDC provider:"
echo "   You are using OIDC authentication (prefix: oidc:)"
echo ""
echo "   Common OIDC providers:"
echo "   • Auth0: https://manage.auth0.com"
echo "   • Keycloak: https://your-keycloak-domain/admin"
echo "   • Google Workspace: https://admin.google.com"
echo "   • Azure AD: https://portal.azure.com"
echo "   • Okta: https://your-org.okta.com/admin"
echo ""

echo "2. Log in to your OIDC provider admin console"
echo ""

echo "3. Navigate to Groups/Organizations section"
echo ""

echo "4. Find or create the group '${GROUP_NAME}'"
echo ""

echo "5. Add user '${USER_EMAIL}' to the group"
echo ""

echo "6. The user must log out and log in again to get new group claims"
echo "   (Group membership is included in the OIDC token at login time)"
echo ""

echo "────────────────────────────────────────────────────────────────"
echo ""

log_info "Provider-specific instructions:"
echo ""

echo "Auth0:"
echo "  1. Go to: User Management → Users"
echo "  2. Click on user: ${USER_EMAIL}"
echo "  3. Go to 'Roles' or 'Organizations' tab"
echo "  4. Assign to organization/role: ${GROUP_NAME}"
echo "  5. Ensure group claim is included in ID token (Actions → Flows → Login)"
echo ""

echo "Keycloak:"
echo "  1. Go to: Users → View all users"
echo "  2. Click on user: ${USER_EMAIL}"
echo "  3. Go to 'Groups' tab"
echo "  4. Click 'Join Group' and select: ${GROUP_NAME}"
echo "  5. Ensure group mapper is configured in Client Scopes"
echo ""

echo "Google Workspace:"
echo "  1. Go to: Directory → Groups"
echo "  2. Click on group: ${GROUP_NAME}"
echo "  3. Click 'Add members'"
echo "  4. Add: ${USER_EMAIL}"
echo "  5. Ensure groups claim is configured in OAuth consent"
echo ""

echo "────────────────────────────────────────────────────────────────"
echo ""

log_info "After adding the user to the group:"
echo ""

echo "1. User logs out from Kubernetes/applications"
echo ""

echo "2. User logs in again (gets new token with group membership)"
echo ""

echo "3. Verify group membership:"
echo "   kubectl auth whoami"
echo "   # Should show: oidc:${USER_EMAIL}"
echo "   # Groups should include: oidc:${GROUP_NAME}"
echo ""

echo "4. Test permissions:"
if [[ -n "$GROUP_BINDINGS" ]]; then
  echo "   kubectl auth can-i '*' '*' --all-namespaces  # If cluster-admin"
  echo "   kubectl get nodes  # If cluster-admin"
fi
if [[ -n "$NAMESPACE_BINDINGS" ]]; then
  FIRST_NS=$(echo "$NAMESPACE_BINDINGS" | head -1 | cut -d'/' -f1)
  echo "   kubectl get pods -n ${FIRST_NS}  # If has namespace access"
fi
echo ""

echo "5. Debug if not working:"
echo "   # Check OIDC token claims (from your OIDC provider's token inspector)"
echo "   # Verify 'groups' claim includes: ${GROUP_NAME}"
echo "   # Check Kubernetes API server OIDC configuration:"
echo "   kubectl get pod -n kube-system -l component=kube-apiserver -o yaml | grep oidc"
echo ""

log_success "Instructions provided!"
echo ""
log_info "Remember: Group membership is managed in your OIDC provider, not in Kubernetes."
echo ""
