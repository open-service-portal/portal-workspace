#!/usr/bin/env bash
#
# XRD Transform - Transform Crossplane XRDs into Backstage templates
#
# This script wraps the xrd-transform CLI tool from the ingestor plugin,
# allowing you to run it from anywhere in the workspace.
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
#   # Save to file
#   ./scripts/xrd-transform.sh template-namespace/configuration/xrd.yaml > output.yaml
#
#   # Use custom templates
#   ./scripts/xrd-transform.sh -t my-templates template-namespace/configuration/xrd.yaml
#
# Options:
#   -t, --templates <dir>    Template directory (defaults to built-in templates)
#   -o, --output <dir>       Output directory (default: stdout)
#   -f, --format <format>    Output format (yaml|json) (default: yaml)
#   --single-file            Output all entities to a single file
#   --organize               Organize output by entity type
#   -v, --verbose            Verbose output
#   --validate               Validate output
#   --watch                  Watch for changes (when input is directory)
#   -h, --help               Display help
#

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PLUGIN_DIR="${WORKSPACE_DIR}/app-portal/plugins/ingestor"

# Check if plugin directory exists
if [[ ! -d "${PLUGIN_DIR}" ]]; then
    echo "Error: Ingestor plugin not found at ${PLUGIN_DIR}" >&2
    echo "Please ensure you're running this from the portal-workspace directory" >&2
    exit 1
fi

# Change to plugin directory (required for ts-node and template resolution)
cd "${PLUGIN_DIR}"

# Collect all arguments
ARGS=()
for arg in "$@"; do
    # If argument is a file path and not an option, make it absolute
    if [[ ! "$arg" =~ ^- ]] && [[ -f "${WORKSPACE_DIR}/${arg}" ]]; then
        ARGS+=("${WORKSPACE_DIR}/${arg}")
    else
        ARGS+=("$arg")
    fi
done

# Run the CLI via ts-node
npx ts-node --project tsconfig.cli.json \
    src/xrd-transform/cli/xrd-transform-cli.ts \
    "${ARGS[@]}"
