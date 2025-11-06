#!/usr/bin/env bash
#
# Create User with Client Certificate and Custom Groups
# Purpose: Create test user with flexible custom group membership
#
# This uses Kubernetes client certificate authentication where groups
# are embedded in the certificate's O (Organization) fields.
#
# Usage:
#   ./scripts/create-user-with-cert.sh <username> <group1> [group2] [group3] ...
#
# Examples:
#   ./scripts/create-user-with-cert.sh alice developers
#   ./scripts/create-user-with-cert.sh bob developers backend-team
#   ./scripts/create-user-with-cert.sh charlie platform-admins ops-team

set -euo pipefail

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

# Show help
show_help() {
  cat <<EOF
Create User with Client Certificate and Custom Groups

Purpose: Create test user with flexible custom group membership using
         Kubernetes client certificate authentication where groups
         are embedded in the certificate's O (Organization) fields.

Usage:
  $0 <username> <group1> [group2] [group3] ...
  $0 --help

Arguments:
  username    Username for the new user
  group1...   One or more groups the user should belong to

Examples:
  $0 alice developers
  $0 bob developers backend-team
  $0 charlie platform-admins ops-team

The script will:
  1. Generate a private key and CSR with groups as O fields
  2. Create and approve a Kubernetes CertificateSigningRequest
  3. Generate a kubeconfig file for the user

Output files:
  ${HOME}/.kube/test-users/certs/<username>.key
  ${HOME}/.kube/test-users/certs/<username>.crt
  ${HOME}/.kube/test-users/<username>-cert-kubeconfig.yaml

To use the generated user:
  export KUBECONFIG=${HOME}/.kube/test-users/<username>-cert-kubeconfig.yaml
  kubectl auth whoami

EOF
  exit 0
}

# Check for help flag
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  show_help
fi

USERNAME="${1:-}"
shift || true
USER_GROUPS=("$@")

