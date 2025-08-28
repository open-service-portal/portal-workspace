#!/bin/bash

# Unified script to reload all Crossplane templates
# Handles both Configuration packages and direct Flux GitRepository sources

set -e

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     🔄 Reloading Crossplane Templates        ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Delete all XRs first (they depend on XRDs)
echo -e "${YELLOW}📦 Step 1: Deleting all Composite Resources (XRs)...${NC}"
for xrd in $(kubectl get xrd -o name 2>/dev/null); do
  resource_name=$(echo $xrd | sed 's/compositeresourcedefinition.apiextensions.crossplane.io\///')
  # Get the plural name for the resource
  plural=$(kubectl get $xrd -o jsonpath='{.spec.names.plural}')
  group=$(kubectl get $xrd -o jsonpath='{.spec.group}')
  if [ ! -z "$plural" ]; then
    echo "  ↳ Deleting XRs for $resource_name"
    kubectl delete $plural.$group --all 2>/dev/null || true
  fi
done

# Step 2: Delete all XRDs and Compositions
echo -e "${YELLOW}🗑️  Step 2: Deleting XRDs and Compositions...${NC}"
kubectl delete xrd --all 2>/dev/null || true
kubectl delete composition --all 2>/dev/null || true

# Step 3: Handle Configuration packages (dns-record, namespace)
echo -e "${YELLOW}📦 Step 3: Reloading Configuration packages...${NC}"
configs=$(kubectl get configuration.pkg.crossplane.io -n crossplane-system -o name 2>/dev/null)
if [ ! -z "$configs" ]; then
  for config in $configs; do
    config_name=$(echo $config | sed 's/configuration.pkg.crossplane.io\///')
    echo "  ↳ Deleting $config_name..."
    kubectl delete $config -n crossplane-system
  done
  
  # Wait for deletion
  echo "  ⏳ Waiting for Configuration packages to be deleted..."
  sleep 5
  
  # Reconcile catalog to recreate Configuration packages
  echo "  ♻️  Reconciling catalog to recreate Configuration packages..."
  flux reconcile source git catalog -n flux-system
  flux reconcile kustomization catalog -n flux-system
else
  echo "  ℹ️  No Configuration packages found"
fi

# Step 4: Handle direct Flux GitRepository templates (cloudflare, whoami)
echo -e "${YELLOW}🔄 Step 4: Reconciling direct Flux templates...${NC}"
# Get all template kustomizations from Flux
templates=$(flux get kustomizations -n flux-system | grep -E "template-" | awk '{print $1}')
if [ ! -z "$templates" ]; then
  for template in $templates; do
    echo "  ↳ Reconciling $template..."
    flux reconcile kustomization $template -n flux-system
  done
else
  echo "  ℹ️  No Flux template kustomizations found"
fi

# Step 5: Wait for XRDs to be established
echo -e "${YELLOW}⏳ Step 5: Waiting for XRDs to be established...${NC}"
sleep 10

# Check for XRD establishment with timeout
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
  xrd_count=$(kubectl get xrd --no-headers 2>/dev/null | wc -l | xargs)
  if [ "$xrd_count" -gt 0 ]; then
    established_count=$(kubectl get xrd -o json 2>/dev/null | jq '[.items[] | select(.status.conditions[]? | select(.type=="Established" and .status=="True"))] | length')
    if [ "$xrd_count" -eq "$established_count" ] 2>/dev/null; then
      echo -e "  ${GREEN}✓ All $xrd_count XRDs are established${NC}"
      break
    fi
  fi
  echo "  ⏳ Waiting for XRDs to be established (attempt $((attempt+1))/$max_attempts)..."
  sleep 2
  attempt=$((attempt+1))
done

# Step 6: Display status
echo ""
echo -e "${BLUE}📊 Final Status:${NC}"
echo -e "${BLUE}────────────────────────────────────────────${NC}"

# Show XRDs
xrd_count=$(kubectl get xrd --no-headers 2>/dev/null | wc -l || echo "0")
if [ $xrd_count -gt 0 ]; then
  echo -e "${GREEN}✅ XRDs restored: $xrd_count${NC}"
  kubectl get xrd 2>/dev/null | head -20
else
  echo -e "${RED}⚠️  No XRDs found${NC}"
fi

echo ""

# Show Compositions
comp_count=$(kubectl get composition --no-headers 2>/dev/null | wc -l || echo "0")
if [ $comp_count -gt 0 ]; then
  echo -e "${GREEN}✅ Compositions restored: $comp_count${NC}"
  kubectl get composition 2>/dev/null | head -20
else
  echo -e "${RED}⚠️  No Compositions found${NC}"
fi

echo ""
echo -e "${BLUE}────────────────────────────────────────────${NC}"

# Show Configuration package status
echo ""
echo -e "${YELLOW}Configuration Packages:${NC}"
kubectl get configuration.pkg.crossplane.io -n crossplane-system 2>/dev/null || echo "  No Configuration packages found"

echo ""
echo -e "${GREEN}✅ Template reload complete!${NC}"
echo ""
echo -e "${BLUE}💡 Troubleshooting tips:${NC}"
echo "  • If XRDs are missing, check Configuration package logs:"
echo "    kubectl describe configuration.pkg.crossplane.io -n crossplane-system"
echo "  • Check Flux logs for template issues:"
echo "    kubectl logs -n flux-system deployment/kustomize-controller | tail -50"
echo "  • Force reconcile a specific template:"
echo "    flux reconcile kustomization <template-name> -n flux-system"