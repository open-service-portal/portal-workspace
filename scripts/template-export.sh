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

# Delegate to the plugin script, forwarding all arguments
exec "$PLUGIN_SCRIPT" "$@"
