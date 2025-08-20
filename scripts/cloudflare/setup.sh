#!/bin/bash
# Setup Cloudflare provider and configuration
# This script installs and configures everything needed for Cloudflare DNS management

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
TEMPLATE_DIR="$WORKSPACE_DIR/template-cloudflare-dnsrecord"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Cloudflare Provider Setup ===${NC}"
echo ""

# Load environment
if [ -f "$WORKSPACE_DIR/.env.openportal" ]; then
    source "$WORKSPACE_DIR/.env.openportal"
    echo "✓ Loaded .env.openportal"
else
    echo -e "${RED}✗ .env.openportal not found${NC}"
    echo "Please create .env.openportal from .env.openportal.example"
    exit 1
fi

# Check kubectl context
CURRENT_CONTEXT=$(kubectl config current-context)
echo "Current context: $CURRENT_CONTEXT"

echo ""
echo -e "${BLUE}Step 1: Installing Cloudflare Provider${NC}"
echo "----------------------------------------"

# Check if provider is already installed and healthy
if kubectl get providers.pkg.crossplane.io provider-cloudflare &>/dev/null; then
    PROVIDER_HEALTHY=$(kubectl get providers.pkg.crossplane.io provider-cloudflare -o jsonpath='{.status.conditions[?(@.type=="Healthy")].status}' 2>/dev/null || echo "Unknown")
    if [ "$PROVIDER_HEALTHY" = "True" ]; then
        echo "Provider already installed and healthy, skipping installation"
    else
        echo "Provider exists but not healthy, reinstalling..."
        kubectl delete providers.pkg.crossplane.io provider-cloudflare --force --grace-period=0 2>/dev/null || true
        sleep 5
        kubectl apply -f "$SCRIPT_DIR/../manifests-setup-cluster/crossplane-provider-cloudflare.yaml"
    fi
else
    # Install provider from manifest
    echo "Installing provider-cloudflare from manifest..."
    kubectl apply -f "$SCRIPT_DIR/../manifests-setup-cluster/crossplane-provider-cloudflare.yaml"
fi

# Wait for provider to be healthy
echo -n "Waiting for provider to be healthy..."
if kubectl wait --for=condition=Healthy providers.pkg.crossplane.io/provider-cloudflare --timeout=120s &>/dev/null; then
    echo -e " ${GREEN}✓${NC}"
else
    echo -e " ${RED}✗${NC}"
    echo "Provider failed to become healthy. Check logs:"
    echo "kubectl describe providers.pkg.crossplane.io provider-cloudflare"
    exit 1
fi

# Enable debug mode for provider
echo "Enabling debug mode for provider..."
DEPLOYMENT=$(kubectl get deployment -n crossplane-system -o name | grep provider-cloudflare | head -1)
if [ -n "$DEPLOYMENT" ]; then
    kubectl patch $DEPLOYMENT -n crossplane-system --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args", "value": ["--debug"]}]' 2>/dev/null || true
    echo "✓ Debug mode enabled"
fi

echo ""
echo -e "${BLUE}Step 2: Configuring Credentials${NC}"
echo "----------------------------------------"

# Create secret with proper JSON format
echo "Creating cloudflare-credentials secret..."
kubectl create secret generic cloudflare-credentials \
    --from-literal=credentials='{"api_token":"'"${CLOUDFLARE_USER_API_TOKEN}"'"}' \
    --namespace crossplane-system \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✓ Secret created/updated"

# Verify secret format
SECRET_TOKEN=$(kubectl get secret cloudflare-credentials -n crossplane-system -o json | jq -r '.data.credentials' | base64 -d | jq -r '.api_token' 2>/dev/null || echo "")
if [ "$SECRET_TOKEN" = "$CLOUDFLARE_USER_API_TOKEN" ]; then
    echo "✓ Secret format verified"
else
    echo -e "${RED}✗ Secret format incorrect${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}Step 3: Creating ProviderConfig${NC}"
echo "----------------------------------------"

# Create ProviderConfig from manifest now that CRDs are available
echo "Creating ProviderConfig from manifest..."
kubectl apply -f "$SCRIPT_DIR/../manifests-setup-cluster/crossplane-provider-cloudflare-config.yaml"

