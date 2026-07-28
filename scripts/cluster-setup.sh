#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
CONFIG_UPDATED=false

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
    
    # Check yq
    if ! command -v yq &> /dev/null; then
        echo -e "${RED}Error: yq is not installed${NC}"
        echo "Please install yq first:"
        echo "  macOS: brew install yq"
        echo "  Linux: Download from https://github.com/mikefarah/yq"
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
    echo "  - yq: $(yq --version | cut -d' ' -f4)"
    echo "  - cluster: $(kubectl config current-context)"
    echo ""
}

# Bootstrap the Flux-managed cluster baseplate (Gateway API networking stack).
# Creates the GitRepository + root Kustomization that point Flux at
# ./clusters/openportal in this repo. Flux then reconciles the Gateway API
# CRDs, Traefik (GatewayClass "traefik"), the wildcard Gateway, and the
# gateway-config EnvironmentConfig.
#
# This replaces the retired ingress-nginx controller (EOL upstream 03/2026).
# See open-service-portal#139 and docs/decisions/2026-07-07-gitops-baseplate.md.
# NOTE: first GitOps slice — cert-manager, external-dns and Crossplane remain
# installed imperatively below and migrate to Flux in later slices.
bootstrap_flux_infrastructure() {
    echo -e "${YELLOW}Bootstrapping Flux-managed baseplate (Gateway API)...${NC}"

    local repo_url="${PLATFORM_REPO_URL:-https://github.com/open-service-portal/open-service-portal}"
    # Defaults to main. To test this baseplate BEFORE it is merged, point Flux at
    # the PR branch: PLATFORM_REPO_BRANCH=feat/gitops-baseplate ./cluster-setup.sh
    # (on main, ./clusters/openportal only exists once the PR has merged).
    local repo_branch="${PLATFORM_REPO_BRANCH:-main}"

    kubectl apply -f - <<EOF
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: platform
  namespace: flux-system
spec:
  interval: 5m
  url: ${repo_url}
  ref:
    branch: ${repo_branch}
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: cluster-openportal
  namespace: flux-system
spec:
  interval: 10m
  retryInterval: 1m
  timeout: 5m
  sourceRef:
    kind: GitRepository
    name: platform
  path: ./clusters/openportal
  prune: true
  wait: true
EOF

    echo -e "${GREEN}✓ Flux baseplate bootstrap applied (Traefik + Gateway API reconciling)${NC}"
}

# Install Flux
install_flux() {
    echo -e "${YELLOW}Installing Flux...${NC}"
    
    # Create namespace for Flux
    kubectl create namespace flux-system --dry-run=client -o yaml | kubectl apply -f -
    
    # Check if already installed
    if kubectl get deployments -n flux-system &> /dev/null && \
       [ $(kubectl get deployments -n flux-system --no-headers 2>/dev/null | wc -l) -gt 0 ]; then
        echo -e "${GREEN}✓ Flux already installed${NC}"
        return
    fi
    
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
    echo -e "${YELLOW}Installing Crossplane v2.0...${NC}"
    
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
        --version 2.0.0 \
        crossplane-stable/crossplane \
        --wait --timeout=5m
    
    echo -e "${GREEN}✓ Crossplane installed${NC}"
}