# Validate
if [[ -z "$USERNAME" ]] || [[ ${#USER_GROUPS[@]} -eq 0 ]]; then
  log_error "Username and at least one group are required"
  echo ""
  echo "Usage: $0 <username> <group1> [group2] [group3] ..."
  echo "       $0 --help"
  echo ""
  echo "Examples:"
  echo "  $0 alice developers"
  echo "  $0 bob developers backend-team"
  echo "  $0 charlie platform-admins ops-team"
  exit 1
fi

CERT_DIR="${HOME}/.kube/test-users/certs"
KUBECONFIG_DIR="${HOME}/.kube/test-users"
CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
CLUSTER_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

mkdir -p "${CERT_DIR}"
mkdir -p "${KUBECONFIG_DIR}"

echo ""
log_header "═══════════════════════════════════════════════════════════"
log_header "  Creating User with Certificate Authentication"
log_header "═══════════════════════════════════════════════════════════"
echo ""
echo "  Username: ${USERNAME}"
echo "  Groups: ${USER_GROUPS[*]}"
echo "  Authentication: Client certificate (x.509)"
echo ""

# Build subject with multiple O fields (one per group)
SUBJECT="/CN=${USERNAME}"
for GROUP in "${USER_GROUPS[@]}"; do
  SUBJECT="${SUBJECT}/O=${GROUP}"
done

log_step "Generating private key..."
openssl genrsa -out "${CERT_DIR}/${USERNAME}.key" 2048 2>/dev/null
log_success "Private key created"

log_step "Creating certificate signing request..."
openssl req -new -key "${CERT_DIR}/${USERNAME}.key" \
  -out "${CERT_DIR}/${USERNAME}.csr" \
  -subj "${SUBJECT}" 2>/dev/null
log_success "CSR created with subject: ${SUBJECT}"

log_step "Creating Kubernetes CertificateSigningRequest..."
CSR_BASE64=$(cat "${CERT_DIR}/${USERNAME}.csr" | base64 | tr -d '\n')
cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${USERNAME}-csr
spec:
  request: ${CSR_BASE64}
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 31536000  # 1 year
  usages:
  - client auth
EOF
log_success "CertificateSigningRequest created"

log_step "Approving certificate..."
kubectl certificate approve ${USERNAME}-csr >/dev/null 2>&1
log_success "Certificate approved"

log_step "Retrieving signed certificate..."
# Wait for certificate to be issued
for i in {1..10}; do
  CERT=$(kubectl get csr ${USERNAME}-csr -o jsonpath='{.status.certificate}' 2>/dev/null || echo "")
  if [[ -n "$CERT" ]]; then
    break
  fi
  sleep 1
done

if [[ -z "$CERT" ]]; then
  log_error "Certificate was not issued. Check CSR status:"
  kubectl get csr ${USERNAME}-csr
  exit 1
fi

echo "$CERT" | base64 -d > "${CERT_DIR}/${USERNAME}.crt"
log_success "Certificate retrieved"

log_step "Getting cluster CA..."
kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | \
  base64 -d > "${CERT_DIR}/ca.crt"
log_success "CA certificate saved"

log_step "Creating kubeconfig..."
KUBECONFIG_FILE="${KUBECONFIG_DIR}/${USERNAME}-cert-kubeconfig.yaml"

cat > "${KUBECONFIG_FILE}" <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: ${CERT_DIR}/ca.crt
    server: ${CLUSTER_SERVER}
  name: ${CLUSTER_NAME}
contexts:
- context:
    cluster: ${CLUSTER_NAME}
    user: ${USERNAME}
  name: ${USERNAME}@${CLUSTER_NAME}
current-context: ${USERNAME}@${CLUSTER_NAME}
users:
- name: ${USERNAME}
  user:
    client-certificate: ${CERT_DIR}/${USERNAME}.crt
    client-key: ${CERT_DIR}/${USERNAME}.key
EOF

log_success "Kubeconfig created"

echo ""
log_header "═══════════════════════════════════════════════════════════"
log_success "User created successfully!"
log_header "═══════════════════════════════════════════════════════════"
echo ""

log_info "User details:"
echo "  Username: ${USERNAME}"
echo "  Authentication: Client certificate (x.509)"
echo "  Groups: ${USER_GROUPS[*]}"
echo "  Certificate: ${CERT_DIR}/${USERNAME}.crt"
echo "  Private Key: ${CERT_DIR}/${USERNAME}.key"
echo "  Kubeconfig: ${KUBECONFIG_FILE}"
echo "  Valid: 1 year"
echo ""

log_info "Automatic group membership:"
echo "  This user belongs to these custom groups:"
for GROUP in "${USER_GROUPS[@]}"; do
  echo "    • ${GROUP}"
done
echo ""
echo "  Plus these automatic groups:"
echo "    • system:authenticated"
echo ""

log_info "How to authenticate with kubectl:"
echo ""
echo "  Method 1: Set KUBECONFIG environment variable (temporary)"
echo "  ────────────────────────────────────────────────────────"
echo "  export KUBECONFIG=${KUBECONFIG_FILE}"
echo "  kubectl get pods"
echo "  # All kubectl commands will use ${USERNAME} identity"
echo "  # To switch back: unset KUBECONFIG"
echo ""
echo "  Method 2: Use --kubeconfig flag (per-command)"
echo "  ────────────────────────────────────────────────────────"
echo "  kubectl --kubeconfig=${KUBECONFIG_FILE} get pods"
echo "  # Other kubectl commands use default context"
echo ""
echo "  Method 3: Merge into default kubeconfig (permanent)"
echo "  ────────────────────────────────────────────────────────"
echo "  # Backup current config first!"
echo "  cp ~/.kube/config ~/.kube/config.backup"
echo "  # Merge the new user context"
echo "  KUBECONFIG=~/.kube/config:${KUBECONFIG_FILE} \\"
echo "    kubectl config view --flatten > /tmp/merged-config"
echo "  mv /tmp/merged-config ~/.kube/config"
echo "  # Switch to the new context"
echo "  kubectl config use-context ${USERNAME}@${CLUSTER_NAME}"
echo "  # List all contexts"
echo "  kubectl config get-contexts"
echo "  # Switch back to admin"
echo "  kubectl config use-context ${CLUSTER_NAME}"
echo ""

log_info "Verify your identity and group membership:"
echo "  export KUBECONFIG=${KUBECONFIG_FILE}"
echo "  kubectl auth whoami"
echo ""
echo "  Expected output:"
echo "  ┌────────────────────────────────────────────────────────┐"
echo "  │ Username: ${USERNAME}"
echo "  │ Groups:"
for GROUP in "${USER_GROUPS[@]}"; do
  echo "  │   - ${GROUP}"
done
echo "  │   - system:authenticated"
echo "  └────────────────────────────────────────────────────────┘"
echo ""

log_info "Test permissions (should fail until RBAC is configured):"
echo "  export KUBECONFIG=${KUBECONFIG_FILE}"
echo "  kubectl get pods"
echo "  # Expected: Error - user has no permissions yet"
echo "  kubectl auth can-i get pods"
echo "  # Expected: no"
echo ""

log_info "Grant permissions to groups:"
echo ""
for GROUP in "${USER_GROUPS[@]}"; do
  echo "  # Allow group '${GROUP}' cluster-admin access"
  echo "  kubectl create clusterrolebinding ${GROUP}-admin \\"
  echo "    --clusterrole=cluster-admin \\"
  echo "    --group=${GROUP}"
  echo ""
  echo "  # Or namespace-scoped edit access"
  echo "  kubectl create rolebinding ${GROUP}-edit \\"
  echo "    --clusterrole=edit \\"
  echo "    --group=${GROUP} \\"
  echo "    -n <namespace>"
  echo ""
done

log_info "Example: Grant all groups edit access"
echo "  # This user is in ${#USER_GROUPS[@]} group(s), so create bindings for each:"
for GROUP in "${USER_GROUPS[@]}"; do
  echo "  kubectl create clusterrolebinding ${GROUP}-edit --clusterrole=edit --group=${GROUP}"
done
echo ""

log_info "To add user to MORE groups:"
echo "  # Create a new certificate with additional groups"
echo "  $0 ${USERNAME} ${USER_GROUPS[*]} new-group"
echo "  # Note: This will replace the existing certificate"
echo ""

log_info "To switch back to admin:"
echo "  unset KUBECONFIG"
echo ""

log_info "To remove this user:"
echo "  kubectl delete csr ${USERNAME}-csr"
echo "  rm ${CERT_DIR}/${USERNAME}.{key,csr,crt}"
echo "  rm ${KUBECONFIG_FILE}"
echo "  # Also delete any bindings created for this user's groups"
echo ""

log_info "Advantages of certificate authentication:"
echo "  ✓ Custom groups (unlike ServiceAccounts)"
echo "  ✓ Multiple groups per user"
echo "  ✓ No external dependencies"
echo "  ✓ Standard Kubernetes feature"
echo ""

log_info "Limitations:"
echo "  ✗ Groups fixed at certificate creation"
echo "  ✗ Need to recreate certificate to change groups"
echo "  ✗ Certificate has expiration (1 year)"
echo ""
