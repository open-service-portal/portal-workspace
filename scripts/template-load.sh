#!/usr/bin/env bash
#
# Template Load - Load local template XRDs/Compositions into cluster
#
# This script deletes all existing XRDs from the cluster and applies fresh
# copies from local template repositories. This ensures clean state without
# merged annotations or stale configuration.
#
# Usage:
#   ./scripts/template-load.sh
#
# What it does:
#   1. Checks Flux sync status and suspends if needed
#   2. Deletes all XRDs from cluster (removes finalizers if stuck)
#   3. Applies XRDs from local template-* directories
#   4. Applies Compositions from local template-* directories
#   5. Shows status summary
#
# Use cases:
#   - After changing XRD annotations (e.g., template-steps)
#   - When kubectl apply doesn't properly update annotations
#   - To ensure cluster has latest local template definitions
#   - For local development and testing
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     📦 Loading Local Templates              ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
echo ""

# Get workspace directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${WORKSPACE_DIR}"

# Step 0: Check Flux status and suspend if running
echo -e "${YELLOW}Step 0: Checking Flux GitOps status...${NC}"

if ! command -v flux &> /dev/null; then
    echo -e "${YELLOW}  ⚠ Flux CLI not found, skipping Flux check${NC}"
elif ! kubectl get namespace flux-system &> /dev/null; then
    echo -e "${YELLOW}  ⚠ Flux not installed, skipping Flux check${NC}"
else
    # Get Flux status using template-sync.sh
    FLUX_STATUS=$("${SCRIPT_DIR}/template-sync.sh" 2>/dev/null | grep "Status:" | awk '{print $2}' || echo "UNKNOWN")

    if [[ "$FLUX_STATUS" == *"RUNNING"* ]] || [[ "$FLUX_STATUS" == *"32m"* ]]; then
        echo -e "${YELLOW}  ⚠ Flux is running, suspending to prevent conflicts...${NC}"
        "${SCRIPT_DIR}/template-sync.sh" stop > /dev/null 2>&1
        echo -e "${GREEN}  ✓ Flux suspended${NC}"
    else
        echo -e "${GREEN}  ✓ Flux already suspended${NC}"
    fi
fi

echo ""

# Step 1: Delete all XRDs
echo -e "${YELLOW}Step 1: Deleting all XRDs from cluster...${NC}"
XRD_COUNT=$(kubectl get xrd --no-headers 2>/dev/null | wc -l || echo "0")

if [ "$XRD_COUNT" -gt 0 ]; then
    echo "  Found ${XRD_COUNT} XRDs to delete"
    kubectl delete xrd --all --timeout=10s 2>/dev/null || {
        echo -e "${YELLOW}  Some XRDs stuck, removing finalizers...${NC}"
        kubectl get xrd -o name 2>/dev/null | \
            xargs -I {} kubectl patch {} --type=json \
            -p='[{"op": "remove", "path": "/metadata/finalizers"}]' 2>/dev/null || true
        sleep 2
    }
    echo -e "${GREEN}  ✓ XRDs deleted${NC}"
else
    echo -e "${GREEN}  ✓ No XRDs to delete${NC}"
fi

echo ""

# Step 2: Find and apply XRDs
echo -e "${YELLOW}Step 2: Applying XRDs from local templates...${NC}"

# Collect all XRD files
XRD_FILES=()
for template_dir in template-*/; do
    if [ -f "${template_dir}configuration/xrd.yaml" ]; then
        XRD_FILES+=("${template_dir}configuration/xrd.yaml")
        echo -e "  → ${template_dir%/}"
    elif [ -f "${template_dir}xrd.yaml" ]; then
        XRD_FILES+=("${template_dir}xrd.yaml")
        echo -e "  → ${template_dir%/}"
    fi
done

# Apply all XRDs at once
if [ ${#XRD_FILES[@]} -gt 0 ]; then
    for xrd_file in "${XRD_FILES[@]}"; do
        kubectl apply -f "${xrd_file}" &>/dev/null
    done
    XRD_COUNT=${#XRD_FILES[@]}
    echo -e "${GREEN}  ✓ Applied ${XRD_COUNT} XRDs${NC}"
else
    echo -e "${RED}  ✗ No XRD files found${NC}"
    XRD_COUNT=0
fi

echo ""

# Step 3: Apply Compositions
echo -e "${YELLOW}Step 3: Applying Compositions from local templates...${NC}"

# Collect all Composition files
COMP_FILES=()
for template_dir in template-*/; do
    if [ -f "${template_dir}configuration/composition.yaml" ]; then
        COMP_FILES+=("${template_dir}configuration/composition.yaml")
        echo -e "  → ${template_dir%/}"
    elif [ -f "${template_dir}composition.yaml" ]; then
        COMP_FILES+=("${template_dir}composition.yaml")
        echo -e "  → ${template_dir%/}"
    fi
done

# Apply all Compositions at once
if [ ${#COMP_FILES[@]} -gt 0 ]; then
    for comp_file in "${COMP_FILES[@]}"; do
        kubectl apply -f "${comp_file}" &>/dev/null
    done
    COMP_COUNT=${#COMP_FILES[@]}
    echo -e "${GREEN}  ✓ Applied ${COMP_COUNT} Compositions${NC}"
else
    echo -e "${YELLOW}  ⚠ No Composition files found${NC}"
    COMP_COUNT=0
fi

echo ""

# Step 4: Wait for XRDs to be established
echo -e "${YELLOW}Step 4: Waiting for XRDs to be established...${NC}"
sleep 3

ESTABLISHED=0
for i in {1..10}; do
    ESTABLISHED=$(kubectl get xrd --no-headers 2>/dev/null | grep -c "True" || echo "0")
    if [ "$ESTABLISHED" -eq "$XRD_COUNT" ]; then
        break
    fi
    echo "  ⏳ Waiting... (${ESTABLISHED}/${XRD_COUNT} established)"
    sleep 2
done

if [ "$ESTABLISHED" -eq "$XRD_COUNT" ]; then
    echo -e "${GREEN}  ✓ All XRDs established${NC}"
else
    echo -e "${YELLOW}  ⚠ Only ${ESTABLISHED}/${XRD_COUNT} XRDs established${NC}"
fi

echo ""

# Step 5: Show summary
echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Summary                                  ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
echo ""

kubectl get xrd
echo ""
kubectl get compositions

echo ""
echo -e "${GREEN}✅ Template load complete!${NC}"
echo ""
echo -e "${BLUE}💡 Next steps:${NC}"
echo "  • Flux is SUSPENDED - local changes will persist"
echo "  • Restart Backstage to pick up changes: cd app-portal && yarn start"
echo "  • Or wait for ingestor plugin to sync (typically 5-10 minutes)"
echo "  • Check Backstage logs for: 'Discovered X XRDs'"
echo ""
echo -e "${YELLOW}⚠️  Remember:${NC}"
echo "  • Resume Flux when done testing: ./scripts/template-sync.sh start"
echo "  • Or keep it suspended for continued local development"
