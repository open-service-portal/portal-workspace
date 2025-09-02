#!/bin/bash
# Universal cleanup script for OpenPortal infrastructure components
# Allows selective cleanup of various installed components

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Display usage
usage() {
    echo -e "${BLUE}=== OpenPortal Cleanup Script ===${NC}"
    echo ""
    echo "Usage: $0 [component] [options]"
    echo ""
    echo "Components:"
    echo "  all                    - Remove everything (use with caution!)"
    echo "  cloudflare-provider    - Remove Crossplane Cloudflare provider and resources"
    echo "  external-dns           - Remove External-DNS and DNSEndpoint CRD"
    echo "  crossplane             - Remove Crossplane and all providers"
    echo "  flux                   - Remove Flux GitOps components"
    echo "  nginx                  - Remove NGINX Ingress Controller"
    echo "  backstage-sa           - Remove Backstage service account and secrets"
    echo "  environment-configs    - Remove platform environment configurations"
    echo "  catalog-orders         - Remove catalog-orders Flux sources"
    echo ""
    echo "Options:"
    echo "  --dry-run            - Show what would be deleted without actually deleting"
    echo ""
    echo "Examples:"
    echo "  $0 cloudflare-provider     # Remove old Cloudflare provider"
    echo "  $0 external-dns            # Remove External-DNS"
    echo "  $0 all                     # Remove everything"
    echo ""
    exit 0
}

# Global variables
DRY_RUN=false
COMPONENT=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            if [ -z "$COMPONENT" ]; then
                COMPONENT=$1
            fi
            shift
            ;;
    esac
done

# Check if component is specified
if [ -z "$COMPONENT" ]; then
    usage
fi

# Check kubectl connectivity
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
    echo "Please ensure kubectl is configured correctly"
    exit 1
fi

echo -e "${CYAN}Current cluster: $(kubectl config current-context)${NC}"
echo ""

# Status message function
status_message() {
    local message=$1
    echo -e "${YELLOW}$message${NC}"
    echo -e "${GREEN}Proceeding with cleanup...${NC}"
}

# Safe delete function
safe_delete() {
    local cmd="$@"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${CYAN}[DRY-RUN]${NC} Would run: kubectl $cmd"
    else
        kubectl $cmd --ignore-not-found=true 2>/dev/null || true
    fi
}

# Cleanup Cloudflare Provider
cleanup_cloudflare_provider() {
    echo -e "${YELLOW}Cleaning up Cloudflare Provider...${NC}"
    
    # Check if provider exists
    if ! kubectl get provider.pkg.crossplane.io provider-cloudflare &>/dev/null 2>&1; then
        echo "No Cloudflare provider found."
        return
    fi
    
    status_message "This will remove the Cloudflare provider and all related resources."
    
    # Delete CloudflareDNSRecord XRs
    echo "Removing CloudflareDNSRecord XRs..."
    if kubectl get crd cloudflarednsrecords.openportal.dev &>/dev/null 2>&1; then
        safe_delete delete cloudflarednsrecord --all --all-namespaces
    fi
    
    # Delete Zone resources
    echo "Removing Zone resources..."
    if kubectl get crd zones.zone.cloudflare.upbound.io &>/dev/null 2>&1; then
        safe_delete delete zone.zone.cloudflare.upbound.io --all
    fi
    
    # Delete ProviderConfig
    echo "Removing ProviderConfig..."
    safe_delete delete providerconfig.cloudflare.upbound.io cloudflare-provider
    
    # Delete Configuration
    echo "Removing Configuration package..."
    safe_delete delete configuration configuration-cloudflare-dnsrecord
    
    # Delete Provider
    echo "Removing Provider..."
    safe_delete delete provider.pkg.crossplane.io provider-cloudflare
    
    # Delete Secret
    echo "Removing credentials secret..."
    safe_delete delete secret cloudflare-credentials -n crossplane-system
    
    # Delete CRDs
    echo "Removing Cloudflare CRDs..."
    for crd in $(kubectl get crd -o name | grep cloudflare); do
        safe_delete delete $crd
    done
    
    echo -e "${GREEN}✓ Cloudflare provider cleanup complete${NC}"
}

