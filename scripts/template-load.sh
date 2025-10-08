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
#   1. Deletes all XRDs from cluster (removes finalizers if stuck)
#   2. Applies XRDs from local template-* directories
#   3. Applies Compositions from local template-* directories
#   4. Shows status summary
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

XRD_COUNT=0
for template_dir in template-*/; do
    template_name="${template_dir%/}"

    # Try configuration/xrd.yaml first, then xrd.yaml
    if [ -f "${template_dir}configuration/xrd.yaml" ]; then
        xrd_file="${template_dir}configuration/xrd.yaml"
    elif [ -f "${template_dir}xrd.yaml" ]; then
        xrd_file="${template_dir}xrd.yaml"
    else
        continue
    fi

    echo -e "  → ${template_name}"
    if kubectl apply -f "${xrd_file}" 2>&1 | grep -v "Warning:"; then
        ((XRD_COUNT++))
    else
        echo -e "${RED}    ✗ Failed${NC}"
    fi
done

echo -e "${GREEN}  ✓ Applied ${XRD_COUNT} XRDs${NC}"
echo ""

# Step 3: Apply Compositions
echo -e "${YELLOW}Step 3: Applying Compositions from local templates...${NC}"

COMP_COUNT=0
for template_dir in template-*/; do
    template_name="${template_dir%/}"

    # Try configuration/composition.yaml first, then composition.yaml
    if [ -f "${template_dir}configuration/composition.yaml" ]; then
        comp_file="${template_dir}configuration/composition.yaml"
    elif [ -f "${template_dir}composition.yaml" ]; then
        comp_file="${template_dir}composition.yaml"
    else
        continue
    fi

    echo -e "  → ${template_name}"
    if kubectl apply -f "${comp_file}" 2>&1 | grep -v "Warning:"; then
        ((COMP_COUNT++))
    else
        echo -e "${RED}    ✗ Failed${NC}"
    fi
done

echo -e "${GREEN}  ✓ Applied ${COMP_COUNT} Compositions${NC}"
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
echo "  • Restart Backstage to pick up changes: cd app-portal && yarn start"
echo "  • Or wait for ingestor plugin to sync (typically 5-10 minutes)"
echo "  • Check Backstage logs for: 'Discovered X XRDs'"
