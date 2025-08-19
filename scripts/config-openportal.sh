#!/bin/bash
# Configure OpenPortal production cluster with Cloudflare settings

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Configuring OpenPortal cluster...${NC}"

# Load OpenPortal environment variables
if [ -f "$WORKSPACE_DIR/.env.openportal" ]; then
    source "$WORKSPACE_DIR/.env.openportal"
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
# The ProviderConfig is already created by setup-cluster.sh and references this secret
echo -e "${GREEN}Configuring Cloudflare credentials...${NC}"
kubectl create secret generic cloudflare-credentials \
    --from-literal=credentials="{\"api_token\":\"${CLOUDFLARE_API_TOKEN}\"}" \
    --namespace crossplane-system \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✓ Cloudflare credentials configured (ProviderConfig already exists from setup)"

# Update EnvironmentConfigs for OpenPortal
echo -e "${GREEN}Updating EnvironmentConfigs...${NC}"
kubectl apply -f - <<EOF
apiVersion: apiextensions.crossplane.io/v1beta1
kind: EnvironmentConfig
metadata:
  name: dns-config
  namespace: crossplane-system
data:
  zone: "${DNS_ZONE}"
  provider: "${DNS_PROVIDER}"
---
apiVersion: apiextensions.crossplane.io/v1beta1
kind: EnvironmentConfig
metadata:
  name: cloudflare-config
  namespace: crossplane-system
data:
  zone_id: "${CLOUDFLARE_ZONE_ID}"
  account_id: "${CLOUDFLARE_ACCOUNT_ID}"
EOF

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