# Cleanup External-DNS
cleanup_external_dns() {
    echo -e "${YELLOW}Cleaning up External-DNS...${NC}"
    
    status_message "This will remove External-DNS and the DNSEndpoint CRD."
    
    # Delete DNSEndpoint resources
    echo "Removing DNSEndpoint resources..."
    if kubectl get crd dnsendpoints.externaldns.openportal.dev &>/dev/null 2>&1; then
        safe_delete delete dnsendpoint --all --all-namespaces
    fi
    
    # Delete External-DNS deployment
    echo "Removing External-DNS deployment..."
    safe_delete delete deployment external-dns -n external-dns
    
    # Delete secrets
    echo "Removing External-DNS secrets..."
    safe_delete delete secret cloudflare-api-token -n external-dns
    
    # Delete service account and RBAC
    echo "Removing External-DNS RBAC..."
    safe_delete delete clusterrolebinding external-dns
    safe_delete delete clusterrole external-dns
    safe_delete delete serviceaccount external-dns -n external-dns
    
    # Delete CRD
    echo "Removing DNSEndpoint CRD..."
    safe_delete delete crd dnsendpoints.externaldns.openportal.dev
    
    # Delete namespace
    echo "Removing External-DNS namespace..."
    safe_delete delete namespace external-dns
    
    echo -e "${GREEN}✓ External-DNS cleanup complete${NC}"
}

# Cleanup Crossplane
cleanup_crossplane() {
    echo -e "${YELLOW}Cleaning up Crossplane...${NC}"
    
    status_message "This will remove Crossplane and ALL providers. All XRs will be deleted!"
    
    # Delete all XRs first
    echo "Removing all Composite Resources..."
    for xrd in $(kubectl get xrd -o name); do
        resource=$(echo $xrd | cut -d'/' -f2 | cut -d'.' -f1)
        group=$(echo $xrd | cut -d'/' -f2 | cut -d'.' -f2-)
        echo "  Deleting ${resource}.${group} resources..."
        safe_delete delete ${resource}.${group} --all --all-namespaces
    done
    
    # Delete all Configurations
    echo "Removing all Configurations..."
    safe_delete delete configuration --all
    
    # Delete all Providers
    echo "Removing all Providers..."
    safe_delete delete provider.pkg.crossplane.io --all
    
    # Wait for providers to terminate
    if [ "$DRY_RUN" = false ]; then
        echo "Waiting for providers to terminate..."
        sleep 10
    fi
    
    # Uninstall Crossplane via Helm
    echo "Uninstalling Crossplane..."
    if [ "$DRY_RUN" = true ]; then
        echo -e "${CYAN}[DRY-RUN]${NC} Would run: helm uninstall crossplane -n crossplane-system"
    else
        helm uninstall crossplane -n crossplane-system 2>/dev/null || true
    fi
    
    # Delete namespace
    echo "Removing Crossplane namespace..."
    safe_delete delete namespace crossplane-system
    
    echo -e "${GREEN}✓ Crossplane cleanup complete${NC}"
}

# Cleanup Flux
cleanup_flux() {
    echo -e "${YELLOW}Cleaning up Flux...${NC}"
    
    status_message "This will remove Flux and all GitOps configurations."
    
    # Delete Flux sources
    echo "Removing Flux sources..."
    safe_delete delete gitrepository --all -n flux-system
    safe_delete delete helmrepository --all -n flux-system
    
    # Delete Flux kustomizations
    echo "Removing Flux kustomizations..."
    safe_delete delete kustomization --all -n flux-system
    
    # Delete Flux helm releases
    echo "Removing Flux helm releases..."
    safe_delete delete helmrelease --all -n flux-system
    
    # Uninstall Flux
    echo "Uninstalling Flux components..."
    if [ "$DRY_RUN" = true ]; then
        echo -e "${CYAN}[DRY-RUN]${NC} Would uninstall Flux"
    else
        flux uninstall --silent 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✓ Flux cleanup complete${NC}"
}

