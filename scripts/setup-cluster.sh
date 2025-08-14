#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Backstage Kubernetes Cluster Setup ===${NC}"
echo ""
echo "This script will install all required components for Backstage in your Kubernetes cluster."
echo ""

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}Error: kubectl is not installed${NC}"
        echo "Please install kubectl first: https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi
    
    # Check helm
    if ! command -v helm &> /dev/null; then
        echo -e "${RED}Error: helm is not installed${NC}"
        echo "Please install helm first: https://helm.sh/docs/intro/install/"
        exit 1
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
        echo "Please ensure you have a running cluster and kubectl is configured"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Prerequisites check passed${NC}"
    echo "  - kubectl: $(kubectl version --client -o json 2>/dev/null | grep gitVersion | cut -d'"' -f4 | head -1)"
    echo "  - helm: $(helm version --short)"
    echo "  - cluster: $(kubectl config current-context)"
    echo ""
}

# Configure SOPS for Flux
configure_sops_for_flux() {
    echo -e "${YELLOW}Configuring SOPS for Flux...${NC}"
    
    # Check if sops CLI is available
    if ! command -v sops &> /dev/null; then
        echo -e "${YELLOW}SOPS CLI not found locally${NC}"
        echo "To install SOPS CLI:"
        echo "  macOS: brew install sops"
        echo "  Linux: Download from https://github.com/getsops/sops/releases"
    else
        echo "SOPS CLI version: $(sops --check-for-updates --version)"
    fi
    
    # Check if age is available
    if ! command -v age &> /dev/null; then
        echo -e "${YELLOW}age not found locally${NC}"
        echo "To install age:"
        echo "  macOS: brew install age"
        echo "  Linux: Download from https://github.com/FiloSottile/age/releases"
    fi
    
    # Create namespace for Flux (needed for later)
    kubectl create namespace flux-system --dry-run=client -o yaml | kubectl apply -f -
    
    echo -e "${GREEN}✓ SOPS configuration info provided${NC}"
}

# Install NGINX Ingress Controller
install_nginx_ingress() {
    echo -e "${YELLOW}Installing NGINX Ingress Controller...${NC}"
    
    # Check if already installed
    if helm list -n ingress-nginx 2>/dev/null | grep -q ingress-nginx; then
        echo -e "${GREEN}✓ NGINX Ingress Controller already installed${NC}"
        return
    fi
    
    # Add NGINX Ingress Helm repository
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    
    # Install NGINX Ingress with LoadBalancer type
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.service.type=LoadBalancer \
        --wait --timeout=5m
    
    echo -e "${GREEN}✓ NGINX Ingress Controller installed${NC}"
    
    # Get ingress endpoint
    echo "Waiting for LoadBalancer IP/hostname..."
    sleep 10
    INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    INGRESS_HOST=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    
    if [ -n "$INGRESS_IP" ]; then
        echo "  Ingress IP: $INGRESS_IP"
    elif [ -n "$INGRESS_HOST" ]; then
        echo "  Ingress Hostname: $INGRESS_HOST"
    else
        echo "  Note: LoadBalancer pending. For local clusters, you may need to use NodePort or port-forward."
    fi
}

# Install Flux
install_flux() {
    echo -e "${YELLOW}Installing Flux...${NC}"
    
    # Check if already installed
    if kubectl get namespace flux-system &> /dev/null && \
       kubectl get deployments -n flux-system &> /dev/null && \
       [ $(kubectl get deployments -n flux-system --no-headers 2>/dev/null | wc -l) -gt 0 ]; then
        echo -e "${GREEN}✓ Flux already installed${NC}"
        return
    fi
    
    # Install Flux using the install manifests
    kubectl create namespace flux-system --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply Flux install manifests
    kubectl apply -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml
    
    # Wait for deployments to be created
    echo "Waiting for Flux deployments to be created..."
    sleep 5
    
    # Wait for each Flux component deployment
    for deployment in source-controller kustomize-controller helm-controller notification-controller; do
        echo "  Waiting for $deployment..."
        kubectl wait --namespace flux-system \
            --for=condition=available deployment/$deployment \
            --timeout=300s || {
            echo -e "${YELLOW}Warning: $deployment may need more time to become ready${NC}"
        }
    done

    echo -e "${GREEN}✓ Flux installed${NC}"
}

# Install Crossplane
install_crossplane() {
    echo -e "${YELLOW}Installing Crossplane v1.17...${NC}"
    
    # Check if already installed
    if helm list -n crossplane-system 2>/dev/null | grep -q crossplane; then
        echo -e "${GREEN}✓ Crossplane already installed${NC}"
        return
    fi
    
    # Add Crossplane Helm repository
    helm repo add crossplane-stable https://charts.crossplane.io/stable
    helm repo update
    
    # Create namespace
    kubectl create namespace crossplane-system --dry-run=client -o yaml | kubectl apply -f -
    
    # Install Crossplane
    helm upgrade --install crossplane \
        --namespace crossplane-system \
        --version 1.17.0 \
        crossplane-stable/crossplane \
        --wait --timeout=5m
    
    echo -e "${GREEN}✓ Crossplane installed${NC}"
}

