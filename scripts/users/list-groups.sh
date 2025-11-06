#!/usr/bin/env bash
#
# List Backstage Groups and Their Members
#
# This script queries the Backstage catalog API to list all groups
# and their members. Groups are imported from:
# 1. GitHub Organization (via githubOrg provider)
# 2. Local org.yaml file (examples/org.yaml)
# 3. Other catalog sources
#
# Usage:
#   ./scripts/list-groups.sh [OPTIONS]
#
# Options:
#   --help, -h          Show this help message
#   --detailed, -d      Show detailed group information
#   --json              Output raw JSON
#   --filter <pattern>  Filter groups by name pattern
#
# Examples:
#   ./scripts/list-groups.sh
#   ./scripts/list-groups.sh --detailed
#   ./scripts/list-groups.sh --filter developers
#   ./scripts/list-groups.sh --json | jq '.[] | .metadata.name'

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

# Defaults
DETAILED=false
JSON_OUTPUT=false
FILTER=""

# Show help
show_help() {
  cat <<EOF
List Backstage Groups and Their Members

This script queries the Backstage catalog API to list all groups
and their members. Groups are imported from:
  • GitHub Organization (via githubOrg provider)
  • Local org.yaml file (examples/org.yaml)
  • Other catalog sources

Usage:
  $0 [OPTIONS]

Options:
  --help, -h          Show this help message
  --detailed, -d      Show detailed group information (type, parent, children)
  --json              Output raw JSON from API
  --filter <pattern>  Filter groups by name pattern (grep regex)

Examples:
  # List all groups with member counts
  $0

  # Show detailed information
  $0 --detailed

  # Filter groups by pattern
  $0 --filter developers
  $0 --filter "platform.*"

  # Get raw JSON for custom processing
  $0 --json | jq '.[] | {name: .metadata.name, members: .spec.members}'

Prerequisites:
  • Backstage must be running (yarn start in app-portal/)
  • Requires cluster-config.sh to have been run for API token

EOF
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      show_help
      ;;
    --detailed|-d)
      DETAILED=true
      shift
      ;;
    --json)
      JSON_OUTPUT=true
      shift
      ;;
    --filter)
      FILTER="${2:-}"
      if [[ -z "$FILTER" ]]; then
        echo -e "${RED}Error: --filter requires a pattern${NC}" >&2
        exit 1
      fi
      shift 2
      ;;
    *)
      echo -e "${RED}Error: Unknown option: $1${NC}" >&2
      echo "Use --help for usage information" >&2
      exit 1
      ;;
  esac
done

# Navigate to workspace root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"

cd "$WORKSPACE_DIR"

# Check if backstage-api.sh exists
if [[ ! -x "./scripts/backstage-api.sh" ]]; then
  echo -e "${RED}Error: backstage-api.sh not found or not executable${NC}" >&2
  exit 1
fi

# Fetch groups from Backstage API
echo -e "${BLUE}Fetching groups from Backstage catalog...${NC}" >&2

# Get groups from API
GROUPS_JSON=$(./scripts/backstage-api.sh '/api/catalog/entities?filter=kind=Group' 2>/dev/null)

if [[ -z "$GROUPS_JSON" || "$GROUPS_JSON" == "null" ]]; then
  echo -e "${RED}Error: No groups found or API returned empty response${NC}" >&2
  exit 1
fi

# If JSON output requested, just output and exit
if [[ "$JSON_OUTPUT" == "true" ]]; then
  echo "$GROUPS_JSON" | jq '.'
  exit 0
fi

# Apply filter if specified
if [[ -n "$FILTER" ]]; then
  GROUPS_JSON=$(echo "$GROUPS_JSON" | jq --arg filter "$FILTER" '
    map(select(.metadata.name | test($filter)))
  ')
fi

# Count groups
GROUP_COUNT=$(echo "$GROUPS_JSON" | jq 'length')

if [[ "$GROUP_COUNT" -eq 0 ]]; then
  if [[ -n "$FILTER" ]]; then
    echo -e "${YELLOW}No groups found matching filter: $FILTER${NC}"
  else
    echo -e "${YELLOW}No groups found in catalog${NC}"
  fi
  exit 0
fi

# Header
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Backstage Groups${NC}"
if [[ -n "$FILTER" ]]; then
  echo -e "${CYAN}  Filter: $FILTER${NC}"
fi
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BOLD}Found $GROUP_COUNT group(s)${NC}"
echo ""

