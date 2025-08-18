#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DOMAIN="openportal.dev"
PROD_IP="50.56.157.82"  # Rackspace LoadBalancer IP

# Function to get ingress endpoint IP
get_ingress_ip() {
    # Try to get LoadBalancer IP
    local lb_ip=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    
    if [[ -n "$lb_ip" ]]; then
        echo "$lb_ip"
    else
        # No LoadBalancer, use localhost for local clusters
        echo "127.0.0.1"
    fi
}

case "$1" in
  deploy)
    echo -e "${GREEN}Deploying Podinfo...${NC}"
    
    # Create deployment and service
    kubectl create deployment podinfo --image=stefanprodan/podinfo --replicas=2
    kubectl expose deployment podinfo --port=9898 --type=NodePort
    
    # Get ingress IP to determine environment
    INGRESS_IP=$(get_ingress_ip)
    
    # Determine which domain to use
    if [[ "$INGRESS_IP" == "$PROD_IP" ]]; then
        # Production cluster - use real domain
        INGRESS_HOST="podinfo.${DOMAIN}"
        echo -e "${GREEN}Production cluster detected - using ${INGRESS_HOST}${NC}"
    else
        # Other cluster - use nip.io
        INGRESS_HOST="podinfo.${INGRESS_IP}.nip.io"
        echo -e "${YELLOW}Non-production cluster - using ${INGRESS_HOST}${NC}"
    fi
    
    # Create ingress with appropriate domain
    kubectl create ingress podinfo --class=nginx --rule="${INGRESS_HOST}/*=podinfo:9898"
    
    echo -e "${GREEN}Waiting for pods...${NC}"
    kubectl wait --for=condition=available --timeout=60s deployment/podinfo
    
    # Get NodePort as fallback
    NODE_PORT=$(kubectl get svc podinfo -o jsonpath='{.spec.ports[0].nodePort}')
    
    echo -e "${GREEN}✓ Podinfo deployed!${NC}"
    
    if [[ "$INGRESS_IP" == "127.0.0.1" ]]; then
        # Local cluster - need port-forward
        echo -e "${YELLOW}Local cluster detected - use port-forward for ingress:${NC}"
        echo "  1. Port-forward: kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80"
        echo "  2. Access at: http://${INGRESS_HOST}:8080"
        echo ""
        echo "  Or use NodePort directly: http://localhost:$NODE_PORT"
    elif [[ "$INGRESS_IP" == "$PROD_IP" ]]; then
        # Production with real domain
        echo "  Access at: http://${INGRESS_HOST}"
        echo -e "${YELLOW}  Note: DNS must be configured in Cloudflare${NC}"
        echo "  NodePort (backup): http://${INGRESS_IP}:$NODE_PORT"
    else
        # Other cloud cluster with nip.io
        echo "  Access at: http://${INGRESS_HOST}"
        echo "  NodePort (backup): http://${INGRESS_IP}:$NODE_PORT"
    fi
    ;;
    
  remove|delete)
    echo -e "${RED}Removing Podinfo...${NC}"
    kubectl delete ingress podinfo --ignore-not-found
    kubectl delete service podinfo --ignore-not-found
    kubectl delete deployment podinfo --ignore-not-found
    echo -e "${GREEN}✓ Podinfo removed${NC}"
    ;;
    
  status)
    echo -e "${YELLOW}Podinfo Status:${NC}"
    kubectl get deployment,service,ingress,pods -l app=podinfo
    
    # Show access URL if deployed
    if kubectl get ingress podinfo &>/dev/null; then
        INGRESS_HOST=$(kubectl get ingress podinfo -o jsonpath='{.spec.rules[0].host}')
        echo ""
        echo -e "${GREEN}Access URL: http://${INGRESS_HOST}${NC}"
    fi
    ;;
    
  url)
    # Quick command to just get the URL
    if kubectl get ingress podinfo &>/dev/null; then
        INGRESS_HOST=$(kubectl get ingress podinfo -o jsonpath='{.spec.rules[0].host}')
        echo "http://${INGRESS_HOST}"
    else
        echo "Podinfo not deployed or ingress not found"
        exit 1
    fi
    ;;
    
  *)
    echo "Usage: $0 {deploy|remove|status|url}"
    echo "  deploy - Deploy Podinfo app with nip.io ingress"
    echo "  remove - Remove Podinfo app"
    echo "  status - Check Podinfo status and URL"
    echo "  url    - Get the access URL"
    exit 1
    ;;
esac