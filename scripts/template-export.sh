#!/bin/bash

# Backstage Template Export Tool
#
# Fetches templates and API entities from a running Backstage instance
# using the ingestor plugin's export CLI tool
# Usage: template-export.sh [options]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Find workspace root
WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_DIR="$WORKSPACE_ROOT/app-portal/plugins/ingestor"

# Auto-detect API token from Backstage config if not provided
if [ -z "$BACKSTAGE_TOKEN" ]; then
    # Try to find token from local config files
    for config in "$WORKSPACE_ROOT/app-portal"/app-config.*.local.yaml; do
        if [ -f "$config" ]; then
            TOKEN=$(grep -A3 "type: static" "$config" 2>/dev/null | grep "token:" | awk -F': ' '{print $2}' | head -1)
            if [ -n "$TOKEN" ]; then
                export BACKSTAGE_TOKEN="$TOKEN"
                echo -e "${GREEN}✓ Auto-detected API token from $(basename "$config")${NC}"
                break
            fi
        fi
    done
    
    if [ -z "$BACKSTAGE_TOKEN" ]; then
        echo -e "${YELLOW}Warning: No API token found. Set BACKSTAGE_TOKEN or use --token flag${NC}"
    fi
fi

# Default values
OUTPUT_DIR="exported"
ARGS=()

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            OUTPUT_DIR="$2"
            ARGS+=("--output" "$2")
            shift 2
            ;;
        -k|--kind)
            ARGS+=("--kind" "$2")
            shift 2
            ;;
        -u|--url)
            ARGS+=("--url" "$2")
            shift 2
            ;;
        -t|--token)
            export BACKSTAGE_TOKEN="$2"
            ARGS+=("--token" "$2")
            shift 2
            ;;
        --organize)
            ARGS+=("--organize")
            shift
            ;;
        --manifest)
            ARGS+=("--manifest")
            shift
            ;;
        -p|--preview)
            ARGS+=("--preview")
            shift
            ;;
        -l|--list)
            ARGS+=("--list")
            shift
            ;;
        --tags)
            ARGS+=("--tags" "$2")
            shift 2
            ;;
        --namespace)
            ARGS+=("--namespace" "$2")
            shift 2
            ;;
        --owner)
            ARGS+=("--owner" "$2")
            shift 2
            ;;
        --name)
            ARGS+=("--name" "$2")
            shift 2
            ;;
        -h|--help)
            echo "Backstage Template Export Tool"
            echo ""
            echo "Usage: template-export.sh [options]"
            echo ""
            echo "Options:"
            echo "  -o, --output <dir>     Output directory (default: exported)"
            echo "  -k, --kind <kinds>     Entity kinds (comma-separated)"
            echo "  -u, --url <url>        Backstage URL (default: http://localhost:7007)"
            echo "  -t, --token <token>    API token (or auto-detected from config)"
            echo "  --namespace <ns>       Namespace filter"
            echo "  --name <pattern>       Name pattern (supports wildcards)"
            echo "  --owner <owner>        Owner filter"
            echo "  --tags <tags>          Tags filter (comma-separated)"
            echo "  --organize             Organize output by entity type"
            echo "  --manifest             Generate export manifest file"
            echo "  -p, --preview          Preview what would be exported"
            echo "  -l, --list             List matching entities only"
            echo "  -h, --help             Show this help message"
            echo ""
            echo "Examples:"
            echo "  # Export all templates"
            echo "  template-export.sh --kind Template"
            echo ""
            echo "  # Export with filters and organization"
            echo "  template-export.sh --kind Template --tags crossplane --organize"
            echo ""
            echo "  # Preview export"
            echo "  template-export.sh --preview --kind Template,API"
            echo ""
            echo "  # List all APIs"
            echo "  template-export.sh --list --kind API"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# If no URL specified, use default
if ! echo "${ARGS[@]}" | grep -q -- "--url"; then
    ARGS+=("--url" "http://localhost:7007")
fi

# If output not in args, add default
if ! echo "${ARGS[@]}" | grep -q -- "--output"; then
    ARGS+=("--output" "$OUTPUT_DIR")
fi

# Add token if available
if [ -n "$BACKSTAGE_TOKEN" ] && ! echo "${ARGS[@]}" | grep -q -- "--token"; then
    ARGS+=("--token" "$BACKSTAGE_TOKEN")
fi

# Run the export CLI directly from source using ts-node
cd "$PLUGIN_DIR"
npx ts-node src/cli/backstage-export-cli.ts "${ARGS[@]}"