#!/usr/bin/env bash
#
# XRD Transform - Workspace Wrapper
#
# This script delegates to the ingestor plugin's xrd-transform.sh script.
# The actual implementation is maintained in app-portal/plugins/ingestor/scripts/
#
# Usage:
#   ./scripts/xrd-transform.sh [options] [input]
#   cat xrd.yaml | ./scripts/xrd-transform.sh [options]
#
# Examples:
#   # Transform from file
#   ./scripts/xrd-transform.sh template-namespace/configuration/xrd.yaml
#
#   # Transform from stdin
#   cat template-namespace/configuration/xrd.yaml | ./scripts/xrd-transform.sh
#
#   # Verbose output
#   ./scripts/xrd-transform.sh -v template-namespace/configuration/xrd.yaml
#
#   # Use debug template
#   ./scripts/xrd-transform.sh -t debug template-namespace/configuration/xrd.yaml
#
# For full documentation and options, see:
#   app-portal/plugins/ingestor/docs/xrd-transform/
#

set -euo pipefail

# Get the directory where this script is located (workspace scripts directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Find the ingestor plugin script
PLUGIN_SCRIPT="${WORKSPACE_DIR}/app-portal/plugins/ingestor/scripts/xrd-transform.sh"

# Check if the plugin script exists
if [[ ! -f "$PLUGIN_SCRIPT" ]]; then
    echo "Error: Ingestor plugin script not found at: $PLUGIN_SCRIPT" >&2
    echo "Please ensure the ingestor plugin is installed at app-portal/plugins/ingestor/" >&2
    exit 1
fi

# Delegate to the plugin script, forwarding all arguments
exec "$PLUGIN_SCRIPT" "$@"
