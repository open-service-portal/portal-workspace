#!/usr/bin/env bash
#
# cluster-kubeconfig.sh - Import all kubectl contexts from a kubeconfig file
#
# Usage:
#   ./cluster-kubeconfig.sh [context]
#
# Description:
#   Imports ALL contexts, clusters, and users from a <context>.kubeconfig file
#   into your ~/.kube/config. This preserves all authentication types including:
#   - Token-based (service accounts)
#   - Exec-based (OIDC via kubectl oidc-login)
#   - Client certificate-based
#
#   If no context is provided, uses the current kubectl context to determine
#   which kubeconfig file to import from.
#
# Examples:
#   ./cluster-kubeconfig.sh openportal
#   # Imports from openportal.kubeconfig
#
#   ./cluster-kubeconfig.sh
#   # If current context is "osp-openportal-oidc", imports from openportal.kubeconfig
#
#   ./cluster-kubeconfig.sh rancher-desktop
#   # Imports from rancher-desktop.kubeconfig
#
# Safety:
#   - Creates automatic backup before merging
#   - Shows what will be imported before proceeding
#   - Non-destructive merge (preserves existing contexts)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get context name from argument or current context
if [[ -n "${1:-}" ]]; then
    CONTEXT="$1"
    echo -e "${BLUE}Using provided context: $CONTEXT${NC}"
else
    # Get current context from kubectl
    CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "")
    if [[ -z "$CURRENT_CONTEXT" ]]; then
        echo -e "${RED}❌ Error: No context provided and no current kubectl context set${NC}"
        echo "Usage: $0 [context]"
        echo ""
        echo "Available contexts:"
        kubectl config get-contexts 2>/dev/null || echo "  None"
        exit 1
    fi
    CONTEXT="$CURRENT_CONTEXT"
    echo -e "${BLUE}Using current context: $CONTEXT${NC}"
fi

# Derive kubeconfig filename from context
# Simply strips -oidc suffix and looks for matching file
# Examples:
#   osp-openportal-oidc -> osp-openportal.kubeconfig
#   osp-openportal -> osp-openportal.kubeconfig
#   rancher-desktop -> rancher-desktop.kubeconfig

# Define paths
KUBE_CONFIG_HOME="$HOME/.kube/config"

echo -e "${BLUE}📋 Kubeconfig Import Tool${NC}"
echo ""

# Strip -oidc suffix if present to get base context name
CONTEXT_BASE="${CONTEXT%-oidc}"
KUBECONFIG_FILE="${CONTEXT_BASE}.kubeconfig"

echo -e "${BLUE}Looking for: $KUBECONFIG_FILE${NC}"
echo ""

# Verify kubeconfig file exists
if [[ ! -f "$KUBECONFIG_FILE" ]]; then
    echo -e "${RED}❌ Error: $KUBECONFIG_FILE not found in current directory${NC}"
    echo ""
    echo "Context derivation:"
    echo "  Original context: $CONTEXT"
    echo "  Base context (stripped -oidc): $CONTEXT_BASE"
    echo "  Expected file: $KUBECONFIG_FILE"
    echo ""
    echo "Available kubeconfig files:"
    ls -1 *.kubeconfig 2>/dev/null | sed 's/^/   - /' || echo "   None found"
    exit 1
fi

echo -e "${GREEN}✓${NC} Found: $KUBECONFIG_FILE"
echo ""

# 2. Check if yq is available
if ! command -v yq &> /dev/null; then
    echo -e "${RED}❌ Error: yq is required but not installed${NC}"
    echo "   Install with: brew install yq"
    exit 1
fi

# 3. Show what will be imported
echo -e "${YELLOW}📦 Analyzing $KUBECONFIG_FILE...${NC}"
echo ""

# Get contexts that will be imported
CONTEXTS=$(yq '.contexts[].name' "$KUBECONFIG_FILE" 2>/dev/null)
CONTEXT_COUNT=$(echo "$CONTEXTS" | wc -l | tr -d ' ')

if [[ -z "$CONTEXTS" ]]; then
    echo -e "${RED}❌ Error: No contexts found in $KUBECONFIG_FILE${NC}"
    exit 1
fi

