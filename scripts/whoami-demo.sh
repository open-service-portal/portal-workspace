#!/bin/bash
# Deploy/remove WhoAmI app using Crossplane template

set -e

ACTION=${1:-deploy}
NAME=${2:-whoami}
NAMESPACE=${3:-whoami-dev}

case "$ACTION" in
  deploy)
    echo "Deploying WhoAmI app: $NAME in namespace $NAMESPACE"
    kubectl apply -f - <<EOF
apiVersion: demo.openportal.dev/v1alpha1
kind: WhoAmIApp
metadata:
  name: $NAME
  namespace: $NAMESPACE
spec:
  name: $NAME
  replicas: 2
EOF
    echo "✓ Deployed $NAME"
    ;;
    
  remove)
    echo "Removing WhoAmI app: $NAME from namespace $NAMESPACE"
    kubectl delete whoamiapp $NAME -n $NAMESPACE --ignore-not-found
    echo "✓ Removed $NAME"
    ;;
    
  list)
    echo "WhoAmI app deployments:"
    kubectl get whoamiapp -A
    echo ""
    echo "DNS records:"
    kubectl get dnsrecord -A
    ;;
    
  *)
    echo "Usage: $0 [deploy|remove|list] [name] [namespace]"
    echo ""
    echo "Examples:"
    echo "  $0 deploy myapp default    # Deploy WhoAmI app"
    echo "  $0 remove myapp default    # Remove WhoAmI app"
    echo "  $0 list                    # List all deployments"
    exit 1
    ;;
esac