# Install Crossplane provider-kubernetes
install_provider_kubernetes() {
    echo -e "${YELLOW}Installing Crossplane provider-kubernetes...${NC}"
    
    # Apply provider manifest
    MANIFEST_DIR="$(cd "$(dirname "$0")" && pwd)/manifests/setup"
    PROVIDER_MANIFEST="$MANIFEST_DIR/crossplane-provider-kubernetes.yaml"
    
    if [ ! -f "$PROVIDER_MANIFEST" ]; then
        echo -e "${RED}Error: Provider manifest not found at $PROVIDER_MANIFEST${NC}"
        echo "Please ensure manifests/setup directory exists with required files"
        exit 1
    fi
    
    kubectl apply -f "$MANIFEST_DIR/crossplane-provider-kubernetes.yaml"
    
    # Wait for provider to be healthy
    echo "Waiting for provider-kubernetes to be healthy..."
    kubectl wait --for=condition=Healthy provider.pkg.crossplane.io/provider-kubernetes --timeout=300s || {
        echo -e "${YELLOW}Provider did not become healthy within the timeout period.${NC}"
        echo -e "${YELLOW}You can check the status with:${NC} kubectl get provider.pkg.crossplane.io provider-kubernetes"
        echo -e "${YELLOW}For more details, view the provider logs with:${NC} kubectl logs -l pkg.crossplane.io/provider=provider-kubernetes -n crossplane-system"
        echo -e "${YELLOW}If the issue persists, review your provider configuration and try reapplying the manifest.${NC}"
    }
    
    # Apply ProviderConfig for cluster-scoped API
    kubectl apply -f "$MANIFEST_DIR/crossplane-provider-kubernetes-config.yaml"
    
    # Apply ClusterProviderConfig for managed API (namespace-scoped, v2 compatible)
    echo "Applying ClusterProviderConfig for managed API..."
    kubectl apply -f "$MANIFEST_DIR/crossplane-provider-kubernetes-managed-config.yaml"
    
    # Apply RBAC for provider-kubernetes to manage all resources
    echo "Applying RBAC for provider-kubernetes..."
    kubectl apply -f "$MANIFEST_DIR/crossplane-provider-kubernetes-rbac.yaml"
    
    echo -e "${GREEN}✓ provider-kubernetes installed and configured with full RBAC${NC}"
    echo "  - Cluster-scoped API (kubernetes.crossplane.io) configured"
    echo "  - Managed API (kubernetes.m.crossplane.io) configured for namespaced XRs"
}

# Install cert-manager for TLS certificate management
install_cert_manager() {

    MANIFEST_DIR="$(cd "$(dirname "$0")" && pwd)/manifests/setup"
    CERT_MANAGER_VERSION="v1.18.2"

    echo -e "${YELLOW}Installing cert-manager for TLS certificates...${NC}"
    
    # Add Jetstack Helm repository
    helm repo add jetstack https://charts.jetstack.io --force-update
    helm repo update
    
    # Create namespace
    kubectl apply -f "$MANIFEST_DIR/cert-manager.yaml"
    
    # Install cert-manager with CRDs and default ClusterIssuer
    echo "Installing cert-manager $CERT_MANAGER_VERSION..."
    helm upgrade --install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --version "$CERT_MANAGER_VERSION" \
        --set crds.enabled=true \
        --set crds.keep=true \
        --set global.leaderElection.namespace=cert-manager \
        --set ingressShim.defaultIssuerName=letsencrypt-prod \
        --set ingressShim.defaultIssuerKind=ClusterIssuer \
        --wait --timeout=5m
    
    # Wait for cert-manager webhook to be ready (critical for issuer creation)
    echo "Waiting for cert-manager webhook to be ready..."
    kubectl wait --for=condition=ready pod \
        -l app.kubernetes.io/component=webhook \
        -n cert-manager \
        --timeout=60s || {
        echo -e "${YELLOW}Webhook may need more time to be ready${NC}"
    }
    
    echo -e "${GREEN}✓ cert-manager $CERT_MANAGER_VERSION installed${NC}"
    echo "  - CRDs installed for Certificate, ClusterIssuer, etc."
    echo "  - Webhook ready for validating resources"
    echo "  - Default ClusterIssuer: letsencrypt-prod (once configured)"
    echo "  - Ready for Let's Encrypt DNS-01 integration"
    
    # Note about ClusterIssuers
    echo -e "${YELLOW}Note: Let's Encrypt ClusterIssuer will be configured by cluster-config.sh${NC}"
}

