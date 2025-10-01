#!/bin/bash
#
# Generic Backstage API wrapper script
# Usage: ./backstage-api.sh '<endpoint>' [jq-filter]
#
# Examples:
#   ./backstage-api.sh /api/catalog/entities
#   ./backstage-api.sh '/api/catalog/entities?filter=kind=Template'
#   ./backstage-api.sh '/api/catalog/entities' '.[] | .metadata.name'
#
# Note: Always quote endpoints with query parameters (?)
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Navigate to app-portal directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"
APP_PORTAL_DIR="$WORKSPACE_DIR/app-portal"

cd "$APP_PORTAL_DIR"

# Get config file based on kubectl context
CONTEXT=$(kubectl config current-context 2>/dev/null || echo "unknown")
CONFIG_FILE="app-config.${CONTEXT}.local.yaml"

# Extract token from config
if [ -f "$CONFIG_FILE" ]; then
  TOKEN=$(grep -A2 "type: static" "$CONFIG_FILE" | grep "token:" | awk '{print $2}')
else
  echo "Error: Config file $CONFIG_FILE not found in $APP_PORTAL_DIR" >&2
  exit 1
fi

if [ -z "$TOKEN" ]; then
  echo "Error: Could not extract token from $CONFIG_FILE" >&2
  exit 1
fi

# Get endpoint (required)
ENDPOINT="${1:-}"
if [ -z "$ENDPOINT" ]; then
  echo -e "${RED}Error: Endpoint is required${NC}" >&2
  echo "" >&2
  echo "Usage: $0 '<endpoint>' [jq-filter]" >&2
  echo "" >&2
  echo "Examples:" >&2
  echo "  $0 /api/catalog/entities" >&2
  echo "  $0 '/api/catalog/entities?filter=kind=Template'" >&2
  echo "  $0 '/api/catalog/entities' '.[] | .metadata.name'" >&2
  echo "" >&2
  echo -e "${YELLOW}Note: Always quote endpoints with query parameters (?)${NC}" >&2
  exit 1
fi

# Check if endpoint contains unquoted ? (common mistake)
if [[ "$ENDPOINT" == *"?"* ]] && [[ "$#" -gt 2 ]]; then
  echo -e "${RED}Error: It looks like you forgot to quote the endpoint${NC}" >&2
  echo "" >&2
  echo -e "${YELLOW}Did you mean:${NC}" >&2
  echo "  $0 '$ENDPOINT' ${2:-}" >&2
  exit 1
fi

# Get optional jq filter
JQ_FILTER="${2:-.}"

# Check if Backstage is running
if ! curl -s -f -o /dev/null "http://localhost:7007/api/catalog/entities?limit=1" 2>/dev/null; then
  echo -e "${RED}Error: Cannot connect to Backstage API at http://localhost:7007${NC}" >&2
  echo "" >&2
  echo "Is Backstage running?" >&2
  echo "  cd app-portal && yarn start" >&2
  exit 1
fi

# Make API call
RESPONSE=$(curl -s -H "Authorization: Bearer $TOKEN" "http://localhost:7007${ENDPOINT}")

# Check if response is valid JSON
if ! echo "$RESPONSE" | jq empty 2>/dev/null; then
  echo -e "${RED}Error: Invalid JSON response from API${NC}" >&2
  echo "" >&2
  echo "Response:" >&2
  echo "$RESPONSE" >&2
  exit 1
fi

# Apply jq filter
echo "$RESPONSE" | jq "${JQ_FILTER}"
