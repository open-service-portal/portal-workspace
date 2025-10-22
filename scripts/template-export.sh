#!/usr/bin/env bash
#
# Template Export - Workspace Wrapper
#
# This script delegates to the ingestor plugin's backstage-export.sh script.
# The actual implementation is maintained in ingestor/scripts/
#
# Usage:
#   ./scripts/template-export.sh [options]
#
# Examples:
#   # Export all templates
#   ./scripts/template-export.sh --kind Template
#
#   # Export with filters
#   ./scripts/template-export.sh --kind Template --tags crossplane --organize
#
#   # Preview what would be exported
#   ./scripts/template-export.sh --preview --kind Template,API
#
#   # List all APIs
#   ./scripts/template-export.sh --list --kind API
#
# For full documentation and options, see:
#   ingestor/docs/cli-export.md
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory where this script is located (workspace scripts directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Find the ingestor plugin script
PLUGIN_SCRIPT="${WORKSPACE_DIR}/ingestor/scripts/backstage-export.sh"

# Check if the plugin script exists
if [[ ! -f "$PLUGIN_SCRIPT" ]]; then
    echo "Error: Ingestor plugin script not found at: $PLUGIN_SCRIPT" >&2
    echo "Please ensure the ingestor plugin is installed at ingestor/" >&2
    exit 1
fi

# Auto-detect API token from context-specific config if not already set
if [ -z "${BACKSTAGE_TOKEN:-}" ]; then
    APP_PORTAL_DIR="${WORKSPACE_DIR}/app-portal"

    if [ -d "$APP_PORTAL_DIR" ]; then
        # Auto-detect kubectl context to find the correct config file
        KUBECTL_CONTEXT=""
        if command -v kubectl &> /dev/null; then
            KUBECTL_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "")
            if [ -n "$KUBECTL_CONTEXT" ]; then
                echo -e "${GREEN}Detected kubectl context: ${KUBECTL_CONTEXT}${NC}" >&2
            fi
        fi

        # Look for API token in context-specific config file first
        if [ -n "$KUBECTL_CONTEXT" ]; then
            CONTEXT_CONFIG="$APP_PORTAL_DIR/app-config.${KUBECTL_CONTEXT}.local.yaml"
            if [ -f "$CONTEXT_CONFIG" ]; then
                TOKEN=$(grep -A3 "type: static" "$CONTEXT_CONFIG" 2>/dev/null | grep "token:" | awk -F': ' '{print $2}' | head -1)
                if [ -n "$TOKEN" ]; then
                    export BACKSTAGE_TOKEN="$TOKEN"
                    echo -e "${GREEN}✓ Auto-detected API token from app-config.${KUBECTL_CONTEXT}.local.yaml${NC}" >&2
                fi
            else
                echo -e "${YELLOW}Warning: Context-specific config not found: app-config.${KUBECTL_CONTEXT}.local.yaml${NC}" >&2
            fi
        fi

        # Fall back to searching all app-config.*.local.yaml files if no context or no token found
        if [ -z "${BACKSTAGE_TOKEN:-}" ]; then
            echo -e "${YELLOW}Searching all app-config.*.local.yaml files...${NC}" >&2
            for config in "$APP_PORTAL_DIR"/app-config.*.local.yaml; do
                if [ -f "$config" ]; then
                    TOKEN=$(grep -A3 "type: static" "$config" 2>/dev/null | grep "token:" | awk -F': ' '{print $2}' | head -1)
                    if [ -n "$TOKEN" ]; then
                        export BACKSTAGE_TOKEN="$TOKEN"
                        echo -e "${GREEN}✓ Auto-detected API token from $(basename "$config")${NC}" >&2
                        break
                    fi
                fi
            done
        fi

        if [ -z "${BACKSTAGE_TOKEN:-}" ]; then
            echo -e "${YELLOW}Warning: No API token found in ${APP_PORTAL_DIR}${NC}" >&2
            echo -e "${YELLOW}Set BACKSTAGE_TOKEN or use --token flag${NC}" >&2
        fi
    fi
fi

# Delegate to the plugin script, forwarding all arguments
exec "$PLUGIN_SCRIPT" "$@"
