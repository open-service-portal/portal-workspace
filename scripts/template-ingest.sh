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

# Parse arguments to check for config flag
HAS_CONFIG_ARG=false
USER_CONFIG_FILE=""
PREV_ARG=""

for arg in "$@"; do
    # Check if user provided -c or --config
    if [[ "$PREV_ARG" == "-c" ]] || [[ "$PREV_ARG" == "--config" ]]; then
        HAS_CONFIG_ARG=true
        USER_CONFIG_FILE="$arg"
        break
    fi
    PREV_ARG="$arg"
done

# Determine config file to use
CONFIG_FILE=""
if [[ "$HAS_CONFIG_ARG" == "true" ]]; then
    # User provided config - use it as-is
    CONFIG_FILE="$USER_CONFIG_FILE"
else
    # Auto-detect config from workspace
    APP_PORTAL_DIR="${WORKSPACE_DIR}/app-portal"
    if [[ ! -d "$APP_PORTAL_DIR" ]]; then
        echo "Error: app-portal directory not found at: $APP_PORTAL_DIR" >&2
        echo "Either:" >&2
        echo "  1. Clone app-portal: git clone git@github.com:open-service-portal/app-portal.git" >&2
        echo "  2. Provide config manually: ./scripts/template-ingest.sh -c /path/to/config.yaml <input>" >&2
        exit 1
    fi

    CONFIG_FILE="${APP_PORTAL_DIR}/app-config/ingestor.yaml"
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "Error: Config file not found at: $CONFIG_FILE" >&2
        echo "Either:" >&2
        echo "  1. Ensure app-portal is properly set up with modular config" >&2
        echo "  2. Provide config manually: ./scripts/template-ingest.sh -c /path/to/config.yaml <input>" >&2
        exit 1
    fi
fi

# Delegate to the plugin script's transform command
# This wrapper is specifically for template transformation (XRD -> Backstage template)
# For other commands like 'init', call the plugin script directly: ingestor/scripts/xrd-transform.sh
if [[ "$HAS_CONFIG_ARG" == "true" ]]; then
    # User provided config, pass args as-is (config already in $@)
    exec "$PLUGIN_SCRIPT" transform "$@"
else
    # Inject auto-detected config
    exec "$PLUGIN_SCRIPT" transform -c "$CONFIG_FILE" "$@"
fi
