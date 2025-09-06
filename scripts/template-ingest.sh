#!/bin/bash

#######################################
# XRD to Backstage Template Ingestor
# 
# Wrapper script for the kubernetes-ingestor plugin's CLI tool.
# Transforms Crossplane XRDs into Backstage Software Templates.
#
# Usage: ingestor.sh <source> [options]
#   source: XRD file, directory, or 'cluster'
#   options: --preview, --validate, --output, etc.
# 
# See: app-portal/plugins/kubernetes-ingestor/docs/CLI-USAGE.md
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
PLUGIN_DIR="$WORKSPACE_DIR/app-portal/plugins/kubernetes-ingestor"

# Check if plugin directory exists
if [ ! -d "$PLUGIN_DIR" ]; then
    echo -e "${RED}Error: Plugin directory not found at $PLUGIN_DIR${NC}"
    echo "Please ensure the app-portal repository is cloned in the workspace."
    exit 1
fi

# Check if the plugin is built
if [ ! -d "$PLUGIN_DIR/dist/cli" ]; then
    echo -e "${YELLOW}Plugin not built. Building now...${NC}"
    
    # Navigate to plugin directory
    cd "$PLUGIN_DIR"
    
    # Install dependencies if needed
    if [ ! -d "node_modules" ]; then
        echo "Installing dependencies..."
        yarn install
    fi
    
    # Build the plugin
    echo "Building plugin..."
    yarn build
    
    if [ ! -d "$PLUGIN_DIR/dist/cli" ]; then
        echo -e "${RED}Error: Failed to build plugin${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Plugin built successfully${NC}"
fi

# Save the original working directory
ORIGINAL_PWD="$(pwd)"

# Run the ingestor script with all arguments passed through
# The script needs to run from the plugin directory, but paths should be relative to user's PWD
cd "$PLUGIN_DIR"

# Convert relative paths to absolute paths based on original PWD
ARGS=()
for arg in "$@"; do
    # Check if argument is a file/directory path (not a flag)
    if [[ ! "$arg" =~ ^- ]] && [[ -e "$ORIGINAL_PWD/$arg" || "$arg" =~ ^[./] ]]; then
        # Convert relative path to absolute
        if [[ "$arg" = /* ]]; then
            # Already absolute
            ARGS+=("$arg")
        else
            # Make it absolute based on original PWD
            ARGS+=("$ORIGINAL_PWD/$arg")
        fi
    else
        ARGS+=("$arg")
    fi
done

node src/cli/ingestor.js "${ARGS[@]}"