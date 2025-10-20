#!/usr/bin/env bash
# Template Sync Control Script
# Controls Flux GitOps synchronization for the catalog repository
# Allows local template testing without GitOps interference

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
FLUX_NAMESPACE="flux-system"
KUSTOMIZATION_NAME="catalog"

# Usage information
usage() {
    cat << EOF
Usage: $0 {start|stop|status}

Control Flux GitOps synchronization for the catalog repository.

Commands:
    start   - Resume Flux synchronization (GitOps enabled)
    stop    - Suspend Flux synchronization (local testing mode)
    status  - Show current synchronization status

Examples:
    # Stop GitOps sync for local template testing
    $0 stop

    # Check current status
    $0 status

    # Resume GitOps sync when done testing
    $0 start

Description:
    When testing local template changes, you want to prevent Flux from
    overwriting your manual XRD updates. This script suspends/resumes
    the Flux Kustomization that manages the catalog repository.

    Stop:  Suspends Flux reconciliation (manual changes persist)
    Start: Resumes Flux reconciliation (cluster syncs from Git)

EOF
    exit 1
}

# Check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}Error: kubectl not found. Please install kubectl.${NC}"
        exit 1
    fi
}

# Check if cluster is accessible
check_cluster() {
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}Error: Cannot connect to Kubernetes cluster.${NC}"
        echo "Please check your kubeconfig and cluster connection."
        exit 1
    fi
}

# Check if Flux is installed
check_flux() {
    if ! kubectl get namespace "$FLUX_NAMESPACE" &> /dev/null; then
        echo -e "${RED}Error: Flux namespace '$FLUX_NAMESPACE' not found.${NC}"
        echo "Please install Flux first."
        exit 1
    fi

    if ! kubectl get kustomization "$KUSTOMIZATION_NAME" -n "$FLUX_NAMESPACE" &> /dev/null; then
        echo -e "${RED}Error: Kustomization '$KUSTOMIZATION_NAME' not found in namespace '$FLUX_NAMESPACE'.${NC}"
        echo "Please check your Flux installation."
        exit 1
    fi
}

# Get current suspension status
get_status() {
    kubectl get kustomization "$KUSTOMIZATION_NAME" -n "$FLUX_NAMESPACE" \
        -o jsonpath='{.spec.suspend}' 2>/dev/null
}

# Get detailed information
get_details() {
    kubectl get kustomization "$KUSTOMIZATION_NAME" -n "$FLUX_NAMESPACE" \
        -o jsonpath='{.spec.interval}{"|"}{.spec.sourceRef.name}{"|"}{.status.lastAppliedRevision}' 2>/dev/null
}

# Show status
show_status() {
    echo -e "${BLUE}=== Template Sync Status ===${NC}"
    echo ""

    local suspended=$(get_status)
    local details=$(get_details)
    local interval=$(echo "$details" | cut -d'|' -f1)
    local source=$(echo "$details" | cut -d'|' -f2)
    local revision=$(echo "$details" | cut -d'|' -f3)

    echo "Cluster:        $(kubectl config current-context)"
    echo "Namespace:      $FLUX_NAMESPACE"
    echo "Kustomization:  $KUSTOMIZATION_NAME"
    echo "Source:         $source"
    echo ""

    if [ "$suspended" = "true" ]; then
        echo -e "Status:         ${YELLOW}SUSPENDED${NC} (GitOps disabled)"
        echo ""
        echo -e "${YELLOW}⚠ Local Testing Mode Active${NC}"
        echo "  - Flux will NOT sync from Git"
        echo "  - Manual XRD changes will persist"
        echo "  - Run '$0 start' to resume GitOps"
    else
        echo -e "Status:         ${GREEN}RUNNING${NC} (GitOps enabled)"
        echo "Sync Interval:  $interval"
        echo "Last Revision:  ${revision:0:12}"
        echo ""
        echo -e "${GREEN}✓ GitOps Active${NC}"
        echo "  - Flux syncs every $interval"
        echo "  - Cluster state matches Git"
        echo "  - Manual changes will be reverted"
    fi

    echo ""
}

# Stop (suspend) Flux synchronization
stop_sync() {
    echo -e "${BLUE}Stopping template synchronization...${NC}"

    local current_status=$(get_status)
    if [ "$current_status" = "true" ]; then
        echo -e "${YELLOW}Already suspended${NC}"
        show_status
        exit 0
    fi

    kubectl patch kustomization "$KUSTOMIZATION_NAME" -n "$FLUX_NAMESPACE" \
        -p '{"spec":{"suspend":true}}' \
        --type=merge

    echo ""
    echo -e "${GREEN}✓ Template sync suspended${NC}"
    echo ""
    echo "You can now:"
    echo "  1. Apply local XRD changes:"
    echo "     kubectl apply -f template-*/configuration/xrd.yaml"
    echo ""
    echo "  2. Test with Backstage:"
    echo "     cd app-portal && yarn start"
    echo ""
    echo "  3. Resume sync when done:"
    echo "     $0 start"
    echo ""
    show_status
}

# Start (resume) Flux synchronization
start_sync() {
    echo -e "${BLUE}Starting template synchronization...${NC}"

    local current_status=$(get_status)
    if [ "$current_status" != "true" ]; then
        echo -e "${YELLOW}Already running${NC}"
        show_status
        exit 0
    fi

    kubectl patch kustomization "$KUSTOMIZATION_NAME" -n "$FLUX_NAMESPACE" \
        -p '{"spec":{"suspend":false}}' \
        --type=merge

    echo ""
    echo -e "${GREEN}✓ Template sync resumed${NC}"
    echo ""
    echo -e "${YELLOW}⚠ Warning:${NC} Flux will now reconcile cluster state from Git."
    echo "  - Manual XRD changes may be overwritten"
    echo "  - Sync happens every $(kubectl get kustomization "$KUSTOMIZATION_NAME" -n "$FLUX_NAMESPACE" -o jsonpath='{.spec.interval}')"
    echo ""
    show_status
}

# Main script logic
main() {
    # Check prerequisites
    check_kubectl
    check_cluster
    check_flux

    # Parse command
    case "${1:-}" in
        start)
            start_sync
            ;;
        stop)
            stop_sync
            ;;
        status)
            show_status
            ;;
        -h|--help)
            usage
            ;;
        *)
            if [ -z "${1:-}" ]; then
                show_status
            else
                echo -e "${RED}Error: Unknown command '$1'${NC}"
                echo ""
                usage
            fi
            ;;
    esac
}

# Run main function
main "$@"