# Cleanup NGINX Ingress
cleanup_nginx() {
    echo -e "${YELLOW}Cleaning up NGINX Ingress Controller...${NC}"
    
    status_message "This will remove the NGINX Ingress Controller."
    
    # Uninstall via Helm
    echo "Uninstalling NGINX Ingress..."
    if [ "$DRY_RUN" = true ]; then
        echo -e "${CYAN}[DRY-RUN]${NC} Would run: helm uninstall ingress-nginx -n ingress-nginx"
    else
        helm uninstall ingress-nginx -n ingress-nginx 2>/dev/null || true
    fi
    
    # Delete namespace
    echo "Removing NGINX namespace..."
    safe_delete delete namespace ingress-nginx
    
    echo -e "${GREEN}✓ NGINX Ingress cleanup complete${NC}"
}

# Cleanup Backstage Service Account
cleanup_backstage_sa() {
    echo -e "${YELLOW}Cleaning up Backstage Service Account...${NC}"
    
    status_message "This will remove the Backstage service account and tokens."
    
    echo "Removing Backstage service account resources..."
    safe_delete delete secret backstage-k8s-sa-token -n default
    safe_delete delete clusterrolebinding backstage-k8s-sa
    safe_delete delete clusterrole backstage-k8s-sa
    safe_delete delete serviceaccount backstage-k8s-sa -n default
    
    # Remove local config files
    if [ "$DRY_RUN" = false ]; then
        echo "Removing local Backstage config files..."
        rm -f ../app-portal/app-config.local.yaml 2>/dev/null || true
        rm -f ../app-portal/app-config.openportal.local.yaml 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✓ Backstage service account cleanup complete${NC}"
}

# Cleanup Environment Configs
cleanup_environment_configs() {
    echo -e "${YELLOW}Cleaning up Environment Configurations...${NC}"
    
    status_message "This will remove all platform environment configurations."
    
    echo "Removing EnvironmentConfigs..."
    safe_delete delete environmentconfig --all
    
    echo -e "${GREEN}✓ Environment configs cleanup complete${NC}"
}

# Cleanup Catalog Orders
cleanup_catalog_orders() {
    echo -e "${YELLOW}Cleaning up Catalog Orders GitOps configuration...${NC}"
    
    status_message "This will remove the catalog-orders Flux source and kustomization."
    
    echo "Removing catalog-orders GitRepository..."
    safe_delete delete gitrepository catalog-orders -n flux-system
    
    echo "Removing catalog-orders Kustomization..."
    safe_delete delete kustomization catalog-orders -n flux-system
    
    echo -e "${GREEN}✓ Catalog orders cleanup complete${NC}"
}

# Cleanup everything
cleanup_all() {
    echo -e "${RED}WARNING: This will remove ALL OpenPortal infrastructure components!${NC}"
    status_message "This action cannot be undone. All resources will be deleted."
    
    echo -e "${YELLOW}Starting complete cleanup...${NC}"
    echo ""
    
    # Order matters - clean up dependent resources first
    cleanup_catalog_orders
    cleanup_environment_configs
    cleanup_backstage_sa
    cleanup_cloudflare_provider
    cleanup_external_dns
    cleanup_crossplane
    cleanup_flux
    cleanup_nginx
    
    echo ""
    echo -e "${GREEN}=== Complete Cleanup Finished ===${NC}"
    echo "All OpenPortal infrastructure components have been removed."
}

# Main execution
case $COMPONENT in
    all)
        cleanup_all
        ;;
    cloudflare-provider)
        cleanup_cloudflare_provider
        ;;
    external-dns)
        cleanup_external_dns
        ;;
    crossplane)
        cleanup_crossplane
        ;;
    flux)
        cleanup_flux
        ;;
    nginx)
        cleanup_nginx
        ;;
    backstage-sa)
        cleanup_backstage_sa
        ;;
    environment-configs)
        cleanup_environment_configs
        ;;
    catalog-orders)
        cleanup_catalog_orders
        ;;
    *)
        echo -e "${RED}Error: Unknown component '$COMPONENT'${NC}"
        echo ""
        usage
        ;;
esac

echo ""
echo "Cleanup completed successfully!"
if [ "$DRY_RUN" = true ]; then
    echo -e "${CYAN}This was a dry run. No resources were actually deleted.${NC}"
    echo "Run without --dry-run to perform actual cleanup."
fi