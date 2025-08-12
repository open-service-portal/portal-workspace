#!/bin/bash

set -e

echo "Setting up Rancher Desktop with Crossplane for Backstage development..."
echo "============================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Rancher Desktop is installed
check_rancher_desktop() {
    if ! command -v rdctl &> /dev/null; then
        echo -e "${RED}Rancher Desktop is not installed.${NC}"
        echo "Please install Rancher Desktop first:"
        echo "  Download from: https://rancherdesktop.io/"
        echo "  macOS: brew install --cask rancher"
        echo "  Linux: Download the .deb or .rpm package from the website"
        exit 1
    fi
}

# Check if kubectl is installed
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}kubectl is not installed.${NC}"
        echo "kubectl should be included with Rancher Desktop."
        echo "Please ensure Rancher Desktop is properly installed and configured."
        exit 1
    fi
}

# Check if helm is installed
check_helm() {
    if ! command -v helm &> /dev/null; then
        echo -e "${RED}Helm is not installed.${NC}"
        echo "Please install Helm:"
        echo "  macOS: brew install helm"
        echo "  Linux: curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
        exit 1
    fi
}

# Start Rancher Desktop if not running
start_rancher_desktop() {
    echo "Checking Rancher Desktop status..."
    
    # Check if Rancher Desktop is running
    if ! rdctl version &> /dev/null; then
        echo -e "${YELLOW}Starting Rancher Desktop...${NC}"
        rdctl start
        
        # Wait for Rancher Desktop to be ready
        echo "Waiting for Rancher Desktop to be ready (this may take a few minutes)..."
        local retries=0
        local max_retries=60
        
        while ! kubectl get nodes &> /dev/null && [ $retries -lt $max_retries ]; do
            echo -n "."
            sleep 5
            ((retries++))
        done
        echo ""
        
        if [ $retries -eq $max_retries ]; then
            echo -e "${RED}Timeout waiting for Rancher Desktop to start.${NC}"
            echo "Please start Rancher Desktop manually and run this script again."
            exit 1
        fi
    fi
    
    echo -e "${GREEN}Rancher Desktop is running.${NC}"
}

# Configure Rancher Desktop settings
configure_rancher_desktop() {
    echo "Configuring Rancher Desktop settings..."
    
    # Set Kubernetes backend (dockerd or containerd)
    rdctl set --container-engine=containerd
    
    # Ensure Kubernetes is enabled
    rdctl set --kubernetes-enabled=true
    
    # Use the currently configured Kubernetes version
    # No need to override the version that Rancher Desktop already has configured
    
    # Disable Traefik to avoid conflicts with other ingress controllers
    echo "Disabling Traefik ingress controller..."
    rdctl set --kubernetes.options.traefik=false
    
    echo -e "${GREEN}Rancher Desktop configured (Traefik disabled).${NC}"
}

# Install Crossplane
install_crossplane() {
    echo ""
    echo "Installing Crossplane v1.17..."
    
    # Add Crossplane Helm repository
    helm repo add crossplane-stable https://charts.crossplane.io/stable
    helm repo update
    
    # Create crossplane-system namespace if it doesn't exist
    kubectl create namespace crossplane-system --dry-run=client -o yaml | kubectl apply -f -
    
    # Install Crossplane using Helm
    helm upgrade --install crossplane \
        --namespace crossplane-system \
        --version 1.17.0 \
        crossplane-stable/crossplane \
        --wait --timeout=5m
    
    echo -e "${GREEN}Crossplane installed successfully.${NC}"
}

# Check Crossplane CLI
check_crossplane_cli() {
    if ! command -v crossplane &> /dev/null; then
        echo -e "${YELLOW}Crossplane CLI is not installed (optional).${NC}"
        echo "To install Crossplane CLI:"
        echo "  macOS: brew install crossplane"
        echo "  Linux: curl -sL https://raw.githubusercontent.com/crossplane/crossplane/master/install.sh | sh"
        echo ""
        echo "Continuing without Crossplane CLI..."
    else
        echo -e "${GREEN}Crossplane CLI is installed.${NC}"
    fi
}

# Install provider-kubernetes
install_provider_kubernetes() {
    echo ""
    echo "Installing provider-kubernetes..."
    
    # Get the directory where the script is located
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    MANIFESTS_DIR="${SCRIPT_DIR}/rancher-k8s-manifests"
    
    # Apply provider configuration
    kubectl apply -f "${MANIFESTS_DIR}/provider-kubernetes.yaml"
    
    # Wait for provider to be healthy
    echo "Waiting for provider-kubernetes to be healthy..."
    kubectl wait --for=condition=Healthy provider/provider-kubernetes --timeout=300s
    
    # Create ProviderConfig
    kubectl apply -f "${MANIFESTS_DIR}/provider-config.yaml"
    
    echo -e "${GREEN}provider-kubernetes installed and configured.${NC}"
}

