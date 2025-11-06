#!/usr/bin/env bash
#
# Create User in Group Namespace
# Purpose: Create ServiceAccount in a "group namespace" for automatic group membership
#
# ServiceAccounts automatically belong to: system:serviceaccounts:<namespace>
# By creating SAs in a shared namespace, they all belong to the same "group"
#
# Usage:
#   ./scripts/create-user-with-group.sh <username> <group-namespace> [permission]
#
# Permission applies to the group namespace by default. Use 'none' for custom bindings.
#
# Examples:
#   ./scripts/create-user-with-group.sh alice developers
#   ./scripts/create-user-with-group.sh bob developers edit
#   ./scripts/create-user-with-group.sh charlie platform-team cluster-admin
#   ./scripts/create-user-with-group.sh dave qa-team none

set -euo pipefail

USERNAME="${1:-}"
GROUP_NAMESPACE="${2:-}"
PERMISSION="${3:-none}"
KUBECONFIG_DIR="${HOME}/.kube/test-users"
CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
CLUSTER_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ${NC} $*"; }
log_success() { echo -e "${GREEN}✓${NC} $*"; }
log_error() { echo -e "${RED}✗${NC} $*"; }
log_step() { echo -e "${YELLOW}▸${NC} $*"; }
log_header() { echo -e "${CYAN}$*${NC}"; }

# Validate
if [[ -z "$USERNAME" ]] || [[ -z "$GROUP_NAMESPACE" ]]; then
  log_error "Username and group namespace are required"
  echo "Usage: $0 <username> <group-namespace> [permission]"
  echo ""
  echo "Examples:"
  echo "  $0 alice developers              # Create alice in developers group"
  echo "  $0 bob developers edit           # Create bob with edit access in developers"
  echo "  $0 charlie platform-team cluster-admin  # Create charlie as cluster admin"
  exit 1
fi

if [[ ! "$PERMISSION" =~ ^(none|view|edit|admin|cluster-admin)$ ]]; then
  log_error "Invalid permission: $PERMISSION"
  echo "Valid permissions: none, view, edit, admin, cluster-admin"
  exit 1
fi

echo ""
log_header "═══════════════════════════════════════════════════════════"
log_header "  Creating User with Group Membership (via namespace)"
log_header "═══════════════════════════════════════════════════════════"
echo ""
echo "  Username: ${USERNAME}"
echo "  Group: ${GROUP_NAMESPACE}"
echo "  Permission: ${PERMISSION}"
echo ""

mkdir -p "${KUBECONFIG_DIR}"

# Step 1: Ensure namespace exists
log_step "Ensuring group namespace exists..."
kubectl create namespace "${GROUP_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1
log_success "Namespace '${GROUP_NAMESPACE}' ready"

# Step 2: Create ServiceAccount
log_step "Creating ServiceAccount..."
kubectl create serviceaccount "${USERNAME}" -n "${GROUP_NAMESPACE}" 2>/dev/null || {
  log_info "ServiceAccount '${USERNAME}' already exists in namespace '${GROUP_NAMESPACE}'"
}
log_success "ServiceAccount ready"

# Step 3: Create Secret for token
log_step "Creating token Secret..."
cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: v1
kind: Secret
metadata:
  name: ${USERNAME}-token
  namespace: ${GROUP_NAMESPACE}
  annotations:
    kubernetes.io/service-account.name: ${USERNAME}
    openportal.dev/user: "${USERNAME}"
    openportal.dev/group: "${GROUP_NAMESPACE}"
type: kubernetes.io/service-account-token
EOF
log_success "Token Secret created"

# Step 4: Wait for token to be populated
log_step "Waiting for token..."
sleep 2
TOKEN=$(kubectl get secret "${USERNAME}-token" -n "${GROUP_NAMESPACE}" -o jsonpath='{.data.token}' | base64 -d)

if [[ -z "$TOKEN" ]]; then
  log_error "Token not found"
  exit 1
fi
log_success "Token retrieved"

# Step 5: Get cluster CA
log_step "Extracting cluster CA..."
kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d > "${KUBECONFIG_DIR}/ca.crt"
log_success "CA certificate saved"

# Step 6: Grant permissions
if [[ "$PERMISSION" != "none" ]]; then
  log_step "Granting permissions..."

  case "$PERMISSION" in
    cluster-admin)
      kubectl create clusterrolebinding "${USERNAME}-admin" \
        --clusterrole=cluster-admin \
        --serviceaccount="${GROUP_NAMESPACE}:${USERNAME}" \
        2>/dev/null || log_info "ClusterRoleBinding already exists"
      log_success "Cluster-admin permissions granted"
      ;;
    view|edit|admin)
      kubectl create rolebinding "${USERNAME}-${PERMISSION}" \
        --clusterrole="${PERMISSION}" \
        --serviceaccount="${GROUP_NAMESPACE}:${USERNAME}" \
        -n "${GROUP_NAMESPACE}" \
        2>/dev/null || log_info "RoleBinding already exists"
      log_success "Namespace '${GROUP_NAMESPACE}' permissions granted (role: ${PERMISSION})"
      ;;
  esac
