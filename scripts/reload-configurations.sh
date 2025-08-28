#!/bin/bash

# Reload Crossplane Configuration packages
# This properly handles templates installed via Configuration packages

set -e

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🔄 Reloading Crossplane Configuration packages...${NC}"

# Step 1: Delete all XRs first (they depend on XRDs)
echo -e "${YELLOW}Deleting all XRs...${NC}"
for xrd in $(kubectl get xrd -o name); do
  resource_name=$(echo $xrd | sed 's/compositeresourcedefinition.apiextensions.crossplane.io\///')
  echo "  Deleting XRs for $resource_name"
  kubectl delete $resource_name --all 2>/dev/null || true
done

# Step 2: Delete all XRDs and Compositions
echo -e "${YELLOW}Deleting XRDs and Compositions...${NC}"
kubectl delete xrd --all 2>/dev/null || true
kubectl delete composition --all 2>/dev/null || true

# Step 3: Delete Configuration packages to force reinstall
echo -e "${YELLOW}Deleting Configuration packages to force reinstall...${NC}"
kubectl delete configuration.pkg.crossplane.io --all -n crossplane-system

# Wait for deletion
sleep 5

# Step 4: Reconcile catalog (which contains the Configuration definitions)
echo -e "${YELLOW}Reconciling catalog...${NC}"
flux reconcile source git catalog -n flux-system
flux reconcile kustomization catalog -n flux-system

# Step 5: Wait for XRDs to be established
echo -e "${YELLOW}Waiting for XRDs to be established...${NC}"
sleep 10

# Step 6: Check status
echo -e "${YELLOW}Checking XRD status...${NC}"
kubectl get xrd

echo -e "${GREEN}✅ Configuration packages reloaded!${NC}"
echo ""
echo "Note: If XRDs are missing, check the Configuration package logs:"
echo "  kubectl logs -n crossplane-system -l pkg.crossplane.io/package-name=configuration-dns-record"
echo "  kubectl logs -n crossplane-system -l pkg.crossplane.io/package-name=configuration-namespace"