# Install NGINX Ingress Controller
install_nginx_ingress() {
    echo ""
    echo "Installing NGINX Ingress Controller..."
    
    # Add NGINX Ingress Helm repository
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    
    # Install NGINX Ingress
    # Note: Using NodePort for local development as LoadBalancer doesn't work properly in Rancher Desktop
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.service.type=NodePort \
        --set controller.service.ports.http=80 \
        --set controller.service.ports.https=443 \
        --set controller.service.nodePorts.http=30080 \
        --set controller.service.nodePorts.https=30443 \
        --wait --timeout=5m
    
    echo -e "${GREEN}NGINX Ingress Controller installed.${NC}"
    echo "Ingress will be available at: http://localhost:30080 (HTTP) and https://localhost:30443 (HTTPS)"
}

# Create service account for Backstage
create_backstage_service_account() {
    echo ""
    echo "Creating service account for Backstage..."
    
    # Create service account
    kubectl create serviceaccount backstage-k8s-sa -n default --dry-run=client -o yaml | kubectl apply -f -
    
    # Create secret for permanent token
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: backstage-k8s-sa-token
  namespace: default
  annotations:
    kubernetes.io/service-account.name: backstage-k8s-sa
type: kubernetes.io/service-account-token
EOF
    
    # Create cluster role binding
    kubectl create clusterrolebinding backstage-k8s-sa-binding \
        --clusterrole=cluster-admin \
        --serviceaccount=default:backstage-k8s-sa \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Wait for token to be generated
    sleep 2
    
    # Get the permanent token from the secret
    export K8S_SERVICE_ACCOUNT_TOKEN=$(kubectl get secret backstage-k8s-sa-token -n default -o jsonpath='{.data.token}' | base64 -d)
    
    echo -e "${GREEN}Service account created with permanent token.${NC}"
}

# Install Flux for GitOps
install_flux() {
    echo ""
    echo "Installing Flux for GitOps..."
    
    # Check if flux CLI is installed
    if ! command -v flux &> /dev/null; then
        echo "Installing Flux CLI..."
        curl -s https://fluxcd.io/install.sh | sh
        
        # Add to PATH if not already there
        if [[ ":$PATH:" != *":$HOME/.fluxcd/bin:"* ]]; then
            export PATH="$HOME/.fluxcd/bin:$PATH"
        fi
    fi
    
    # Check if Flux is already installed in cluster
    if kubectl get namespace flux-system &> /dev/null; then
        echo -e "${YELLOW}Flux is already installed in the cluster.${NC}"
        return
    fi
    
    # Try to find GitHub token from multiple sources
    local GITHUB_TOKEN=""
    
    # 1. Check GITHUB_TOKEN env var
    if [ -n "${GITHUB_TOKEN}" ]; then
        echo "Using GitHub token from GITHUB_TOKEN environment variable"
        GITHUB_TOKEN="${GITHUB_TOKEN}"
    # 2. Check FLUX_GITHUB_TOKEN env var
    elif [ -n "${FLUX_GITHUB_TOKEN}" ]; then
        echo "Using GitHub token from FLUX_GITHUB_TOKEN environment variable"
        GITHUB_TOKEN="${FLUX_GITHUB_TOKEN}"
    # 3. Check .envrc file
    elif [ -f "${SCRIPT_DIR}/../.envrc" ]; then
        source "${SCRIPT_DIR}/../.envrc" 2>/dev/null || true
        if [ -n "${GITHUB_TOKEN}" ]; then
            echo "Using GitHub token from .envrc file"
        fi
    # 4. Try GitHub CLI
    elif command -v gh &> /dev/null && gh auth token &> /dev/null; then
        echo "Using GitHub token from GitHub CLI (gh auth)"
        GITHUB_TOKEN=$(gh auth token)
    fi
    
    # If no token found, skip Flux installation
    if [ -z "$GITHUB_TOKEN" ]; then
        echo -e "${YELLOW}No GitHub token found. Skipping Flux installation.${NC}"
        echo ""
        echo "To install Flux later, you can:"
        echo "  1. Set GITHUB_TOKEN environment variable"
        echo "  2. Create .envrc file with: export GITHUB_TOKEN=ghp_xxxxx"
        echo "  3. Authenticate with GitHub CLI: gh auth login"
        echo "  4. Run manually: flux bootstrap github --owner=open-service-portal --repository=flux-system --path=clusters/local --personal"
        echo ""
        echo "Create a token at: https://github.com/settings/tokens/new (needs 'repo' scope)"
        return
    fi
    
    # Bootstrap Flux
    echo "Bootstrapping Flux..."
    if ! GITHUB_TOKEN=$GITHUB_TOKEN flux bootstrap github \
        --token-auth \
        --owner=open-service-portal \
        --repository=flux-system \
        --branch=main \
        --path=clusters/local \
        --personal; then
        echo -e "${YELLOW}Failed to bootstrap Flux. This might be due to:${NC}"
        echo "  - Token doesn't have access to the open-service-portal organization"
        echo "  - Repository already exists"
        echo "  - Network issues"
        echo ""
        echo "You can try bootstrapping to your personal account instead:"
        echo "  flux bootstrap github --owner=$(gh api user --jq .login 2>/dev/null || echo YOUR_GITHUB_USERNAME) --repository=flux-system --path=clusters/local --personal"
        return
    fi
    
    # Create auto-discovery for labeled repos
    echo "Setting up auto-discovery for Backstage-created services..."
    kubectl apply -f - <<EOF
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: backstage-services
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/open-service-portal
  ref:
    branch: main
  secretRef:
    name: flux-system
---
apiVersion: notification.toolkit.fluxcd.io/v1beta3
kind: Alert
metadata:
  name: backstage-services
  namespace: flux-system
spec:
  providerRef:
    name: generic-webhook
  eventSeverity: info
  eventSources:
    - kind: GitRepository
      name: backstage-services
  summary: 'Backstage service reconciliation'
EOF
    
    echo -e "${GREEN}Flux installed and configured for GitOps.${NC}"
}


