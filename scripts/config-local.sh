#!/bin/bash
# Switch to local Kubernetes cluster context

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Switching to local cluster...${NC}"

# Load local environment variables
if [ -f "$WORKSPACE_DIR/.env.local" ]; then
    source "$WORKSPACE_DIR/.env.local"
    echo "✓ Loaded .env.local"
else
    echo -e "${YELLOW}Warning: .env.local not found${NC}"
    echo "Using default: rancher-desktop"
    KUBE_CONTEXT="rancher-desktop"
fi

# Switch to local context
echo -e "${GREEN}Switching to context: ${KUBE_CONTEXT}${NC}"
if ! kubectl config use-context "${KUBE_CONTEXT}"; then
    echo -e "${RED}Error: Failed to switch to context '${KUBE_CONTEXT}'${NC}"
    echo "Available contexts:"
    kubectl config get-contexts
    exit 1
fi
echo "✓ Switched to context: ${KUBE_CONTEXT}"

echo ""
echo -e "${GREEN}Local cluster active!${NC}"
echo ""
echo "DNS Zone: localhost (default)"
echo "DNS Provider: mock (default)"
echo ""
echo "You can now create DNS records that will resolve to localhost"