if kubectl get providerconfig.cloudflare.upbound.io cloudflare-provider &>/dev/null; then
    echo "✓ ProviderConfig created from manifest"
else
    echo -e "${RED}✗ Failed to create ProviderConfig${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}Step 4: Installing XRD and Composition${NC}"
echo "----------------------------------------"

if [ -d "$TEMPLATE_DIR" ]; then
    echo "Applying Cloudflare DNS template..."
    kubectl apply -k "$TEMPLATE_DIR"
    echo "✓ Template applied"
else
    echo -e "${YELLOW}⚠ Template directory not found: $TEMPLATE_DIR${NC}"
    echo "Skipping XRD/Composition installation"
fi

echo ""
echo -e "${BLUE}Step 5: Creating Environment Configs${NC}"
echo "----------------------------------------"

echo "Updating EnvironmentConfigs..."
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

echo "✓ EnvironmentConfigs updated"

echo ""
echo -e "${BLUE}Step 6: Importing Cloudflare Zone${NC}"
echo "----------------------------------------"

# Import existing zone using external-name annotation
echo "Importing existing Cloudflare zone..."
kubectl apply -f - <<EOF
apiVersion: zone.cloudflare.upbound.io/v1alpha1
kind: Zone
metadata:
  name: openportal-zone
  annotations:
    crossplane.io/external-name: "${CLOUDFLARE_ZONE_ID}"
  labels:
    zone: primary
spec:
  forProvider:
    zone: "${DNS_ZONE}"
    accountId: "${CLOUDFLARE_ACCOUNT_ID}"
  providerConfigRef:
    name: cloudflare-provider
EOF

echo "✓ Zone imported: ${DNS_ZONE} (${CLOUDFLARE_ZONE_ID})"

echo ""
echo -e "${BLUE}Step 7: Creating Test Resources${NC}"
echo "----------------------------------------"

# Create a Record resource with zoneIdRef for testing
echo "Creating test Record with zoneIdRef..."
TEST_TIMESTAMP=$(date +%s)
kubectl apply -f - <<EOF
apiVersion: dns.cloudflare.upbound.io/v1alpha1
kind: Record
metadata:
  name: direct-test-${TEST_TIMESTAMP}
  labels:
    test: cloudflare-setup
spec:
  forProvider:
    zoneIdRef:
      name: openportal-zone
    name: "direct-test-${TEST_TIMESTAMP}"
    value: "192.0.2.1"
    type: "A"
    ttl: 300
  providerConfigRef:
    name: cloudflare-provider
EOF

echo "✓ Created test Record with zoneIdRef: direct-test-${TEST_TIMESTAMP}"

# Create an XR if composition exists
if kubectl get composition cloudflarednsrecord &>/dev/null; then
    echo "Creating test CloudflareDNSRecord XR..."
    kubectl apply -f - <<EOF
apiVersion: platform.io/v1alpha1
kind: CloudflareDNSRecord
metadata:
  name: xr-test-${TEST_TIMESTAMP}
  labels:
    test: cloudflare-setup
spec:
  type: A
  name: xr-test-${TEST_TIMESTAMP}
  value: "192.0.2.2"
  ttl: 300
  proxied: false
EOF
    echo "✓ Created test XR: xr-test-${TEST_TIMESTAMP}"
else
    echo "⚠ Composition not found, skipping XR creation"
fi

echo ""
echo -e "${GREEN}=== Setup Complete ===${NC}"
echo ""
echo "Summary:"
echo "✓ Provider installed from manifest with debug mode"
echo "✓ Credentials configured (API token)" 
echo "✓ ProviderConfig created from manifest"
echo "✓ EnvironmentConfigs created"
echo "✓ XRD and Composition installed"
echo "✓ Zone imported: ${DNS_ZONE}"
echo "✓ Test resources created"
echo ""
echo "Next steps:"
echo "1. Run: ./scripts/cloudflare/validate.sh"
echo "2. Check for any errors"
echo "3. If needed, run: ./scripts/cloudflare/remove.sh"