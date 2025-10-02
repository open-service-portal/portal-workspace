#!/bin/bash

#######################################
# XRD to Backstage Template Ingestor
#
# Wrapper script for the ingestor plugin's CLI tool.
# Transforms Crossplane XRDs into Backstage Software Templates
# using a unified ingestion engine.
#
# Usage: template-ingest.sh <source> [options]
#   source: XRD file, directory, or '-' for stdin
#   options: --preview, --validate, --output, etc.
#
# See: app-portal/plugins/ingestor/docs/CLI-INGESTOR-SPEC.md
#######################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"
PLUGIN_DIR="$WORKSPACE_DIR/app-portal/plugins/ingestor"

# Check if plugin directory exists
if [ ! -d "$PLUGIN_DIR" ]; then
    echo -e "${RED}Error: Plugin directory not found at $PLUGIN_DIR${NC}"
    echo "Please ensure the ingestor plugin is cloned in app-portal/plugins/"
    exit 1
fi

# Save the original working directory
ORIGINAL_PWD="$(pwd)"

# Default values
OUTPUT_DIR="templates"      # Default: templates directory
SOURCE=""          # Required: XRD file, directory, or 'cluster'
PREVIEW=false      # Show preview without writing files
VALIDATE=false     # Validate XRDs only
HELP=false         # Show help message

# Parse arguments
ARGS=()
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -p|--preview)
            PREVIEW=true
            ARGS+=("--preview")
            shift
            ;;
        -v|--validate)
            VALIDATE=true
            ARGS+=("--validate")
            shift
            ;;
        -h|--help)
            HELP=true
            ARGS+=("--help")
            shift
            ;;
        -*)
            # Unknown flag, pass through to ingestor
            ARGS+=("$1")
            shift
            ;;
        *)
            # This is the source argument (file, directory, or 'cluster')
            if [[ -z "$SOURCE" ]]; then
                SOURCE="$1"
            else
                # Additional non-flag argument, pass through
                ARGS+=("$1")
            fi
            shift
            ;;
    esac
done

# Convert source path to absolute if it's a file/directory
if [[ -n "$SOURCE" ]]; then
    if [[ "$SOURCE" == "-" ]]; then
        # Special case for stdin
        ARGS+=("-")
    elif [[ "$SOURCE" = /* ]]; then
        # Already absolute
        ARGS+=("$SOURCE")
    elif [[ -e "$ORIGINAL_PWD/$SOURCE" ]]; then
        # Convert relative to absolute based on original PWD
        ARGS+=("$ORIGINAL_PWD/$SOURCE")
    else
        # Pass as-is (might be a pattern or special value)
        ARGS+=("$SOURCE")
    fi
fi

# Handle output directory
if [[ -n "$OUTPUT_DIR" ]]; then
    # User specified output, convert to absolute if relative
    if [[ "$OUTPUT_DIR" = /* ]]; then
        ARGS+=("--output" "$OUTPUT_DIR")
    else
        ARGS+=("--output" "$ORIGINAL_PWD/$OUTPUT_DIR")
    fi
else
    # Default to current working directory
    ARGS+=("--output" "$ORIGINAL_PWD")
fi

# Run the ingestor CLI directly from source using ts-node
cd "$PLUGIN_DIR"
# echo "Args: ${ARGS[*]}"
npx ts-node --project tsconfig.cli.json src/cli/ingestor-cli.ts "${ARGS[@]}"