echo "   Contexts to import ($CONTEXT_COUNT):"
echo "$CONTEXTS" | while read -r ctx; do
    # Get cluster and user info for each context
    CLUSTER=$(yq ".contexts[] | select(.name == \"$ctx\") | .context.cluster" "$KUBECONFIG_FILE")
    USER=$(yq ".contexts[] | select(.name == \"$ctx\") | .context.user" "$KUBECONFIG_FILE")

    # Determine auth type
    HAS_TOKEN=$(yq ".users[] | select(.name == \"$USER\") | has(\"token\")" "$KUBECONFIG_FILE")
    HAS_EXEC=$(yq ".users[] | select(.name == \"$USER\") | has(\"exec\")" "$KUBECONFIG_FILE")
    HAS_CERT=$(yq ".users[] | select(.name == \"$USER\") | has(\"client-certificate-data\")" "$KUBECONFIG_FILE")

    if [[ "$HAS_TOKEN" == "true" ]]; then
        AUTH_TYPE="token"
    elif [[ "$HAS_EXEC" == "true" ]]; then
        AUTH_TYPE="exec (OIDC)"
    elif [[ "$HAS_CERT" == "true" ]]; then
        AUTH_TYPE="client-cert"
    else
        AUTH_TYPE="unknown"
    fi

    echo -e "   ${GREEN}✓${NC} $ctx"
    echo "     └─ cluster: $CLUSTER, user: $USER, auth: $AUTH_TYPE"
done

echo ""

# 4. Check for conflicts with existing contexts
if [[ -f "$KUBE_CONFIG_HOME" ]]; then
    echo -e "${YELLOW}🔍 Checking for existing contexts...${NC}"
    EXISTING_CONTEXTS=$(yq '.contexts[].name' "$KUBE_CONFIG_HOME" 2>/dev/null || echo "")

    CONFLICTS=""
    echo "$CONTEXTS" | while read -r ctx; do
        if echo "$EXISTING_CONTEXTS" | grep -q "^${ctx}$"; then
            echo -e "   ${YELLOW}⚠${NC}  $ctx (will be updated)"
            CONFLICTS="yes"
        fi
    done

    if [[ -z "$CONFLICTS" ]]; then
        echo "   No conflicts found - all contexts are new"
    fi
    echo ""
fi

# 5. Confirm before proceeding
echo -e "${YELLOW}❓ Proceed with import?${NC}"
echo "   This will merge contexts into ~/.kube/config"
read -p "   Continue? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}⏸  Import cancelled${NC}"
    exit 0
fi

# 6. Create backup
if [[ -f "$KUBE_CONFIG_HOME" ]]; then
    BACKUP_FILE="$KUBE_CONFIG_HOME.backup-$(date +%Y%m%d-%H%M%S)"
    cp "$KUBE_CONFIG_HOME" "$BACKUP_FILE"
    echo -e "${GREEN}💾 Backup created: $BACKUP_FILE${NC}"
else
    echo -e "${YELLOW}📝 No existing config - creating new file${NC}"
    mkdir -p "$(dirname "$KUBE_CONFIG_HOME")"
    touch "$KUBE_CONFIG_HOME"
fi

# 7. Merge kubeconfig files
echo -e "${BLUE}🔀 Merging kubeconfig files...${NC}"

# Use kubectl's built-in merge capability
TEMP_FILE="/tmp/merged-config.$$"
KUBECONFIG="$KUBECONFIG_FILE:$KUBE_CONFIG_HOME" kubectl config view --flatten > "$TEMP_FILE"

# Verify merge was successful
if [[ ! -s "$TEMP_FILE" ]]; then
    echo -e "${RED}❌ Error: Merge failed - temporary file is empty${NC}"
    echo "   Your original config is safe, no changes made"
    rm -f "$TEMP_FILE"
    exit 1
fi

# Replace config with merged version
mv "$TEMP_FILE" "$KUBE_CONFIG_HOME"
chmod 600 "$KUBE_CONFIG_HOME"

# 8. Verify import
echo ""
echo -e "${GREEN}✅ Import successful!${NC}"
echo ""
echo "Imported contexts:"
echo "$CONTEXTS" | while read -r ctx; do
    echo -e "  ${GREEN}✓${NC} $ctx"
done

echo ""
echo -e "${BLUE}📌 Next steps:${NC}"
echo "   List all contexts:    kubectl config get-contexts"
echo "   Switch context:       kubectl config use-context <name>"
echo "   View current config:  kubectl config view"
echo ""

# Show imported contexts in kubectl config
echo "Available contexts:"
kubectl config get-contexts
