#!/bin/bash

# Backstage Template Export Tool
#
# Fetches templates and API entities from a running Backstage instance
# Usage: template-export.sh [options]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Find workspace root
WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_DIR="$WORKSPACE_ROOT/app-portal/plugins/kubernetes-ingestor"
EXPORT_SCRIPT="$PLUGIN_DIR/src/cli/export.js"

# Check if export script exists
if [ ! -f "$EXPORT_SCRIPT" ]; then
    echo -e "${RED}Error: Export script not found at $EXPORT_SCRIPT${NC}"
    exit 1
fi

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
OUTPUT_DIR=""
PATTERN=""
KIND="all"
URL="http://localhost:7007"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -p|--pattern)
            PATTERN="$2"
            shift 2
            ;;
        -k|--kind)
            KIND="$2"
            shift 2
            ;;
        -u|--url)
            URL="$2"
            shift 2
            ;;
        -t|--token)
            export BACKSTAGE_TOKEN="$2"
            shift 2
            ;;
        -h|--help)
            echo "Backstage Template Export Tool"
            echo ""
            echo "Usage: template-export.sh [options]"
            echo ""
            echo "Options:"
            echo "  -o, --output <dir>     Output directory (required)"
            echo "  -p, --pattern <name>   Name pattern to match"
            echo "  -k, --kind <kind>      Entity kind: template, api, or all (default: all)"
            echo "  -u, --url <url>        Backstage URL (default: http://localhost:7007)"
            echo "  -t, --token <token>    API token (or auto-detected from config)"
            echo "  -h, --help            Show this help message"
            echo ""
            echo "Examples:"
            echo "  # Export all templates and APIs to original directory"
            echo "  template-export.sh -o ./template-namespace/docs/backstage-templates/original"
            echo ""
            echo "  # Export namespace-related templates"
            echo "  template-export.sh -k template -p namespace -o ./templates"
            echo ""
            echo "  # Export from specific Backstage instance"
            echo "  template-export.sh -u https://backstage.example.com -o ./exported"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate output directory
if [ -z "$OUTPUT_DIR" ]; then
    echo -e "${RED}Error: Output directory is required${NC}"
    echo "Use -o or --output to specify the output directory"
    exit 1
fi

# Save original working directory
ORIGINAL_PWD="$(pwd)"

# Create absolute path for output directory relative to where user executed the script
if [[ ! "$OUTPUT_DIR" = /* ]]; then
    OUTPUT_DIR="$ORIGINAL_PWD/$OUTPUT_DIR"
fi

# Run the export
echo "Exporting Backstage entities..."
echo "  URL: $URL"
echo "  Kind: $KIND"
[ -n "$PATTERN" ] && echo "  Pattern: $PATTERN"
echo "  Output: $OUTPUT_DIR"
echo ""

# Build command
CMD="node \"$EXPORT_SCRIPT\" --url \"$URL\" --output \"$OUTPUT_DIR\" --kind \"$KIND\""
[ -n "$PATTERN" ] && CMD="$CMD --pattern \"$PATTERN\""

# Execute
eval $CMD

# Show results
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ Export complete${NC}"
    echo "Files saved to: $OUTPUT_DIR"
    
    # List exported files
    if [ -d "$OUTPUT_DIR" ]; then
        echo ""
        echo "Exported files:"
        ls -la "$OUTPUT_DIR" | grep -E '\.(yaml|json)$' | awk '{print "  - " $9}'
    fi
else
    echo -e "${RED}✗ Export failed${NC}"
    exit 1
fi