# Install External-DNS for Cloudflare DNS management
install_external_dns() {
    echo -e "${YELLOW}Installing External-DNS with Cloudflare support...${NC}"
    
    # Apply External-DNS manifest with CRD and deployment
    MANIFEST_DIR="$(cd "$(dirname "$0")" && pwd)/manifests/setup"
    
    if [ ! -f "$MANIFEST_DIR/external-dns.yaml" ]; then
        echo -e "${RED}Error: External-DNS manifest not found at $MANIFEST_DIR/external-dns.yaml${NC}"
        exit 1
    fi
    
    kubectl apply -f "$MANIFEST_DIR/external-dns.yaml"
    
    # Wait for External-DNS deployment to be ready (with shorter timeout since credentials come later)
    echo "Waiting for External-DNS deployment to be ready (10s timeout)..."
    kubectl rollout status deployment/external-dns -n external-dns --timeout=10s || {
        echo -e "${YELLOW}⚠ External-DNS is not ready yet (this is expected if Cloudflare credentials are not configured)${NC}"
        echo -e "${YELLOW}External-DNS will start working after you run the cluster config script to add credentials.${NC}"
        echo -e "${YELLOW}You can check the status with:${NC} kubectl get deployment -n external-dns"
        echo -e "${YELLOW}Check logs with:${NC} kubectl logs -n external-dns deployment/external-dns"
    }
    
    echo -e "${GREEN}✓ External-DNS installed (configure Cloudflare credentials with config scripts)${NC}"
    echo "  - DNSEndpoint CRD created for namespaced DNS management"
    echo "  - External-DNS will sync DNSEndpoint resources to Cloudflare"
}

# Install Crossplane provider-helm
install_provider_helm() {
    echo -e "${YELLOW}Installing Crossplane provider-helm...${NC}"
    
    # Apply provider manifest
    MANIFEST_DIR="$(cd "$(dirname "$0")" && pwd)/manifests/setup"
    kubectl apply -f "$MANIFEST_DIR/crossplane-provider-helm.yaml"
    
    # Wait for provider to be healthy
    echo "Waiting for provider-helm to be healthy..."
    kubectl wait --for=condition=Healthy provider.pkg.crossplane.io/provider-helm --timeout=300s || {
        echo -e "${YELLOW}Provider did not become healthy within the timeout period.${NC}"
        echo -e "${YELLOW}You can check the status with:${NC} kubectl get provider.pkg.crossplane.io provider-helm"
        echo -e "${YELLOW}For more details, view the provider logs with:${NC} kubectl logs -l pkg.crossplane.io/provider=provider-helm -n crossplane-system"
        echo -e "${YELLOW}If the issue persists, review your provider configuration and try reapplying the manifest.${NC}"
    }
    
    # Apply ProviderConfig
    kubectl apply -f "$MANIFEST_DIR/crossplane-provider-helm-config.yaml"
    
    echo -e "${GREEN}✓ provider-helm installed and configured${NC}"
}

