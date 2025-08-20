#!/bin/bash
# Remove Cloudflare provider and all related resources
# Simple cleanup script - removes everything

set +e  # Continue on errors during cleanup

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Cloudflare Provider Removal ===${NC}"
echo ""

# Load environment for API cleanup
if [ -f "$WORKSPACE_DIR/.env.openportal" ]; then
    source "$WORKSPACE_DIR/.env.openportal"
fi

echo ""
echo -e "${BLUE}Step 1: Deleting Test Resources${NC}"
echo "----------------------------------------"

# Delete all CloudflareDNSRecord XRs
echo "Deleting CloudflareDNSRecord XRs..."
XR_COUNT=$(kubectl get cloudflarednsrecord --no-headers 2>/dev/null | wc -l || echo "0")
if [ "$XR_COUNT" -gt "0" ]; then
    kubectl delete cloudflarednsrecord --all --force --grace-period=0 --timeout=30s --timeout=30s 2>/dev/null || true
    echo "  Deleted $XR_COUNT XR(s)"
else
    echo "  No XRs found"
fi

# Delete all Record resources
echo "Deleting direct Record resources..."
RECORD_COUNT=$(kubectl get record.dns.cloudflare.upbound.io --no-headers 2>/dev/null | wc -l || echo "0")
if [ "$RECORD_COUNT" -gt "0" ]; then
    kubectl delete record.dns.cloudflare.upbound.io --all --force --grace-period=0 --timeout=30s --timeout=30s 2>/dev/null || true
    echo "  Deleted $RECORD_COUNT Record(s)"
else
    echo "  No Records found"
fi

# Delete test resources by label
echo "Deleting labeled test resources..."
kubectl delete record.dns.cloudflare.upbound.io -l test=cloudflare-setup --force --grace-period=0 --timeout=30s 2>/dev/null
kubectl delete cloudflarednsrecord -l test=cloudflare-setup --force --grace-period=0 --timeout=30s 2>/dev/null

echo ""
echo -e "${BLUE}Step 2: Deleting Zone Resource${NC}"
echo "----------------------------------------"

echo "Deleting Zone..."
kubectl delete zones.zone.cloudflare.upbound.io openportal-zone --force --grace-period=0 --timeout=30s 2>/dev/null || true
echo "  ✓ Zone resource deleted"

echo ""
echo -e "${BLUE}Step 3: Deleting Composition and XRD${NC}"
echo "----------------------------------------"

# Delete Composition
if kubectl get composition cloudflarednsrecord &>/dev/null; then
    echo "Deleting Composition..."
    kubectl delete composition cloudflarednsrecord --force --grace-period=0 --timeout=30s
    echo "  ✓ Composition deleted"
else
    echo "  Composition not found"
fi

# Delete XRD
if kubectl get xrd cloudflarednsrecords.platform.io &>/dev/null; then
    echo "Deleting XRD..."
    kubectl delete xrd cloudflarednsrecords.platform.io --force --grace-period=0 --timeout=30s
    echo "  ✓ XRD deleted"
else
    echo "  XRD not found"
fi

echo ""
echo -e "${BLUE}Step 4: Deleting ProviderConfig${NC}"
echo "----------------------------------------"

# List all ProviderConfigs
PROVIDER_CONFIGS=$(kubectl get providerconfig.cloudflare.upbound.io --no-headers -o name 2>/dev/null)
if [ -n "$PROVIDER_CONFIGS" ]; then
    echo "Deleting ProviderConfigs..."
    for pc in $PROVIDER_CONFIGS; do
        echo "  Deleting $pc..."
        kubectl delete $pc --force --grace-period=0 --timeout=30s 2>/dev/null
    done
else
    echo "  No ProviderConfigs found"
fi

echo ""
echo -e "${BLUE}Step 5: Deleting Provider${NC}"
echo "----------------------------------------"

if kubectl get providers.pkg.crossplane.io provider-cloudflare &>/dev/null; then
    echo "Deleting provider-cloudflare..."
    kubectl delete providers.pkg.crossplane.io provider-cloudflare --force --grace-period=0 --timeout=30s
    echo "  ✓ Provider deleted"
    
    # Wait a bit for provider to be removed
    sleep 5
else
    echo "  Provider not found"
fi

echo ""
echo -e "${BLUE}Step 6: Cleaning Up Secrets${NC}"
echo "----------------------------------------"

# Delete cloudflare-credentials secret
if kubectl get secret cloudflare-credentials -n crossplane-system &>/dev/null; then
    echo "Deleting cloudflare-credentials secret..."
    kubectl delete secret cloudflare-credentials -n crossplane-system
    echo "  ✓ Secret deleted"
else
    echo "  Secret not found"
fi

echo ""
echo -e "${BLUE}Step 7: API Cleanup Verification${NC}"
echo "----------------------------------------"

# If we have API credentials, check for orphaned records
if [ -n "$CLOUDFLARE_USER_API_TOKEN" ] && [ -n "$CLOUDFLARE_ZONE_ID" ]; then
    echo "Checking for test records in Cloudflare..."
    
    # List test records
    TEST_RECORDS=$(curl -s "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records" \
        -H "Authorization: Bearer ${CLOUDFLARE_USER_API_TOKEN}" | \
        jq -r '.result[] | select(.name | contains("test") or contains("direct") or contains("xr")) | "\(.id) \(.name)"')
    
    if [ -n "$TEST_RECORDS" ]; then
        echo -e "${YELLOW}Found test records in Cloudflare:${NC}"
        echo "$TEST_RECORDS" | while read -r id name; do
            echo "  - $name"
            # Optionally delete them
            # curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records/${id}" \
            #     -H "Authorization: Bearer ${CLOUDFLARE_USER_API_TOKEN}" &>/dev/null
        done
        echo ""
        echo "Note: These records were found but not deleted via API."
        echo "They should be cleaned up by Crossplane, but you may need to delete them manually."
    else
        echo "  ✓ No test records found in Cloudflare"
    fi
else
    echo "  Skipping API verification (credentials not available)"
fi

echo ""
echo -e "${BLUE}Step 8: Final Cleanup${NC}"
echo "----------------------------------------"

# Clean up any remaining CRDs
echo "Checking for remaining Cloudflare CRDs..."
REMAINING_CRDS=$(kubectl get crd | grep cloudflare | wc -l)
if [ "$REMAINING_CRDS" -gt "0" ]; then
    echo "  Found $REMAINING_CRDS Cloudflare CRDs"
    echo "  These will be removed when the provider is fully deleted"
else
    echo "  ✓ No Cloudflare CRDs remaining"
fi

echo ""
echo -e "${GREEN}=== Cleanup Complete ===${NC}"
echo ""
echo "Summary:"
echo "✓ Test resources deleted"
echo "✓ Zone resource removed"
echo "✓ Composition and XRD removed"
echo "✓ ProviderConfig deleted"
echo "✓ Provider removed"
echo "✓ Secrets cleaned up"
echo ""
echo "You can now run ./scripts/cloudflare/setup.sh to start fresh."