#!/usr/bin/env bash

###############################################################################
# recover-rbac.sh
#
# Recovers the cloudspace-admin-role ClusterRoleBinding using the
# backstage-k8s-sa service account credentials.
#
# This script is designed as a backup recovery mechanism when the
# cloudspace-admin-role ClusterRoleBinding has been removed and needs to be
# restored. It uses the backstage-k8s-sa service account which has
# cluster-admin privileges to recreate the binding.
#
# Usage:
#   ./scripts/recover-rbac.sh
#
# Prerequisites:
#   - kubectl must be installed and in PATH
#   - Either:
#     - Current kubectl context has sufficient permissions, OR
#     - backstage-k8s-sa-token.local.txt exists in workspace root
###############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOKEN_FILE="${WORKSPACE_ROOT}/backstage-k8s-sa-token.local.txt"
SA_NAME="backstage-k8s-sa"
SA_NAMESPACE="default"
CLUSTERROLEBINDING_NAME="cloudspace-admin-role"
OIDC_GROUP="oidc:org_zOuCBHiyF1yG8d1D"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Kubernetes RBAC Recovery Script                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

###############################################################################
# Functions
###############################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    log_success "kubectl found: $(kubectl version --client --short 2>/dev/null | head -n1 || echo 'version check skipped')"
}

check_clusterrolebinding_exists() {
    if kubectl get clusterrolebinding "${CLUSTERROLEBINDING_NAME}" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

get_current_context() {
    kubectl config current-context 2>/dev/null || echo "unknown"
}

# Try to authenticate using service account token
setup_sa_credentials() {
    log_info "Attempting to use backstage-k8s-sa service account credentials..."

    # Check if token file exists
    if [[ -f "${TOKEN_FILE}" ]]; then
        log_success "Found token file: ${TOKEN_FILE}"
        SA_TOKEN=$(cat "${TOKEN_FILE}" | tr -d '\n')

        # Get the API server URL from current context
        API_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

        if [[ -z "${API_SERVER}" ]]; then
            log_error "Could not determine API server URL from kubectl config"
            return 1
        fi

        log_info "API Server: ${API_SERVER}"

        # Test the token
        if kubectl --token="${SA_TOKEN}" --server="${API_SERVER}" --insecure-skip-tls-verify auth can-i create clusterrolebindings &> /dev/null; then
            log_success "Service account token is valid and has required permissions"
            export KUBECTL_OPTS="--token=${SA_TOKEN} --server=${API_SERVER} --insecure-skip-tls-verify"
            return 0
        else
            log_warning "Service account token found but doesn't have required permissions"
            return 1
        fi
    else
        log_warning "Token file not found at: ${TOKEN_FILE}"
        return 1
    fi
}

# Try to use current kubectl context
use_current_context() {
    log_info "Attempting to use current kubectl context..."

    if kubectl auth can-i create clusterrolebindings &> /dev/null; then
        log_success "Current context has sufficient permissions"
        export KUBECTL_OPTS=""
        return 0
    else
        log_warning "Current context doesn't have permission to create ClusterRoleBindings"
        return 1
    fi
}

recover_clusterrolebinding() {
    log_info "Creating ClusterRoleBinding: ${CLUSTERROLEBINDING_NAME}"

    # Create the ClusterRoleBinding manifest
    cat <<EOF | kubectl ${KUBECTL_OPTS} apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ${CLUSTERROLEBINDING_NAME}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: ${OIDC_GROUP}
EOF

    if [[ $? -eq 0 ]]; then
        log_success "ClusterRoleBinding '${CLUSTERROLEBINDING_NAME}' created successfully"
        return 0
    else
        log_error "Failed to create ClusterRoleBinding"
        return 1
    fi
}

verify_recovery() {
    log_info "Verifying ClusterRoleBinding..."

    if kubectl ${KUBECTL_OPTS} get clusterrolebinding "${CLUSTERROLEBINDING_NAME}" &> /dev/null; then
        log_success "Verification successful: ClusterRoleBinding exists"
        echo ""
        kubectl ${KUBECTL_OPTS} get clusterrolebinding "${CLUSTERROLEBINDING_NAME}" -o yaml | grep -A 10 "^subjects:"
        return 0
    else
        log_error "Verification failed: ClusterRoleBinding not found"
        return 1
    fi
}

###############################################################################
# Main Script
###############################################################################

main() {
    log_info "Current kubectl context: $(get_current_context)"
    log_info "Target ClusterRoleBinding: ${CLUSTERROLEBINDING_NAME}"
    echo ""

    # Check prerequisites
    check_kubectl
    echo ""

    # Check if ClusterRoleBinding already exists
    if check_clusterrolebinding_exists; then
        log_warning "ClusterRoleBinding '${CLUSTERROLEBINDING_NAME}' already exists"
        echo ""
        log_info "Current configuration:"
        kubectl get clusterrolebinding "${CLUSTERROLEBINDING_NAME}" -o yaml | grep -A 10 "^subjects:"
        echo ""
        read -p "Do you want to recreate it? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Aborted by user"
            exit 0
        fi
        log_info "Deleting existing ClusterRoleBinding..."
        kubectl delete clusterrolebinding "${CLUSTERROLEBINDING_NAME}"
    fi

    # Try to establish authentication
    # First try current context, then fall back to service account token
    if ! use_current_context; then
        if ! setup_sa_credentials; then
            log_error "Failed to establish authentication"
            echo ""
            log_info "Please ensure either:"
            log_info "  1. Your current kubectl context has cluster-admin permissions, OR"
            log_info "  2. The token file exists at: ${TOKEN_FILE}"
            exit 1
        fi
    fi

    echo ""

    # Perform recovery
    if recover_clusterrolebinding; then
        echo ""
        verify_recovery
        echo ""
        log_success "RBAC recovery completed successfully!"
        echo ""
        echo -e "${GREEN}The OIDC group '${OIDC_GROUP}' now has cluster-admin access.${NC}"
    else
        echo ""
        log_error "RBAC recovery failed"
        exit 1
    fi
}

# Run main function
main "$@"