# Install the Valkey operator (supplier for ValkeyInstance templates)
install_valkey_operator() {
    # The Valkey operator is alpha/WIP (valkey.io/v1alpha1). We password-protect
    # the 'default' user (see template-valkey), which requires the probe-auth fix
    # #235 (probes connect as the '_operator' system user, not 'default'). That
    # fix is merged on main but NOT in any release yet (latest is v0.2.0), so we
    # build from a PINNED upstream commit and run that image, while still using
    # the pinned Helm chart for everything else.
    #   Revisit: switch back to a chart-version pin once a release > v0.2.0 ships
    #   #235, then this build-from-source step can be dropped.
    # See docs/specs/valkey-spike-findings.md.
    VALKEY_OPERATOR_GIT_REF="5ac4d51"        # v0.2.0-12, includes #235 (d184606); the tree we validated
    VALKEY_OPERATOR_CHART_VERSION="0.2.7"
    VALKEY_OPERATOR_IMAGE="valkey-operator:${VALKEY_OPERATOR_GIT_REF}"
    BUILD_DIR="$(cd "$(dirname "$0")/.." && pwd)/_work/build/valkey-operator"

    echo -e "${YELLOW}Installing Valkey operator (pinned @ ${VALKEY_OPERATOR_GIT_REF}, includes probe-auth #235)...${NC}"

    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Error: docker is required to build the pinned Valkey operator image${NC}"
        echo "Install docker, or skip this step until a release > v0.2.0 (with #235) is available."
        return 1
    fi

    # Build the image once (idempotent). NOTE: pullPolicy=Never means the image
    # must exist in the runtime the cluster uses. This works on rancher-desktop
    # (docker runtime). On kind/remote clusters, load/push the image instead
    # (e.g. `kind load docker-image` or push to a registry + adjust the override).
    if ! docker image inspect "$VALKEY_OPERATOR_IMAGE" >/dev/null 2>&1; then
        if [ ! -d "$BUILD_DIR/.git" ]; then
            mkdir -p "$(dirname "$BUILD_DIR")"
            git clone https://github.com/valkey-io/valkey-operator.git "$BUILD_DIR"
        fi
        git -C "$BUILD_DIR" fetch --quiet origin
        git -C "$BUILD_DIR" checkout --quiet "$VALKEY_OPERATOR_GIT_REF"
        echo "Building operator image ${VALKEY_OPERATOR_IMAGE} (this can take a few minutes)..."
        docker build -t "$VALKEY_OPERATOR_IMAGE" "$BUILD_DIR"
    else
        echo "  Image ${VALKEY_OPERATOR_IMAGE} already built, skipping build."
    fi

    helm repo add valkey https://valkey.io/valkey-helm
    helm repo update valkey
    helm upgrade --install valkey-operator valkey/valkey-operator \
        -n valkey-operator-system --create-namespace \
        --version "$VALKEY_OPERATOR_CHART_VERSION" \
        --set image.registry="" \
        --set global.imageRegistry="" \
        --set image.repository="valkey-operator" \
        --set image.tag="${VALKEY_OPERATOR_GIT_REF}" \
        --set image.pullPolicy=Never \
        --wait --timeout=5m
    echo -e "${GREEN}✓ Valkey operator installed (image ${VALKEY_OPERATOR_IMAGE}, chart ${VALKEY_OPERATOR_CHART_VERSION})${NC}"
}

# Install Crossplane composition functions
install_crossplane_functions() {
    echo -e "${YELLOW}Installing Crossplane composition functions...${NC}"
    
    MANIFEST_DIR="$(cd "$(dirname "$0")" && pwd)/manifests/setup"
    FUNCTIONS_MANIFEST="$MANIFEST_DIR/crossplane-functions.yaml"
    
    # Apply functions manifest
    kubectl apply -f "$FUNCTIONS_MANIFEST"
    
    # Wait for functions to be installed
    echo "Waiting for functions to be installed..."
    sleep 10
    
    # Check each function
    for function in function-go-templating function-patch-and-transform function-auto-ready function-environment-configs; do
        echo "  Checking $function..."
        kubectl wait --for=condition=Installed function.pkg.crossplane.io/$function --timeout=90s 2>/dev/null || {
            echo -e "${YELLOW}  $function is still installing...${NC}"
        }
    done
    
    echo -e "${GREEN}✓ Crossplane functions installed${NC}"
    echo "  - function-go-templating: Go templating for resource generation"
    echo "  - function-patch-and-transform: Traditional patching"
    echo "  - function-auto-ready: Automatic readiness"
    echo "  - function-environment-configs: Shared configurations"
}