fi

# Step 7: Create kubeconfig
log_step "Creating kubeconfig..."
KUBECONFIG_FILE="${KUBECONFIG_DIR}/${USERNAME}-${GROUP_NAMESPACE}-kubeconfig.yaml"

cat > "${KUBECONFIG_FILE}" <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: ${KUBECONFIG_DIR}/ca.crt
    server: ${CLUSTER_SERVER}
  name: ${CLUSTER_NAME}
contexts:
- context:
    cluster: ${CLUSTER_NAME}
    user: ${USERNAME}
    namespace: ${GROUP_NAMESPACE}
  name: ${USERNAME}@${CLUSTER_NAME}
current-context: ${USERNAME}@${CLUSTER_NAME}
users:
- name: ${USERNAME}
  user:
    token: ${TOKEN}
EOF

log_success "Kubeconfig created"

echo ""
log_header "═══════════════════════════════════════════════════════════"
log_success "User created successfully!"
log_header "═══════════════════════════════════════════════════════════"
echo ""

log_info "User details:"
echo "  Username: system:serviceaccount:${GROUP_NAMESPACE}:${USERNAME}"
echo "  Type: ServiceAccount token"
echo "  Group Namespace: ${GROUP_NAMESPACE}"
echo "  Permission: ${PERMISSION}"
if [[ "$PERMISSION" == "cluster-admin" ]]; then
  echo "  Scope: Cluster-wide"
elif [[ "$PERMISSION" != "none" ]]; then
  echo "  Scope: Namespace '${GROUP_NAMESPACE}'"
else
  echo "  Scope: None (requires group-based bindings)"
fi
echo "  Kubeconfig: ${KUBECONFIG_FILE}"
echo ""

log_info "Automatic group membership:"
echo "  This user automatically belongs to Kubernetes group:"
echo "    system:serviceaccounts:${GROUP_NAMESPACE}"
echo ""
echo "  All users in namespace '${GROUP_NAMESPACE}' share this group!"
echo ""

log_info "Grant permissions to the entire group:"
echo ""
echo "  # Allow group to edit resources in their namespace"
echo "  kubectl create rolebinding ${GROUP_NAMESPACE}-group-edit \\"
echo "    --clusterrole=edit \\"
echo "    --group=system:serviceaccounts:${GROUP_NAMESPACE} \\"
echo "    -n ${GROUP_NAMESPACE}"
echo ""
echo "  # Allow group to view resources in staging namespace"
echo "  kubectl create rolebinding ${GROUP_NAMESPACE}-view-staging \\"
echo "    --clusterrole=view \\"
echo "    --group=system:serviceaccounts:${GROUP_NAMESPACE} \\"
echo "    -n staging"
echo ""
echo "  # Allow group cluster-admin (careful!)"
echo "  kubectl create clusterrolebinding ${GROUP_NAMESPACE}-admin \\"
echo "    --clusterrole=cluster-admin \\"
echo "    --group=system:serviceaccounts:${GROUP_NAMESPACE}"
echo ""

log_info "Test identity and group membership:"
echo "  export KUBECONFIG=${KUBECONFIG_FILE}"
echo "  kubectl auth whoami"
echo "  # Should show groups:"
echo "  #   - system:serviceaccounts"
echo "  #   - system:serviceaccounts:${GROUP_NAMESPACE}"
echo "  #   - system:authenticated"
echo ""

log_info "Test permissions:"
if [[ "$PERMISSION" != "none" ]]; then
  echo "  kubectl get pods -n ${GROUP_NAMESPACE}"
else
  echo "  # No individual permissions granted"
  echo "  # Create group binding first, then:"
  echo "  kubectl get pods -n ${GROUP_NAMESPACE}"
fi
echo ""

log_info "Switch back to admin:"
echo "  unset KUBECONFIG"
echo ""

log_info "To add more users to this group:"
echo "  $0 another-user ${GROUP_NAMESPACE} ${PERMISSION}"
echo ""

log_info "To remove this user:"
echo "  kubectl delete serviceaccount ${USERNAME} -n ${GROUP_NAMESPACE}"
echo "  kubectl delete secret ${USERNAME}-token -n ${GROUP_NAMESPACE}"
if [[ "$PERMISSION" == "cluster-admin" ]]; then
  echo "  kubectl delete clusterrolebinding ${USERNAME}-admin"
elif [[ "$PERMISSION" != "none" ]]; then
  echo "  kubectl delete rolebinding ${USERNAME}-${PERMISSION} -n ${GROUP_NAMESPACE}"
fi
echo "  rm ${KUBECONFIG_FILE}"
echo ""
