#!/usr/bin/env bash
#
# Create User with Token Authentication
# Purpose: Create a test user with configurable permissions for RBAC testing
#
# Usage:
#   ./scripts/create-user.sh <username> [permission] [namespace]
#
# Permissions:
#   none          - No permissions (default)
#   view          - Read-only access to namespace
#   edit          - Read/write access to namespace (cannot manage RBAC)
#   admin         - Full namespace control (including RBAC)
#   cluster-admin - Full cluster access
#
# Examples:
#   ./scripts/create-user.sh testuser                    # Zero access
#   ./scripts/create-user.sh testuser none               # Zero access (explicit)
#   ./scripts/create-user.sh testuser cluster-admin      # Full cluster access
#   ./scripts/create-user.sh testuser edit myapp         # Edit access to myapp namespace
#   ./scripts/create-user.sh testuser view prod          # Read-only access to prod namespace

set -euo pipefail

USERNAME="${1:-}"
PERMISSION="${2:-none}"
NAMESPACE="${3:-default}"
KUBECONFIG_DIR="${HOME}/.kube/test-users"
CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
CLUSTER_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ${NC} $*"; }
log_success() { echo -e "${GREEN}✓${NC} $*"; }
log_error() { echo -e "${RED}✗${NC} $*"; }
log_step() { echo -e "${YELLOW}▸${NC} $*"; }

# Validate
if [[ -z "$USERNAME" ]]; then
  log_error "Username is required"
  echo "Usage: $0 <username> [permission] [namespace]"
  echo "Permissions: none, view, edit, admin, cluster-admin"
  exit 1
fi

if [[ ! "$PERMISSION" =~ ^(none|view|edit|admin|cluster-admin)$ ]]; then
  log_error "Invalid permission: $PERMISSION"
  echo "Valid permissions: none, view, edit, admin, cluster-admin"
  exit 1
fi

echo "Creating user: ${USERNAME}"
echo ""

# Create directory for kubeconfigs
mkdir -p "${KUBECONFIG_DIR}"

# Step 1: Create ServiceAccount
log_step "Creating ServiceAccount..."
kubectl create serviceaccount "${USERNAME}" -n "${NAMESPACE}" 2>/dev/null || {
  log_info "ServiceAccount '${USERNAME}' already exists"
}
log_success "ServiceAccount ready"

# Step 2: Create Secret for token
log_step "Creating token Secret..."
cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: v1
kind: Secret
metadata:
  name: ${USERNAME}-token
  namespace: ${NAMESPACE}
  annotations:
    kubernetes.io/service-account.name: ${USERNAME}
type: kubernetes.io/service-account-token
EOF
log_success "Token Secret created"

# Step 3: Wait for token to be populated
log_step "Waiting for token..."
sleep 2
TOKEN=$(kubectl get secret "${USERNAME}-token" -n "${NAMESPACE}" -o jsonpath='{.data.token}' | base64 -d)

if [[ -z "$TOKEN" ]]; then
  log_error "Token not found"
  exit 1
fi
log_success "Token retrieved"

# Step 4: Get cluster CA
log_step "Extracting cluster CA..."
kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d > "${KUBECONFIG_DIR}/ca.crt"
log_success "CA certificate saved"

# Step 5: Grant permissions
if [[ "$PERMISSION" != "none" ]]; then
  log_step "Granting permissions..."

  case "$PERMISSION" in
    cluster-admin)
      kubectl create clusterrolebinding "${USERNAME}-admin" \
        --clusterrole=cluster-admin \
        --serviceaccount="${NAMESPACE}:${USERNAME}" \
        2>/dev/null || log_info "ClusterRoleBinding already exists"
      log_success "Cluster-admin permissions granted"
      ;;
    view|edit|admin)
      kubectl create rolebinding "${USERNAME}-${PERMISSION}" \
        --clusterrole="${PERMISSION}" \
        --serviceaccount="${NAMESPACE}:${USERNAME}" \
        -n "${NAMESPACE}" \
        2>/dev/null || log_info "RoleBinding already exists"
      log_success "Namespace '${NAMESPACE}' permissions granted (role: ${PERMISSION})"
      ;;
  esac
fi

# Step 6: Create kubeconfig
log_step "Creating kubeconfig..."
KUBECONFIG_FILE="${KUBECONFIG_DIR}/${USERNAME}-kubeconfig.yaml"

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
    namespace: ${NAMESPACE}
  name: ${USERNAME}@${CLUSTER_NAME}