# Install platform-wide environment configs
install_environment_configs() {
    echo -e "${YELLOW}Installing platform environment configurations...${NC}"
    
    MANIFEST_DIR="$(cd "$(dirname "$0")" && pwd)/manifests/setup"
    ENV_CONFIGS_MANIFEST="$MANIFEST_DIR/environment-configs.yaml"
    
    # Apply environment configs (CRD is included with Crossplane v2.0)
    kubectl apply -f "$ENV_CONFIGS_MANIFEST" && {
        echo -e "${GREEN}✓ Environment configurations installed${NC}"
        echo "  - dns-config: DNS zone settings for all templates"
        
        # Auto-detect and add ingress controller IP if available
        echo "Detecting ingress controller IP..."
        INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        
        if [ -n "$INGRESS_IP" ]; then
            echo "  Adding ingress IP to dns-config: $INGRESS_IP"
            kubectl patch environmentconfig dns-config --type merge -p "{\"data\": {\"ingressIP\": \"$INGRESS_IP\"}}" && {
                echo -e "${GREEN}  ✓ Ingress IP automatically configured${NC}"
            } || {
                echo -e "${YELLOW}  ⚠ Could not patch ingress IP (may retry later)${NC}"
            }
        else
            echo -e "${YELLOW}  ⚠ Ingress IP not yet available (LoadBalancer may be pending)${NC}"
            echo "  You can manually add it later with:"
            echo "  kubectl patch environmentconfig dns-config --type merge -p '{\"data\": {\"ingressIP\": \"YOUR_IP\"}}'"
        fi
    } || {
        echo -e "${RED}Error: Failed to apply environment configs${NC}"
        echo "Please check the error message above"
        return 1
    }
}

# Configure Flux to watch catalog repository
configure_flux_catalog() {
    echo -e "${YELLOW}Configuring Flux to watch Crossplane template catalog...${NC}"
    
    MANIFEST_DIR="$(cd "$(dirname "$0")" && pwd)/manifests/setup"
    FLUX_CATALOG_MANIFEST="$MANIFEST_DIR/flux-catalog.yaml"
    
    # Apply Flux catalog configuration
    kubectl apply -f "$FLUX_CATALOG_MANIFEST"
    
    # Wait a moment for the resources to be created
    sleep 2
    
    # Check if the GitRepository was created
    if kubectl get gitrepository catalog -n flux-system &>/dev/null; then
        echo -e "${GREEN}✓ Flux configured to watch catalog repository${NC}"
        echo "  Repository: https://github.com/open-service-portal/catalog"
        echo "  Sync interval: 1 minute"
    else
        echo -e "${YELLOW}Note: Flux catalog resources created but not yet syncing${NC}"
        echo "  This is normal if the catalog repository doesn't exist yet"
    fi
}


# Apply cluster-admin bindings for OIDC users from the checked-in list
apply_admin_bindings() {
    echo -e "${YELLOW}Applying cluster-admin bindings (manifests/users/admins.yaml)...${NC}"

    ADMINS_MANIFEST="$(cd "$(dirname "$0")" && pwd)/manifests/users/admins.yaml"

    if [ ! -f "$ADMINS_MANIFEST" ]; then
        echo -e "${YELLOW}⚠ No admins manifest found at $ADMINS_MANIFEST, skipping${NC}"
        return
    fi

    kubectl apply -f "$ADMINS_MANIFEST"

    echo -e "${GREEN}✓ Admin bindings applied${NC}"
    echo "  Manage the list via PR on manifests/users/admins.yaml"
    echo "  (rbac-add-admin.sh remains for one-off use — add its bindings to the file afterwards)"
}