# Process each group
echo "$GROUPS_JSON" | jq -r '.[] | @json' | while IFS= read -r group; do
  # Extract group info
  GROUP_NAME=$(echo "$group" | jq -r '.metadata.name')
  GROUP_TITLE=$(echo "$group" | jq -r '.metadata.title // .metadata.name')
  GROUP_DESC=$(echo "$group" | jq -r '.metadata.description // ""')
  GROUP_TYPE=$(echo "$group" | jq -r '.spec.type // "team"')
  GROUP_PARENT=$(echo "$group" | jq -r '.spec.parent // ""')
  GROUP_CHILDREN=$(echo "$group" | jq -r '.spec.children // [] | join(", ")')
  GROUP_MEMBERS=$(echo "$group" | jq -r '.spec.members // [] | join(", ")')
  MEMBER_COUNT=$(echo "$group" | jq -r '.spec.members // [] | length')

  # Display group
  echo -e "${GREEN}▸${NC} ${BOLD}${GROUP_TITLE}${NC} ${BLUE}(${GROUP_NAME})${NC}"

  if [[ -n "$GROUP_DESC" ]]; then
    echo "  Description: ${GROUP_DESC}"
  fi

  if [[ "$DETAILED" == "true" ]]; then
    echo "  Type: ${GROUP_TYPE}"
    if [[ -n "$GROUP_PARENT" ]]; then
      echo "  Parent: ${GROUP_PARENT}"
    fi
    if [[ -n "$GROUP_CHILDREN" ]]; then
      echo "  Children: ${GROUP_CHILDREN}"
    fi
  fi

  # Display members
  if [[ $MEMBER_COUNT -eq 0 ]]; then
    echo -e "  Members: ${YELLOW}(none)${NC}"
  else
    echo "  Members ($MEMBER_COUNT):"
    echo "$group" | jq -r '.spec.members[] // empty' | while IFS= read -r member; do
      echo "    • ${member}"
    done
  fi

  echo ""
done

# Summary
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"

# Fetch users to show group membership from user side
echo ""
echo -e "${BLUE}Fetching users from catalog...${NC}" >&2
USERS_JSON=$(./scripts/backstage-api.sh '/api/catalog/entities?filter=kind=User' 2>/dev/null)
USER_COUNT=$(echo "$USERS_JSON" | jq 'length')

if [[ $USER_COUNT -gt 0 ]]; then
  echo ""
  echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${CYAN}  Users and Their Groups${NC}"
  echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "${BOLD}Found $USER_COUNT user(s)${NC}"
  echo ""

  echo "$USERS_JSON" | jq -r '.[] | @json' | while IFS= read -r user; do
    USER_NAME=$(echo "$user" | jq -r '.metadata.name')
    USER_TITLE=$(echo "$user" | jq -r '.metadata.title // .metadata.name')
    USER_EMAIL=$(echo "$user" | jq -r '.spec.profile.email // ""')
    USER_GROUPS=$(echo "$user" | jq -r '.spec.memberOf // [] | join(", ")')

    echo -e "${GREEN}▸${NC} ${BOLD}${USER_TITLE}${NC} ${BLUE}(${USER_NAME})${NC}"
    if [[ -n "$USER_EMAIL" ]]; then
      echo "  Email: ${USER_EMAIL}"
    fi
    if [[ -n "$USER_GROUPS" ]]; then
      echo "  Groups: ${USER_GROUPS}"
    else
      echo -e "  Groups: ${YELLOW}(none)${NC}"
    fi
    echo ""
  done

  echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
fi

# Footer with helpful info
echo ""
echo -e "${BLUE}ℹ${NC} Group Sources:"
echo "  • GitHub Organization: open-service-portal (via githubOrg provider)"
echo "  • Local file: app-portal/examples/org.yaml"
echo ""
echo -e "${BLUE}ℹ${NC} To add users to groups for Kubernetes RBAC:"
echo "  ./scripts/create-user-with-cert.sh <username> <group1> [group2]..."
echo ""
echo -e "${BLUE}ℹ${NC} To refresh catalog (force re-sync):"
echo "  Visit: http://localhost:3000/catalog?filters%5Bkind%5D=group"
echo "  Click on a group → Refresh"
echo ""
