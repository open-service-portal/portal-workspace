#!/bin/bash
# Enhanced Cloudflare DNS validation script
# Tests both direct Record resources and XR functionality

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Test result function
test_result() {
    local test_name="$1"
    local result="$2"
    local message="$3"
    
    ((TESTS_TOTAL++))
    
    if [ "$result" = "pass" ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
        if [ -n "$message" ]; then
            echo "  $message"
        fi
    else
        echo -e "${RED}✗${NC} $test_name"
        ((TESTS_FAILED++))
        if [ -n "$message" ]; then
            echo -e "  ${RED}$message${NC}"
        fi
    fi
}

echo -e "${BLUE}=== Enhanced Cloudflare DNS Validation ===${NC}"
echo ""

# Load environment
if [ -f "$WORKSPACE_DIR/.env.openportal" ]; then
    source "$WORKSPACE_DIR/.env.openportal"
    echo "✓ Loaded .env.openportal"
else
    echo -e "${RED}✗ .env.openportal not found${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}1. API Token Validation${NC}"
echo "----------------------------------------"

# Test user API token
VERIFY_RESULT=$(curl -s "https://api.cloudflare.com/client/v4/user/tokens/verify" \
     -H "Authorization: Bearer ${CLOUDFLARE_USER_API_TOKEN}" | jq -r '.success')

if [ "$VERIFY_RESULT" = "true" ]; then
    test_result "API token validity" "pass" "Token is active and valid"
else
    test_result "API token validity" "fail" "Invalid token - check CLOUDFLARE_USER_API_TOKEN"
fi

# Test DNS permissions
DNS_TEST=$(curl -s "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records" \
     -H "Authorization: Bearer ${CLOUDFLARE_USER_API_TOKEN}" | jq -r '.success')

if [ "$DNS_TEST" = "true" ]; then
    test_result "DNS permissions" "pass" "Can access zone ${DNS_ZONE}"
else
    test_result "DNS permissions" "fail" "Cannot access DNS records for zone"
fi

# Test write permissions by creating and deleting a test record
echo -n ""
TEST_NAME="validation-test-$(date +%s)"
CREATE_RESULT=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records" \
     -H "Authorization: Bearer ${CLOUDFLARE_USER_API_TOKEN}" \
     -H "Content-Type: application/json" \
     --data "{\"type\":\"TXT\",\"name\":\"${TEST_NAME}\",\"content\":\"validation\",\"ttl\":300}" | jq -r '.success')

if [ "$CREATE_RESULT" = "true" ]; then
    # Delete the test record
    RECORD_ID=$(curl -s "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records?name=${TEST_NAME}.${DNS_ZONE}" \
         -H "Authorization: Bearer ${CLOUDFLARE_USER_API_TOKEN}" | jq -r '.result[0].id')
    
    curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records/${RECORD_ID}" \
         -H "Authorization: Bearer ${CLOUDFLARE_USER_API_TOKEN}" &>/dev/null
    
    test_result "Write permissions" "pass" "Can create and delete DNS records"
else
    test_result "Write permissions" "fail" "Cannot create DNS records"
fi

echo ""
echo -e "${BLUE}2. Crossplane Provider Status${NC}"
echo "----------------------------------------"

# Check provider health
PROVIDER_HEALTHY=$(kubectl get providers.pkg.crossplane.io provider-cloudflare -o jsonpath='{.status.conditions[?(@.type=="Healthy")].status}' 2>/dev/null || echo "NotFound")

if [ "$PROVIDER_HEALTHY" = "True" ]; then
    PROVIDER_VERSION=$(kubectl get providers.pkg.crossplane.io provider-cloudflare -o jsonpath='{.spec.package}' 2>/dev/null || echo "unknown")
    test_result "Provider health" "pass" "Version: $PROVIDER_VERSION"
else
    test_result "Provider health" "fail" "Provider not healthy or not installed"
fi

# Check ProviderConfig
if kubectl get providerconfig.cloudflare.upbound.io cloudflare-provider &>/dev/null; then
    test_result "ProviderConfig exists" "pass"
else
    test_result "ProviderConfig exists" "fail" "Run ./scripts/cloudflare/setup.sh"
fi

# Check secret format
SECRET_TOKEN=$(kubectl get secret cloudflare-credentials -n crossplane-system -o json 2>/dev/null | jq -r '.data.credentials' | base64 -d | jq -r '.api_token' 2>/dev/null || echo "")

if [ "$SECRET_TOKEN" = "$CLOUDFLARE_USER_API_TOKEN" ]; then
    test_result "Secret configuration" "pass" "Token matches .env.openportal"
else
    test_result "Secret configuration" "fail" "Token mismatch or secret not found"
fi

echo ""
echo -e "${BLUE}3. Crossplane Resources${NC}"
echo "----------------------------------------"

# Check XRD
if kubectl get xrd cloudflarednsrecords.platform.io &>/dev/null; then
    test_result "XRD installed" "pass" "cloudflarednsrecords.platform.io"
else
    test_result "XRD installed" "fail" "Run: kubectl apply -k template-cloudflare-dnsrecord/"
fi

# Check Composition
if kubectl get composition cloudflarednsrecord &>/dev/null; then
    # Compositions don't have a Ready status - check if it has valid pipeline
    COMP_GEN=$(kubectl get composition cloudflarednsrecord -o jsonpath='{.metadata.generation}' 2>/dev/null || echo "0")
    PIPELINE_STEPS=$(kubectl get composition cloudflarednsrecord -o jsonpath='{.spec.pipeline}' 2>/dev/null | jq '. | length' 2>/dev/null || echo "0")
    
    if [ "$PIPELINE_STEPS" -gt "0" ]; then
        test_result "Composition ready" "pass" "Has $PIPELINE_STEPS pipeline steps"
    else
        test_result "Composition ready" "fail" "No pipeline steps defined"
    fi
else
    test_result "Composition ready" "fail" "Composition not found"
fi

echo ""
echo -e "${BLUE}4. Direct Record Resource Test${NC}"
echo "----------------------------------------"

# Find or create a direct test record
DIRECT_RECORD=$(kubectl get record.dns.cloudflare.upbound.io -l test=cloudflare-setup --no-headers -o name 2>/dev/null | head -1)

if [ -z "$DIRECT_RECORD" ]; then
    echo "Creating new direct test record..."
    TEST_TIMESTAMP=$(date +%s)
    kubectl apply -f - <<EOF
apiVersion: dns.cloudflare.upbound.io/v1alpha1
kind: Record
metadata:
  name: direct-validation-${TEST_TIMESTAMP}
  labels:
    test: cloudflare-setup
spec:
  forProvider:
    zoneIdRef:
      name: openportal-zone
    name: "direct-validation-${TEST_TIMESTAMP}"
    value: "192.0.2.100"
    type: "A"
    ttl: 300
  providerConfigRef:
    name: cloudflare-provider
EOF
    DIRECT_RECORD="record.dns.cloudflare.upbound.io/direct-validation-${TEST_TIMESTAMP}"
    sleep 5
fi

if [ -n "$DIRECT_RECORD" ]; then
    # Check sync status
    SYNCED=$(kubectl get $DIRECT_RECORD -o jsonpath='{.status.conditions[?(@.type=="Synced")].status}' 2>/dev/null || echo "Unknown")
    SYNC_MESSAGE=$(kubectl get $DIRECT_RECORD -o jsonpath='{.status.conditions[?(@.type=="Synced")].message}' 2>/dev/null || echo "")
    
    if [ "$SYNCED" = "True" ]; then
        test_result "Direct Record sync" "pass" "Record synced successfully"
        
        # Check if it exists in Cloudflare
        RECORD_NAME=$(kubectl get $DIRECT_RECORD -o jsonpath='{.spec.forProvider.name}' 2>/dev/null || echo "")
        CF_CHECK=$(curl -s "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records?name=${RECORD_NAME}.${DNS_ZONE}" \
             -H "Authorization: Bearer ${CLOUDFLARE_USER_API_TOKEN}" | jq -r '.result | length')
        
        if [ "$CF_CHECK" -gt "0" ]; then
            test_result "Record in Cloudflare" "pass" "Found in Cloudflare API"
        else
            test_result "Record in Cloudflare" "fail" "Not found via API"
        fi
    else
        # Check for specific errors
        if echo "$SYNC_MESSAGE" | grep -q "7000"; then
            test_result "Direct Record sync" "fail" "Error 7000: API endpoint issue"
            echo "  This is a known issue with the cdloh provider v0.1.0"
            echo "  The provider may need to be updated or replaced"
        elif echo "$SYNC_MESSAGE" | grep -q "authentication"; then
            test_result "Direct Record sync" "fail" "Authentication error"
            echo "  Check secret format and API token"
        else
            test_result "Direct Record sync" "fail" "$SYNC_MESSAGE"
        fi
    fi
else
    test_result "Direct Record creation" "fail" "Could not create test record"
fi

echo ""
echo -e "${BLUE}5. XR (Composite Resource) Test${NC}"
echo "----------------------------------------"

# Check if composition exists before testing XR
if kubectl get composition cloudflarednsrecord &>/dev/null; then
    # Find or create an XR
    XR_RECORD=$(kubectl get cloudflarednsrecord -l test=cloudflare-setup --no-headers -o name 2>/dev/null | head -1)
    
    if [ -z "$XR_RECORD" ]; then
        echo "Creating new test XR..."
        XR_TIMESTAMP=$(date +%s)
        kubectl apply -f - <<EOF
apiVersion: platform.io/v1alpha1
kind: CloudflareDNSRecord
metadata:
  name: xr-validation-${XR_TIMESTAMP}
  labels:
    test: cloudflare-setup
spec:
  type: A
  name: xr-validation-${XR_TIMESTAMP}
  value: "192.0.2.101"
  ttl: 300
  proxied: false
EOF
        XR_RECORD="cloudflarednsrecord.platform.io/xr-validation-${XR_TIMESTAMP}"
        sleep 5
    fi
    
    if [ -n "$XR_RECORD" ]; then
        # Check XR sync status
        XR_SYNCED=$(kubectl get $XR_RECORD -o jsonpath='{.status.conditions[?(@.type=="Synced")].status}' 2>/dev/null || echo "Unknown")
        
        if [ "$XR_SYNCED" = "True" ]; then
            test_result "XR sync" "pass" "Composition processed successfully"
            
            # Check if managed resource was created
            MANAGED_RESOURCES=$(kubectl get $XR_RECORD -o jsonpath='{.spec.resourceRefs[*].name}' 2>/dev/null || echo "")
            if [ -n "$MANAGED_RESOURCES" ]; then
                RESOURCE_COUNT=$(echo "$MANAGED_RESOURCES" | wc -w | xargs)
                # Verify the resources actually exist
                EXISTING_COUNT=0
                for RESOURCE in $MANAGED_RESOURCES; do
                    if kubectl get records.dns.cloudflare.upbound.io $RESOURCE &>/dev/null; then
                        ((EXISTING_COUNT++))
                    fi
                done
                if [ "$EXISTING_COUNT" -gt 0 ]; then
                    test_result "Managed resources" "pass" "Created $EXISTING_COUNT managed resource(s): $MANAGED_RESOURCES"
                else
                    test_result "Managed resources" "fail" "Resources listed but not found"
                fi
            else
                test_result "Managed resources" "fail" "No managed resources created"
            fi
        else
            XR_MESSAGE=$(kubectl get $XR_RECORD -o jsonpath='{.status.conditions[?(@.type=="Synced")].message}' 2>/dev/null || echo "")
            test_result "XR sync" "fail" "$XR_MESSAGE"
        fi
    else
        test_result "XR creation" "fail" "Could not create test XR"
    fi
else
    test_result "XR test" "fail" "Composition not installed - skipping XR tests"
fi

echo ""
echo -e "${BLUE}6. Cloudflare API Verification${NC}"
echo "----------------------------------------"

# List all test records in Cloudflare
echo "Checking for test records in Cloudflare..."
TEST_RECORDS=$(curl -s "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records" \
    -H "Authorization: Bearer ${CLOUDFLARE_USER_API_TOKEN}" | \
    jq -r '.result[] | select(.name | contains("test") or contains("validation") or contains("direct") or contains("xr")) | .name' | sort -u)

if [ -n "$TEST_RECORDS" ]; then
    RECORD_COUNT=$(echo "$TEST_RECORDS" | wc -l)
    test_result "Records in Cloudflare" "pass" "Found $RECORD_COUNT test record(s)"
    echo "$TEST_RECORDS" | while read -r name; do
        echo "  • $name"
    done
else
    test_result "Records in Cloudflare" "fail" "No test records found"
fi

echo ""
echo -e "${BLUE}7. CRUD Operations Test${NC}"
echo "----------------------------------------"

# Test Create
TEST_CREATE_NAME="crud-test-$(date +%s)"
CREATE_RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records" \
     -H "Authorization: Bearer ${CLOUDFLARE_USER_API_TOKEN}" \
     -H "Content-Type: application/json" \
     --data "{\"type\":\"A\",\"name\":\"${TEST_CREATE_NAME}\",\"content\":\"192.0.2.200\",\"ttl\":300}")

CREATE_SUCCESS=$(echo "$CREATE_RESPONSE" | jq -r '.success')
RECORD_ID=$(echo "$CREATE_RESPONSE" | jq -r '.result.id')

if [ "$CREATE_SUCCESS" = "true" ]; then
    test_result "Create operation" "pass" "Created ${TEST_CREATE_NAME}.${DNS_ZONE}"
    
    # Test Update
    UPDATE_RESPONSE=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records/${RECORD_ID}" \
         -H "Authorization: Bearer ${CLOUDFLARE_USER_API_TOKEN}" \
         -H "Content-Type: application/json" \
         --data '{"content":"192.0.2.201"}')
    
    UPDATE_SUCCESS=$(echo "$UPDATE_RESPONSE" | jq -r '.success')
    if [ "$UPDATE_SUCCESS" = "true" ]; then
        test_result "Update operation" "pass" "Updated IP to 192.0.2.201"
    else
        test_result "Update operation" "fail" "Could not update record"
    fi
    
    # Test Delete
    DELETE_RESPONSE=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records/${RECORD_ID}" \
         -H "Authorization: Bearer ${CLOUDFLARE_USER_API_TOKEN}")
    
    DELETE_SUCCESS=$(echo "$DELETE_RESPONSE" | jq -r '.success')
    if [ "$DELETE_SUCCESS" = "true" ]; then
        test_result "Delete operation" "pass" "Deleted test record"
    else
        test_result "Delete operation" "fail" "Could not delete record"
    fi
else
    test_result "CRUD operations" "fail" "Could not create test record"
fi

echo ""
echo -e "${BLUE}8. All Records Inventory${NC}"
echo "----------------------------------------"

# List all Records in Kubernetes
echo "Records in Kubernetes:"
K8S_RECORDS=$(kubectl get records.dns.cloudflare.upbound.io -A --no-headers 2>/dev/null || echo "")
if [ -n "$K8S_RECORDS" ]; then
    K8S_COUNT=$(echo "$K8S_RECORDS" | wc -l | xargs)
    echo -e "  ${GREEN}Found $K8S_COUNT record(s) in Kubernetes:${NC}"
    echo "$K8S_RECORDS" | while IFS= read -r line; do
        NAME=$(echo "$line" | awk '{print $1}')
        READY=$(echo "$line" | awk '{print $2}')
        SYNCED=$(echo "$line" | awk '{print $3}')
        EXTERNAL=$(echo "$line" | awk '{print $4}')
        AGE=$(echo "$line" | awk '{print $5}')
        
        if [ "$READY" = "True" ] && [ "$SYNCED" = "True" ]; then
            STATUS_SYMBOL="✓"
            STATUS_COLOR="${GREEN}"
        elif [ "$SYNCED" = "False" ]; then
            STATUS_SYMBOL="✗"
            STATUS_COLOR="${RED}"
        else
            STATUS_SYMBOL="⚠"
            STATUS_COLOR="${YELLOW}"
        fi
        
        echo -e "    ${STATUS_COLOR}${STATUS_SYMBOL}${NC} $NAME (Ready: $READY, Synced: $SYNCED, Age: $AGE)"
    done
else
    echo -e "  ${YELLOW}No Record resources found in Kubernetes${NC}"
fi

echo ""

# List all XRs in Kubernetes
echo "CloudflareDNSRecord XRs in Kubernetes:"
XR_RECORDS=$(kubectl get cloudflarednsrecord -A --no-headers 2>/dev/null || echo "")
if [ -n "$XR_RECORDS" ]; then
    XR_COUNT=$(echo "$XR_RECORDS" | wc -l | xargs)
    echo -e "  ${GREEN}Found $XR_COUNT XR(s) in Kubernetes:${NC}"
    echo "$XR_RECORDS" | while IFS= read -r line; do
        NAME=$(echo "$line" | awk '{print $1}')
        SYNCED=$(kubectl get cloudflarednsrecord $NAME -o jsonpath='{.status.conditions[?(@.type=="Synced")].status}' 2>/dev/null || echo "Unknown")
        READY=$(kubectl get cloudflarednsrecord $NAME -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
        
        if [ "$READY" = "True" ] && [ "$SYNCED" = "True" ]; then
            STATUS="${GREEN}✓${NC}"
        elif [ "$SYNCED" = "False" ]; then
            STATUS="${RED}✗${NC}"
        else
            STATUS="${YELLOW}⚠${NC}"
        fi
        
        echo -e "    $STATUS $NAME (Ready: $READY, Synced: $SYNCED)"
    done
else
    echo -e "  ${YELLOW}No CloudflareDNSRecord XRs found${NC}"
fi

echo ""

# List ALL records in Cloudflare (not just test ones)
echo "ALL DNS Records in Cloudflare zone ${DNS_ZONE}:"
ALL_CF_RECORDS=$(curl -s "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records?per_page=100" \
    -H "Authorization: Bearer ${CLOUDFLARE_USER_API_TOKEN}" | \
    jq -r '.result[] | "\(.type)|\(.name)|\(.content)|\(.proxied)|\(.ttl)"' 2>/dev/null || echo "")

if [ -n "$ALL_CF_RECORDS" ]; then
    CF_COUNT=$(echo "$ALL_CF_RECORDS" | wc -l | xargs)
    echo -e "  ${GREEN}Found $CF_COUNT DNS record(s) in Cloudflare:${NC}"
    
    # Header
    printf "    %-6s %-50s %-40s %-8s %s\n" "Type" "Name" "Value" "Proxied" "TTL"
    printf "    %-6s %-50s %-40s %-8s %s\n" "----" "----" "-----" "-------" "---"
    
    # Records
    echo "$ALL_CF_RECORDS" | while IFS='|' read -r type name content proxied ttl; do
        # Truncate long values for display
        if [ ${#name} -gt 48 ]; then
            name="${name:0:45}..."
        fi
        if [ ${#content} -gt 38 ]; then
            content="${content:0:35}..."
        fi
        
        # Format TTL
        if [ "$ttl" = "1" ]; then
            ttl="Auto"
        fi
        
        # Highlight test records
        if echo "$name" | grep -qE "(test|validation|direct|xr)" ; then
            printf "    ${BLUE}%-6s %-50s %-40s %-8s %s${NC}\n" "$type" "$name" "$content" "$proxied" "$ttl"
        else
            printf "    %-6s %-50s %-40s %-8s %s\n" "$type" "$name" "$content" "$proxied" "$ttl"
        fi
    done
    
    # Count test vs non-test records
    TEST_COUNT=$(echo "$ALL_CF_RECORDS" | cut -d'|' -f2 | grep -cE "(test|validation|direct|xr)" || echo "0")
    NON_TEST_COUNT=$((CF_COUNT - TEST_COUNT))
    echo ""
    echo "  Summary: $TEST_COUNT test record(s), $NON_TEST_COUNT production record(s)"
else
    echo -e "  ${RED}Could not retrieve records from Cloudflare${NC}"
fi

echo ""
echo -e "${BLUE}=== Validation Summary ===${NC}"
echo ""

# Calculate percentage
if [ $TESTS_TOTAL -gt 0 ]; then
    PERCENTAGE=$((TESTS_PASSED * 100 / TESTS_TOTAL))
else
    PERCENTAGE=0
fi

# Summary with color coding
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed! ($TESTS_PASSED/$TESTS_TOTAL)${NC}"
    echo ""
    echo "The Cloudflare setup is working correctly."
    EXIT_CODE=0
elif [ $PERCENTAGE -ge 75 ]; then
    echo -e "${YELLOW}⚠ Most tests passed ($TESTS_PASSED/$TESTS_TOTAL - ${PERCENTAGE}%)${NC}"
    echo ""
    echo "The setup is mostly working but has some issues:"
    echo "• Check failed tests above for details"
    echo "• Consider running: ./scripts/cloudflare/remove.sh && ./scripts/cloudflare/setup.sh"
    EXIT_CODE=1
else
    echo -e "${RED}✗ Many tests failed ($TESTS_PASSED/$TESTS_TOTAL - ${PERCENTAGE}%)${NC}"
    echo ""
    echo "The setup has significant issues:"
    echo "• Review the error messages above"
    echo "• Run: ./scripts/cloudflare/remove.sh"
    echo "• Fix configuration issues"
    echo "• Run: ./scripts/cloudflare/setup.sh"
    EXIT_CODE=2
fi

echo ""
echo "Test Details:"
echo "• API Operations: Working directly with Cloudflare API"
if [ "$SYNCED" = "True" ]; then
    echo "• Crossplane Sync: Records syncing with Cloudflare"
else
    echo "• Crossplane Sync: Issues with provider (may need update)"
fi

echo ""
echo -e "${BLUE}Step 9: Cleanup${NC}"
echo "----------------------------------------"

# Clean up validation test resources
echo "Cleaning up test resources created by validation..."

# Remove direct test record if we created it
if [ -n "$TEST_TIMESTAMP" ]; then
    kubectl delete record.dns.cloudflare.upbound.io direct-validation-${TEST_TIMESTAMP} --ignore-not-found=true 2>/dev/null || true
    echo "✓ Removed direct test record"
fi

# Remove XR test record if we created it
if [ -n "$XR_TIMESTAMP" ]; then
    kubectl delete cloudflarednsrecord xr-validation-${XR_TIMESTAMP} --ignore-not-found=true 2>/dev/null || true
    echo "✓ Removed XR test record"
fi

echo ""
echo -e "${GREEN}Validation complete!${NC}"

exit $EXIT_CODE