# Create service account with persistent token
# Arguments:
#   $1 - Service account name (e.g., "backstage", "github-actions")
#   $2 - Description (e.g., "Persistent token for Backstage - shared by team")
create_service_account_with_token() {
    local SA_NAME="${1}"
    local SA_DESCRIPTION="${2}"

    # Validate required parameters
    if [ -z "$SA_NAME" ]; then
        echo -e "${RED}Error: Service account name is required${NC}"
        return 1
    fi
    if [ -z "$SA_DESCRIPTION" ]; then
        echo -e "${RED}Error: Service account description is required${NC}"
        return 1
    fi

    # Derive names from base name
    local SA_FULL_NAME="${SA_NAME}-k8s-sa"
    local BINDING_NAME="${SA_FULL_NAME}-binding"
    local SECRET_NAME="${SA_FULL_NAME}-token"

    echo -e "${YELLOW}Creating service account: ${SA_FULL_NAME}...${NC}"
    echo "  Purpose: ${SA_DESCRIPTION}"

    # Create service account (idempotent)
    kubectl create serviceaccount "$SA_FULL_NAME" -n default --dry-run=client -o yaml | kubectl apply -f -

    # Create cluster role binding (idempotent)
    kubectl create clusterrolebinding "$BINDING_NAME" \
        --clusterrole=cluster-admin \
        --serviceaccount="default:${SA_FULL_NAME}" \
        --dry-run=client -o yaml | kubectl apply -f -

    # Check for existing persistent token secret
    EXISTING_SECRET=$(kubectl get secret "$SECRET_NAME" -n default -o name 2>/dev/null || echo "")

    if [ -n "$EXISTING_SECRET" ]; then
        echo -e "${GREEN}✓ Found existing token secret in cluster: $SECRET_NAME${NC}"
        # Validate token is still working
        TOKEN=$(kubectl get secret "$SECRET_NAME" -n default -o jsonpath='{.data.token}' 2>/dev/null | base64 -d)
        if kubectl auth can-i get pods --token="$TOKEN" &>/dev/null; then
            echo -e "${GREEN}✓ Existing token is valid${NC}"
        else
            echo -e "${YELLOW}⚠ Existing token is invalid, recreating...${NC}"
            kubectl delete secret "$SECRET_NAME" -n default
            EXISTING_SECRET=""
        fi
    fi

    # Create persistent token secret if it doesn't exist
    if [ -z "$EXISTING_SECRET" ]; then
        echo "Creating persistent token secret..."

        # Export variables for envsubst
        export SA_NAME="$SA_NAME"
        export SA_DESCRIPTION="$SA_DESCRIPTION"

        # Apply the template with substituted values
        envsubst < "$MANIFEST_DIR/service-account-token-secret.template.yaml" | kubectl apply -f -

        # Wait for token to be populated
        echo -n "Waiting for token generation"
        for i in {1..10}; do
            TOKEN=$(kubectl get secret "$SECRET_NAME" -n default -o jsonpath='{.data.token}' 2>/dev/null | base64 -d)
            if [ -n "$TOKEN" ]; then
                echo -e " ${GREEN}✓${NC}"
                echo -e "${GREEN}✓ New token secret created${NC}"
                break
            fi
            echo -n "."
            sleep 1
        done
    fi

    echo -e "${GREEN}✓ Service account ${SA_FULL_NAME} ready${NC}"

    # Show specific instructions based on the service account type
    if [ "$SA_NAME" == "backstage" ]; then
        echo ""
        echo "Note: Run cluster-config.sh to configure Backstage for this cluster"
    else
        echo ""
        echo "Note: Extract the token with:"
        echo "  kubectl get secret ${SECRET_NAME} -n default -o jsonpath='{.data.token}' | base64 -d"
    fi
}

