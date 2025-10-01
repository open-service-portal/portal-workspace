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
#   # Use debug template
#   ./scripts/xrd-transform.sh -t debug template-namespace/configuration/xrd.yaml
#
#   # Use custom template directory
#   ./scripts/xrd-transform.sh --template-path my-templates template-namespace/configuration/xrd.yaml
#
# Options:
#   -t, --template <name>    Template name to use (e.g., "debug", "default") - overrides XRD annotation
#   --template-path <dir>    Template directory path (defaults to built-in templates)
#   -o, --output <dir>       Output directory (default: stdout)
#   -f, --format <format>    Output format (yaml|json) (default: yaml)
#   --only <type>            Only generate specific entity type (template|api)
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
OUTPUT_DIR=""

for arg in "$@"; do
    # Check if previous argument was an option that takes a path
    if [[ "$PREV_ARG" == "-o" ]] || [[ "$PREV_ARG" == "--output" ]] || \
       [[ "$PREV_ARG" == "--template-path" ]]; then
        # This is a path argument, make it absolute if relative
        if [[ ! "$arg" =~ ^/ ]]; then
            ARGS+=("${USER_CWD}/${arg}")
            # Save output directory for creation
            if [[ "$PREV_ARG" == "-o" ]] || [[ "$PREV_ARG" == "--output" ]]; then
                OUTPUT_DIR="${USER_CWD}/${arg}"
            fi
        else
            ARGS+=("$arg")
            # Save output directory for creation
            if [[ "$PREV_ARG" == "-o" ]] || [[ "$PREV_ARG" == "--output" ]]; then
                OUTPUT_DIR="$arg"
            fi
        fi
    # -t is now template name, not a path - pass through as-is
    elif [[ "$PREV_ARG" == "-t" ]] || [[ "$PREV_ARG" == "--template" ]]; then
        ARGS+=("$arg")
    # If it's a non-option argument (input file or directory), make it absolute
    elif [[ ! "$arg" =~ ^- ]]; then
        # Try relative to user's CWD first (file or directory)
        if [[ -e "${USER_CWD}/${arg}" ]]; then
            ARGS+=("${USER_CWD}/${arg}")
        # Try relative to workspace
        elif [[ -e "${WORKSPACE_DIR}/${arg}" ]]; then
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

# Create output directory if specified and doesn't exist
if [[ -n "$OUTPUT_DIR" ]] && [[ ! -d "$OUTPUT_DIR" ]]; then
    mkdir -p "$OUTPUT_DIR"
fi

# Run the CLI via ts-node
npx ts-node --project tsconfig.cli.json \
    src/xrd-transform/cli/xrd-transform-cli.ts \
    "${ARGS[@]}"