current-context: ${USERNAME}@${CLUSTER_NAME}
users:
- name: ${USERNAME}
  user:
    token: ${TOKEN}
EOF

log_success "Kubeconfig created"

echo ""
echo -e "${GREEN}✓ User created successfully!${NC}"
echo ""
log_info "User details:"
echo "  Username: system:serviceaccount:${NAMESPACE}:${USERNAME}"
echo "  Type: ServiceAccount token"
echo "  Permission: ${PERMISSION}"
if [[ "$PERMISSION" == "cluster-admin" ]]; then
  echo "  Scope: Cluster-wide"
elif [[ "$PERMISSION" != "none" ]]; then
  echo "  Scope: Namespace '${NAMESPACE}'"
else
  echo "  Scope: None (zero access)"
fi
echo "  Kubeconfig: ${KUBECONFIG_FILE}"
echo ""

# Show test commands based on permission
case "$PERMISSION" in
  none)
    log_info "Test zero access:"
    echo "  export KUBECONFIG=${KUBECONFIG_FILE}"
    echo "  kubectl get pods --all-namespaces"
    echo "  # Should fail: Error from server (Forbidden)"
    echo ""
    log_info "Grant permissions manually:"
    echo "  kubectl create rolebinding ${USERNAME}-edit --clusterrole=edit --serviceaccount=${NAMESPACE}:${USERNAME} -n myapp"
    echo "  kubectl create clusterrolebinding ${USERNAME}-admin --clusterrole=cluster-admin --serviceaccount=${NAMESPACE}:${USERNAME}"
    ;;
  cluster-admin)
    log_info "Test cluster-admin access:"
    echo "  export KUBECONFIG=${KUBECONFIG_FILE}"
    echo "  kubectl get nodes"
    echo "  kubectl get pods --all-namespaces"
    echo "  kubectl auth can-i '*' '*' --all-namespaces  # Should output: yes"
    echo ""
    log_info "To remove cluster-admin:"
    echo "  kubectl delete clusterrolebinding ${USERNAME}-admin"
    ;;
  view)
    log_info "Test view access:"
    echo "  export KUBECONFIG=${KUBECONFIG_FILE}"
    echo "  kubectl get pods -n ${NAMESPACE}  # ✓ Can view"
    echo "  kubectl delete pod xxx -n ${NAMESPACE}  # ✗ Forbidden"
    echo "  kubectl get secrets -n ${NAMESPACE}  # ✗ Forbidden (view can't see secrets)"
    ;;
  edit)
    log_info "Test edit access:"
    echo "  export KUBECONFIG=${KUBECONFIG_FILE}"
    echo "  kubectl create deployment test --image=nginx -n ${NAMESPACE}  # ✓ Can create"
    echo "  kubectl delete deployment test -n ${NAMESPACE}  # ✓ Can delete"
    echo "  kubectl get secrets -n ${NAMESPACE}  # ✓ Can view secrets"
    echo "  kubectl create rolebinding test ... -n ${NAMESPACE}  # ✗ Cannot manage RBAC"
    ;;
  admin)
    log_info "Test admin access:"
    echo "  export KUBECONFIG=${KUBECONFIG_FILE}"
    echo "  kubectl create rolebinding test ... -n ${NAMESPACE}  # ✓ Can manage RBAC"
    echo "  kubectl create resourcequota test ... -n ${NAMESPACE}  # ✓ Can set quotas"
    echo "  kubectl get pods -n other-namespace  # ✗ No access to other namespaces"
    ;;
esac

echo ""
log_info "Test identity:"
echo "  kubectl --kubeconfig=${KUBECONFIG_FILE} auth whoami"
echo ""
log_info "Switch back to admin:"
echo "  unset KUBECONFIG"
echo ""
log_info "To remove this user:"
echo "  kubectl delete serviceaccount ${USERNAME} -n ${NAMESPACE}"
echo "  kubectl delete secret ${USERNAME}-token -n ${NAMESPACE}"
if [[ "$PERMISSION" == "cluster-admin" ]]; then
  echo "  kubectl delete clusterrolebinding ${USERNAME}-admin"
elif [[ "$PERMISSION" != "none" ]]; then
  echo "  kubectl delete rolebinding ${USERNAME}-${PERMISSION} -n ${NAMESPACE}"
fi
echo "  rm ${KUBECONFIG_FILE}"
