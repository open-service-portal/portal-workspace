#!/usr/bin/env bash
#
# cluster-kubeconfig.sh - Update kubectl config from a context-specific kubeconfig file
#
# Usage:
#   ./cluster-kubeconfig.sh <context>
#
# Description:
#   Extracts cluster configuration and credentials from a <context>.kubeconfig file
#   and updates your ~/.kube/config with the information. 
#
# Examples:
#   ./cluster-kubeconfig.sh openportal     # Updates from openportal.kubeconfig
#   ./cluster-kubeconfig.sh rancher-desktop # Updates from rancher-desktop.kubeconfig

set -euo pipefail

# Get context name from argument
CONTEXT="${1:?Usage: $0 <context>}"

# Define paths
KUBECONFIG_FILE="${CONTEXT}.kubeconfig"
KUBE_CONFIG_HOME="$HOME/.kube/config"

# 1. Verify kubeconfig file exists
if [[ ! -f "$KUBECONFIG_FILE" ]]; then
    echo "❌ Error: $KUBECONFIG_FILE not found in current directory"
    echo "   Available kubeconfig files:"
    ls -1 *.kubeconfig 2>/dev/null | sed 's/^/   - /' || echo "   None found"
    exit 1
fi

# 2. Get cluster info from KUBECONFIG_FILE using yq
# First get the current context from the file
CURRENT_CONTEXT=$(yq '.current-context' "$KUBECONFIG_FILE")

# If no current context, try to use first context or match by name
if [[ "$CURRENT_CONTEXT" == "null" ]] || [[ -z "$CURRENT_CONTEXT" ]]; then
    # Try to find a context matching the CONTEXT name
    CURRENT_CONTEXT=$(yq ".contexts[] | select(.name == \"$CONTEXT\") | .name" "$KUBECONFIG_FILE")
    
    # If still not found, use the first context
    if [[ -z "$CURRENT_CONTEXT" ]]; then
        CURRENT_CONTEXT=$(yq '.contexts[0].name' "$KUBECONFIG_FILE")
    fi
fi

echo "   Using context: $CURRENT_CONTEXT"

# Get cluster and user names from the context
CLUSTER=$(yq ".contexts[] | select(.name == \"$CURRENT_CONTEXT\") | .context.cluster" "$KUBECONFIG_FILE")
USER=$(yq ".contexts[] | select(.name == \"$CURRENT_CONTEXT\") | .context.user" "$KUBECONFIG_FILE")

# Get cluster details using the cluster name
SERVER=$(yq ".clusters[] | select(.name == \"$CLUSTER\") | .cluster.server" "$KUBECONFIG_FILE")
CERT_DATA=$(yq ".clusters[] | select(.name == \"$CLUSTER\") | .cluster.certificate-authority-data" "$KUBECONFIG_FILE")

# Get user token using the user name
TOKEN=$(yq ".users[] | select(.name == \"$USER\") | .user.token" "$KUBECONFIG_FILE")

echo "   Cluster: $CLUSTER Server: $SERVER User: $USER"

# 3. Validate kubectl config exists for given context - create it if not
if ! kubectl config get-contexts "$CONTEXT" &>/dev/null; then
    echo "⚠️  Context $CONTEXT not found in kube config, creating it"
    # Create cluster without cert data first
    kubectl config set-cluster "$CONTEXT" --server="$SERVER"
    # Set certificate data separately
    kubectl config set clusters."$CONTEXT".certificate-authority-data "$CERT_DATA"
    # Create context
    kubectl config set-context "$CONTEXT" --cluster="$CONTEXT" --user="$USER"
fi

# 4. Update kubectl config with token
kubectl config set-credentials "$USER" --token="$TOKEN"
kubectl config use-context "$CONTEXT"
echo "✅ Updated kubectl config with $CONTEXT context"