# Install Crossplane provider-kubernetes
install_provider_kubernetes() {
    echo -e "${YELLOW}Installing Crossplane provider-kubernetes...${NC}"
    
    # Apply provider manifest
    MANIFEST_DIR="$(cd "$(dirname "$0")" && pwd)/cluster-manifests"
    PROVIDER_MANIFEST="$MANIFEST_DIR/provider-kubernetes.yaml"
    
    if [ ! -f "$PROVIDER_MANIFEST" ]; then
        echo -e "${RED}Error: Provider manifest not found at $PROVIDER_MANIFEST${NC}"
        echo "Please ensure cluster-manifests directory exists with required files"
        exit 1
    fi
    
    kubectl apply -f "$PROVIDER_MANIFEST"
    
    # Wait for provider to be healthy
    echo "Waiting for provider-kubernetes to be healthy..."
    kubectl wait --for=condition=Healthy provider.pkg.crossplane.io/provider-kubernetes --timeout=300s || {
        echo -e "${YELLOW}Provider may take additional time to become healthy${NC}"
    }
    
    # Apply ProviderConfig
    PROVIDER_CONFIG="$MANIFEST_DIR/provider-config.yaml"
    
    if [ ! -f "$PROVIDER_CONFIG" ]; then
        echo -e "${RED}Error: Provider config not found at $PROVIDER_CONFIG${NC}"
        echo "Please ensure cluster-manifests directory exists with required files"
        exit 1
    fi
    
    kubectl apply -f "$PROVIDER_CONFIG"
    
    echo -e "${GREEN}✓ provider-kubernetes installed and configured${NC}"
}

# Create Backstage service account
create_backstage_service_account() {
    echo -e "${YELLOW}Setting up Backstage service account...${NC}"
    
    # Check if service account already exists
    if kubectl get serviceaccount backstage-k8s-sa -n default &> /dev/null; then
        echo "Service account already exists"
        
        # Check if we have a valid token in environment
        if [ -n "${K8S_SERVICE_ACCOUNT_TOKEN}" ]; then
            echo "Using existing token from environment"
            export K8S_SERVICE_ACCOUNT_TOKEN="${K8S_SERVICE_ACCOUNT_TOKEN}"
        else
            # Check if there's a long-lived token secret (for older K8s versions)
            TOKEN_SECRET=$(kubectl get serviceaccount backstage-k8s-sa -n default -o jsonpath='{.secrets[0].name}' 2>/dev/null || echo "")
            if [ -n "${TOKEN_SECRET}" ] && [ "${TOKEN_SECRET}" != "null" ]; then
                echo "Found existing token secret: ${TOKEN_SECRET}"
                export K8S_SERVICE_ACCOUNT_TOKEN=$(kubectl get secret "${TOKEN_SECRET}" -n default -o jsonpath='{.data.token}' | base64 -d)
            else
                echo "Generating new token..."
                export K8S_SERVICE_ACCOUNT_TOKEN=$(kubectl create token backstage-k8s-sa -n default --duration=8760h)
            fi
        fi
    else
        # Create service account
        kubectl create serviceaccount backstage-k8s-sa -n default --dry-run=client -o yaml | kubectl apply -f -
        
        # Create cluster role binding
        kubectl create clusterrolebinding backstage-k8s-sa-binding \
            --clusterrole=cluster-admin \
            --serviceaccount=default:backstage-k8s-sa \
            --dry-run=client -o yaml | kubectl apply -f -
        
        # Generate new token
        echo "Generating new token for new service account..."
        export K8S_SERVICE_ACCOUNT_TOKEN=$(kubectl create token backstage-k8s-sa -n default --duration=8760h)
    fi
    
    echo -e "${GREEN}✓ Backstage service account ready${NC}"
}

# Print summary and configuration
print_summary() {
    echo ""
    echo "============================================================"
    echo -e "${GREEN}✅ Cluster setup complete!${NC}"
    echo ""
    echo "Installed components:"
    echo "  ✓ NGINX Ingress Controller"
    echo "  ✓ Flux GitOps"
    echo "  ✓ SOPS for secret management"
    echo "  ✓ Crossplane v1.17.0"
    echo "  ✓ provider-kubernetes"
    echo "  ✓ Backstage service account"
    echo ""
    echo "Cluster Information:"
    echo "  Context: $(kubectl config current-context)"
    echo "  API Server: $(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
    echo ""
    echo "Backstage Configuration:"
    echo "Add the following to your app-config.local.yaml:"
    echo ""
    echo "kubernetes:"
    echo "  serviceLocatorMethod:"
    echo "    type: 'multiTenant'"
    echo "  clusterLocatorMethods:"
    echo "    - type: 'config'"
    echo "      clusters:"
    echo "        - url: $(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
    echo "          name: $(kubectl config current-context)"
    echo "          authProvider: 'serviceAccount'"
    echo "          skipTLSVerify: true"
    echo "          serviceAccountToken: \${K8S_SERVICE_ACCOUNT_TOKEN}"
    echo ""
    echo "Environment Variable (add to .envrc):"
    echo "export K8S_SERVICE_ACCOUNT_TOKEN='$K8S_SERVICE_ACCOUNT_TOKEN'"
    echo ""
    echo "To verify installation:"
    echo "  kubectl get pods -n ingress-nginx"
    echo "  kubectl get pods -n flux-system"
    echo "  kubectl get secret -n flux-system sops-age"
    echo "  kubectl get pods -n crossplane-system"
    echo "  kubectl get providers.pkg.crossplane.io"
    echo ""
    echo "To deploy Backstage:"
    echo "  1. Encrypt secrets with SOPS: ./scripts/encrypt-secrets.sh"
    echo "  2. Apply manifests: kubectl apply -k deploy-backstage/overlays/development/"
    echo ""
    echo "============================================================"
}

# Main execution
main() {
    check_prerequisites
    install_nginx_ingress
    install_flux
    configure_sops_for_flux  # SOPS configuration info after Flux
    install_crossplane
    install_provider_kubernetes
    create_backstage_service_account
    print_summary
}

# Run main function
main