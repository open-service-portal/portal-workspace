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
CONFIG_FILE="${WORKSPACE_DIR}/app-portal/app-config/ingestor.yaml"
HAS_CONFIG_ARG=false

# Check if user already provided -c or --config
for arg in "$@"; do
    if [[ "$arg" == "-c" ]] || [[ "$arg" == "--config" ]]; then
        HAS_CONFIG_ARG=true
        break
    fi
done

# Delegate to the plugin script
# If config file exists and user didn't provide one, inject it
if [[ -f "$CONFIG_FILE" ]] && [[ "$HAS_CONFIG_ARG" == "false" ]]; then
    exec "$PLUGIN_SCRIPT" transform -c "$CONFIG_FILE" "$@"
else
    exec "$PLUGIN_SCRIPT" "$@"
fi
