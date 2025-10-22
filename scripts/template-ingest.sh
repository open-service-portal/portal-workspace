#!/usr/bin/env bash
#
# Template Ingest - Workspace Wrapper
#
# This script delegates to the ingestor plugin's xrd-transform.sh script.
# The actual implementation is maintained in ingestor/scripts/
#
# Usage:
#   ./scripts/template-ingest.sh [options] [input]
#   cat xrd.yaml | ./scripts/template-ingest.sh [options]
#
# Examples:
#   # Transform XRD from file
#   ./scripts/template-ingest.sh template-namespace/configuration/xrd.yaml
#
#   # Transform from stdin
#   cat template-namespace/configuration/xrd.yaml | ./scripts/template-ingest.sh
#
#   # Verbose output
#   ./scripts/template-ingest.sh -v template-namespace/configuration/xrd.yaml
#
#   # Use debug template
#   ./scripts/template-ingest.sh -t debug template-namespace/configuration/xrd.yaml
#
# For full documentation and options, see:
#   ingestor/docs/xrd-transform-examples.md
#

set -euo pipefail

# Get the directory where this script is located (workspace scripts directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Find the ingestor plugin script
PLUGIN_SCRIPT="${WORKSPACE_DIR}/ingestor/scripts/xrd-transform.sh"

# Check if the plugin script exists
if [[ ! -f "$PLUGIN_SCRIPT" ]]; then
    echo "Error: Ingestor plugin script not found at: $PLUGIN_SCRIPT" >&2
    echo "Please ensure the ingestor plugin is installed at ingestor/" >&2
    exit 1
fi

# Auto-detect config file if not provided
HAS_CONFIG_ARG=false

# Check if user already provided -c or --config
for arg in "$@"; do
    if [[ "$arg" == "-c" ]] || [[ "$arg" == "--config" ]]; then
        HAS_CONFIG_ARG=true
        break
    fi
done

# Auto-inject config if available and not provided by user
CONFIG_ARGS=()
if [[ "$HAS_CONFIG_ARG" == "false" ]]; then
    APP_PORTAL_DIR="${WORKSPACE_DIR}/app-portal"
    if [[ -d "$APP_PORTAL_DIR" ]]; then
        CONFIG_FILE="${APP_PORTAL_DIR}/app-config/ingestor.yaml"
        if [[ -f "$CONFIG_FILE" ]]; then
            CONFIG_ARGS=("-c" "$CONFIG_FILE")
        fi
    fi
fi

# Delegate to the plugin script's transform command
# Note: This wrapper is specifically for template transformation (XRD -> Backstage template)
# For other commands like 'init', use the plugin script directly: ingestor/scripts/xrd-transform.sh
exec "$PLUGIN_SCRIPT" transform "${CONFIG_ARGS[@]}" "$@"
