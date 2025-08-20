#!/bin/bash
# List available Cloudflare zones for DNS record creation

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Available Cloudflare Zones ===${NC}"
echo ""

# Check if any zones exist
ZONE_COUNT=$(kubectl get zones.zone.cloudflare.upbound.io --no-headers 2>/dev/null | wc -l || echo "0")

if [ "$ZONE_COUNT" -eq "0" ]; then
    echo -e "${YELLOW}No zones found.${NC}"
    echo ""
    echo "To import zones, run: ./scripts/config-openportal.sh"
    exit 0
fi

echo "You can use these zone names in your CloudflareDNSRecord resources:"
echo ""

# List zones with details
kubectl get zones.zone.cloudflare.upbound.io -o custom-columns=\
"NAME:.metadata.name,DOMAIN:.spec.forProvider.zone,READY:.status.conditions[?(@.type=='Ready')].status,ZONE_ID:.metadata.annotations.crossplane\.io/external-name" \
--no-headers | while IFS= read -r line; do
    NAME=$(echo "$line" | awk '{print $1}')
    DOMAIN=$(echo "$line" | awk '{print $2}')
    READY=$(echo "$line" | awk '{print $3}')
    ZONE_ID=$(echo "$line" | awk '{print $4}')
    
    if [ "$READY" = "True" ]; then
        STATUS="${GREEN}✓${NC}"
    else
        STATUS="${RED}✗${NC}"
    fi
    
    echo -e "$STATUS ${BLUE}$NAME${NC} → $DOMAIN"
done

echo ""
echo -e "${BLUE}Usage Example:${NC}"
echo ""
echo "apiVersion: platform.io/v1alpha1"
echo "kind: CloudflareDNSRecord"
echo "metadata:"
echo "  name: my-record"
echo "spec:"
echo "  type: A"
echo "  name: myapp"
echo "  value: \"192.168.1.100\""
echo "  zone: \"openportal-zone\"  # Use one of the zone names above"
echo ""
echo "To add more zones, update .env.openportal and run ./scripts/config-openportal.sh"