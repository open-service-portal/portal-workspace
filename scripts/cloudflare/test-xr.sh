#!/bin/bash
# Test Cloudflare XR with zoneIdRef pattern
# Based on cdloh provider examples

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment
if [ -f "$WORKSPACE_DIR/.env.openportal" ]; then
    source "$WORKSPACE_DIR/.env.openportal"
    echo "✓ Loaded .env.openportal"
else
    echo -e "${RED}✗ .env.openportal not found${NC}"
    exit 1
fi

ACTION=${1:-create}
TEST_NAME="xr-ref-test-$(date +%s)"

if [ "$ACTION" = "create" ]; then
    echo -e "${BLUE}=== Creating Test Resources ===${NC}"
    echo ""
    
    # Check if Zone resource exists
    if ! kubectl get zones.zone.cloudflare.upbound.io openportal-zone &>/dev/null; then
        echo -e "${RED}Error: Zone resource 'openportal-zone' not found${NC}"
        echo "Please run config-openportal.sh first to create the Zone resource"
        exit 1
    fi
    echo "✓ Using existing Zone resource: openportal-zone"
    
    echo ""
    echo "Step 1: Creating Record with zoneIdRef..."
    kubectl apply -f - <<EOF
apiVersion: dns.cloudflare.upbound.io/v1alpha1
kind: Record
metadata:
  name: ${TEST_NAME}
  labels:
    test: zoneref
spec:
  forProvider:
    zoneIdRef:
      name: openportal-zone
    name: ${TEST_NAME}
    value: 192.168.0.11
    type: A
    ttl: 3600
  providerConfigRef:
    name: cloudflare-provider
EOF
    echo "✓ Record with zoneIdRef created: ${TEST_NAME}"
    
    echo ""
    echo "Step 2: Creating another Record with zoneIdRef..."
    kubectl apply -f - <<EOF
apiVersion: dns.cloudflare.upbound.io/v1alpha1
kind: Record
metadata:
  name: ref2-${TEST_NAME}
  labels:
    test: zoneref
spec:
  forProvider:
    zoneIdRef:
      name: openportal-zone
    name: ref2-${TEST_NAME}
    value: 192.168.0.12
    type: A
    ttl: 3600
  providerConfigRef:
    name: cloudflare-provider
EOF
    echo "✓ Second Record with zoneIdRef created: ref2-${TEST_NAME}"
    
    echo ""
    echo -e "${GREEN}=== Test Resources Created ===${NC}"
    echo ""
    echo "Check status with:"
    echo "  kubectl get zones.zone.cloudflare.upbound.io"
    echo "  kubectl get records.dns.cloudflare.upbound.io"
    echo ""
    echo "Remove with:"
    echo "  $0 remove"
    
elif [ "$ACTION" = "remove" ]; then
    echo -e "${BLUE}=== Removing Test Resources ===${NC}"
    echo ""
    
    echo "Removing test Records..."
    kubectl delete records.dns.cloudflare.upbound.io -l test=zoneref --force --grace-period=0 2>/dev/null || true
    
    echo ""
    echo -e "${GREEN}=== Test Resources Removed ===${NC}"
    
elif [ "$ACTION" = "status" ]; then
    echo -e "${BLUE}=== Test Resource Status ===${NC}"
    echo ""
    
    echo "Zones:"
    kubectl get zones.zone.cloudflare.upbound.io -o wide
    echo ""
    
    echo "Records:"
    kubectl get records.dns.cloudflare.upbound.io -l test -o wide
    echo ""
    
    echo "Recent Events:"
    kubectl get events --sort-by='.lastTimestamp' | grep -E "Record|Zone" | tail -10
    
else
    echo "Usage: $0 [create|remove|status]"
    echo ""
    echo "  create - Create test resources with zoneIdRef pattern"
    echo "  remove - Remove all test resources"
    echo "  status - Show status of test resources"
    exit 1
fi