# Print summary and configuration
print_summary() {
    echo ""
    echo "============================================================"
    echo -e "${GREEN}✅ Cluster setup complete!${NC}"
    echo ""
    echo "Installed components:"
    echo "  ✓ Flux GitOps"
    echo "  ✓ Flux catalog watcher for Crossplane templates"
    echo "  ✓ Traefik + Gateway API baseplate (Flux-managed, replaces ingress-nginx)"
    echo "  ✓ Crossplane v2.0.0"
    echo "  ✓ provider-kubernetes (both cluster & managed APIs)"
    echo "  ✓ cert-manager with Let's Encrypt DNS-01 support"
    echo "  ✓ External-DNS with Cloudflare (configure with config scripts)"
    echo "  ✓ Crossplane composition functions"
    
    # Check if environment configs were installed
    if kubectl get environmentconfig dns-config &>/dev/null 2>&1; then
        echo "  ✓ Platform environment configurations"
    else
        echo "  ⚠ Platform environment configurations (pending CRD availability)"
    fi
    
    echo "  ✓ Backstage service account (with persistent token)"
    echo ""
    echo "Cluster Information:"
    echo "  Context: $(kubectl config current-context)"
    echo "  API Server: $(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
    echo ""
    echo "Next Steps:"
    echo ""
    echo "1. Configure Backstage for this cluster:"
    echo "     ./scripts/cluster-config.sh"
    echo ""
    echo "2. Start Backstage:"
    echo "   cd app-portal"
    echo "   yarn start          # For local cluster"
    echo "   yarn start:openportal  # For OpenPortal cluster"
    echo ""
    echo "To verify installation:"
    echo "  kubectl get pods -n flux-system"
    echo "  kubectl get gitrepository -n flux-system"
    echo "  kubectl get gatewayclass,gateway -A  # Traefik GatewayClass + wildcard Gateway"
    echo "  kubectl get pods -n traefik"
    echo "  kubectl get pods -n crossplane-system"
    echo "  kubectl get pods -n cert-manager"
    echo "  kubectl get providers.pkg.crossplane.io"
    echo "  kubectl get functions.pkg.crossplane.io"
    echo "  kubectl get clusterissuers  # After running cluster-config.sh with valid domain"
    echo ""
    echo ""
    echo "============================================================"
}

# Run cluster configuration if environment file exists
run_cluster_config() {
    echo ""
    echo -e "${BLUE}Checking for cluster configuration...${NC}"
    
    # Get current context
    CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "")
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"
    ENV_FILE="${WORKSPACE_DIR}/.env.${CURRENT_CONTEXT}"
    
    if [ -f "$ENV_FILE" ]; then
        echo -e "${GREEN}Environment file found: .env.${CURRENT_CONTEXT}${NC}"
        echo ""
        echo -e "${YELLOW}Running cluster configuration to set up credentials...${NC}"
        echo "============================================================"
        
        # Run the config script
        "${SCRIPT_DIR}/cluster-config.sh"
        
        echo ""
        echo -e "${GREEN}✅ Configuration applied successfully!${NC}"
        echo ""
    else
        echo -e "${YELLOW}No environment file found for context: ${CURRENT_CONTEXT}${NC}"
        echo ""
        echo "To configure credentials later:"
        echo "1. Create environment file:"
        echo -e "   ${GREEN}cp .env.rancher-desktop.example .env.${CURRENT_CONTEXT}${NC}"
        echo "2. Edit with your credentials:"
        echo -e "   ${GREEN}vim .env.${CURRENT_CONTEXT}${NC}"
        echo "3. Run configuration:"
        echo -e "   ${GREEN}./scripts/cluster-config.sh${NC}"
        echo ""
    fi
}

# Main execution
main() {
    check_prerequisites
    install_flux
    configure_flux_catalog  # Configure Flux to watch catalog
    bootstrap_flux_infrastructure  # Flux-managed Gateway API baseplate (replaces ingress-nginx)
    install_crossplane
    install_provider_kubernetes
    install_cert_manager  # Install cert-manager for TLS certificates
    install_external_dns
    install_provider_helm  # Install provider-helm for Helm chart deployments
    install_valkey_operator  # Install Valkey operator (ValkeyInstance supplier)
    install_crossplane_functions  # Install common functions
    install_environment_configs  # Install platform-wide configs
    create_service_account_with_token "backstage" "Persistent token for Backstage - shared by team"
    create_service_account_with_token "gha-app-portal-deploy" "GitHub Actions deployment for app-portal"
    apply_admin_bindings  # Cluster-admin bindings from manifests/users/admins.yaml
    print_summary
    run_cluster_config  # Run configuration if environment file exists
}

# Run main function
main