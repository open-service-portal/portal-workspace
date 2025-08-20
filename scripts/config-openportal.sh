#!/bin/bash
# Configure OpenPortal production cluster with Cloudflare settings

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"
MANIFEST_DIR="${SCRIPT_DIR}/manifests-config-openportal"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Configuring OpenPortal cluster...${NC}"

# Load OpenPortal environment variables
if [ -f "$WORKSPACE_DIR/.env.openportal" ]; then
    set -a  # Auto-export all variables
    source "$WORKSPACE_DIR/.env.openportal"
    set +a  # Turn off auto-export
    echo "✓ Loaded .env.openportal"
else
    echo -e "${YELLOW}Warning: .env.openportal not found${NC}"
    exit 1
fi

# Switch to OpenPortal context
echo -e "${GREEN}Switching to context: ${KUBE_CONTEXT}${NC}"
if ! kubectl config use-context "${KUBE_CONTEXT}"; then
    echo -e "${RED}Error: Failed to switch to context '${KUBE_CONTEXT}'${NC}"
    echo "Available contexts:"
    kubectl config get-contexts
    exit 1
fi
echo "✓ Switched to context: ${KUBE_CONTEXT}"

# Create Cloudflare credentials secret
echo -e "${GREEN}Configuring Cloudflare credentials...${NC}"
# Use the user API token for authentication with proper JSON escaping
kubectl create secret generic cloudflare-credentials \
    --from-literal=credentials='{"api_token":"'"${CLOUDFLARE_USER_API_TOKEN}"'"}' \
    --namespace crossplane-system \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✓ Cloudflare credentials configured"

# Import Cloudflare Zone (if provider is installed)
if kubectl get crd zones.zone.cloudflare.upbound.io &>/dev/null; then
    echo -e "${GREEN}Importing Cloudflare Zone...${NC}"
    # Apply Zone manifest with variable substitution
    envsubst < "$MANIFEST_DIR/cloudflare-zone-openportal-dev.yaml" | kubectl apply -f -
    echo "✓ Zone imported: ${DNS_ZONE}"
else
    echo -e "${YELLOW}Note: Cloudflare provider not installed, skipping Zone import${NC}"
    echo "      Run setup-cluster.sh with Cloudflare provider to enable DNS management"
fi

# Update EnvironmentConfigs for OpenPortal
echo -e "${GREEN}Updating EnvironmentConfigs...${NC}"
# Apply environment configs with variable substitution
envsubst < "$MANIFEST_DIR/environment-configs.yaml" | kubectl apply -f -

echo "✓ EnvironmentConfigs updated for OpenPortal"

echo ""
echo -e "${GREEN}OpenPortal cluster configuration complete!${NC}"
echo ""
echo "DNS Zone: ${DNS_ZONE}"
echo "DNS Provider: ${DNS_PROVIDER}"
echo "Cloudflare Zone ID: ${CLOUDFLARE_ZONE_ID}"
echo "Cloudflare Account ID: ${CLOUDFLARE_ACCOUNT_ID}"
echo ""
echo "You can now create real DNS records in Cloudflare!"