# Print summary
print_summary() {
    echo ""
    echo "============================================================"
    echo -e "${GREEN}✅ Setup complete!${NC}"
    echo ""
    echo "Cluster Information:"
    echo "  Context: rancher-desktop"
    echo "  Kubernetes: $(kubectl version --short 2>/dev/null | grep Server | awk '{print $3}')"
    echo "  Crossplane: v1.17.0"
    if kubectl get namespace flux-system &> /dev/null; then
        echo "  Flux: $(flux version --client 2>/dev/null | grep flux | awk '{print $2}')"
    else
        echo "  Flux: Not installed (no GitHub token found)"
    fi
    echo ""
    echo "Kubeconfig Access:"
    echo "  Location: ~/.kube/config"
    echo "  Current context: $(kubectl config current-context)"
    echo "  API Server: https://127.0.0.1:6443"
    echo ""
    echo "To export kubeconfig:"
    echo "  export KUBECONFIG=~/.kube/config"
    echo ""
    echo "To use this cluster:"
    echo "  kubectl config use-context rancher-desktop"
    echo ""
    echo "To verify installation:"
    echo "  kubectl get pods -n crossplane-system"
    echo "  kubectl get providers"
    echo "  kubectl get crds | grep crossplane"
    if kubectl get namespace flux-system &> /dev/null; then
        echo "  kubectl get pods -n flux-system"
        echo "  flux get sources git"
        echo "  flux get kustomizations"
    fi
    echo ""
    echo "To run smoke tests:"
    echo "  See examples/crossplane-rancher-examples/README.md"
    echo ""
    echo "Backstage Configuration:"
    echo "  Service Account Token has been created."
    echo "  Add the following to your Backstage app-config.local.yaml:"
    echo ""
    echo "kubernetes:"
    echo "  serviceLocatorMethod:"
    echo "    type: 'multiTenant'"
    echo "  clusterLocatorMethods:"
    echo "    - type: 'config'"
    echo "      clusters:"
    echo "        - url: https://127.0.0.1:6443"
    echo "          name: rancher-desktop"
    echo "          authProvider: 'serviceAccount'"
    echo "          skipTLSVerify: true"
    echo "          serviceAccountToken: \${K8S_SERVICE_ACCOUNT_TOKEN}"
    echo ""
    echo "Export the token (add to .envrc):"
    echo "  export K8S_SERVICE_ACCOUNT_TOKEN='$K8S_SERVICE_ACCOUNT_TOKEN'"
    echo ""
    echo "To get the full kubeconfig for external access:"
    echo "  kubectl config view --raw > rancher-desktop-kubeconfig.yaml"
    echo "  export KUBECONFIG=\$(pwd)/rancher-desktop-kubeconfig.yaml"
    echo ""
    echo "Or programmatically access the cluster:"
    echo "  Server: https://127.0.0.1:6443"
    echo "  CA Certificate: kubectl config view --raw -o jsonpath='{.clusters[?(@.name==\"rancher-desktop\")].cluster.certificate-authority-data}' | base64 -d"
    echo "  Client Certificate: kubectl config view --raw -o jsonpath='{.users[0].user.client-certificate-data}' | base64 -d"
    echo "  Client Certificate: kubectl config view --raw -o jsonpath=\"{.users[?(@.name==\\\"\$(kubectl config view --raw -o jsonpath='{.contexts[?(@.name==\\\"\\$(kubectl config current-context)\\\")].context.user}')\\\")].user.client-certificate-data}\" | base64 -d"
    echo "  Client Key: kubectl config view --raw -o jsonpath=\"{.users[?(@.name==\\\"\$(kubectl config view --raw -o jsonpath='{.contexts[?(@.name==\\\"\\$(kubectl config current-context)\\\")].context.user}')\\\")].user.client-key-data}\" | base64 -d"
    echo ""
    echo "============================================================"
}

# Main execution
main() {
    echo ""
    
    # Run checks
    check_rancher_desktop
    check_kubectl
    check_helm
    
    # Start and configure Rancher Desktop
    start_rancher_desktop
    configure_rancher_desktop
    
    # Install components
    install_crossplane
    check_crossplane_cli
    install_provider_kubernetes
    
    # Install NGINX Ingress
    install_nginx_ingress
    
    # Create Backstage service account
    create_backstage_service_account
    
    # Install Flux for GitOps
    install_flux
    
    # Print summary
    print_summary
}

# Run main function
main