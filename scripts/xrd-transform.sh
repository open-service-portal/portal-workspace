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

# Save the user's current working directory
USER_CWD="$(pwd)"

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

# Process arguments and convert relative paths to absolute
ARGS=()
PREV_ARG=""

for arg in "$@"; do
    # Check if previous argument was an option that takes a path
    if [[ "$PREV_ARG" == "-o" ]] || [[ "$PREV_ARG" == "--output" ]] || \
       [[ "$PREV_ARG" == "-t" ]] || [[ "$PREV_ARG" == "--templates" ]]; then
        # This is a path argument, make it absolute if relative
        if [[ ! "$arg" =~ ^/ ]]; then
            ARGS+=("${USER_CWD}/${arg}")
        else
            ARGS+=("$arg")
        fi
    # If it's a non-option argument (input file), make it absolute
    elif [[ ! "$arg" =~ ^- ]]; then
        # Try relative to user's CWD first
        if [[ -f "${USER_CWD}/${arg}" ]]; then
            ARGS+=("${USER_CWD}/${arg}")
        # Try relative to workspace
        elif [[ -f "${WORKSPACE_DIR}/${arg}" ]]; then
            ARGS+=("${WORKSPACE_DIR}/${arg}")
        # Use as-is (absolute or doesn't exist)
        else
            ARGS+=("$arg")
        fi
    else
        # Regular option, pass through
        ARGS+=("$arg")
    fi
    PREV_ARG="$arg"
done

# Run the CLI via ts-node
npx ts-node --project tsconfig.cli.json \
    src/xrd-transform/cli/xrd-transform-cli.ts \
    "${ARGS[@]}"
