#!/usr/bin/env bash
#
# List Custom RBAC Bindings (OIDC Users and Groups Only)
# Purpose: Show only non-system RBAC bindings for humans and custom groups
#
# This script filters out:
# - System service accounts (system:serviceaccount:*)
# - System users (system:*)
# - System groups (system:*)
# - Built-in Kubernetes groups
#
# Shows only:
# - OIDC users (oidc:*)
# - OIDC groups (oidc:*)
#
# Usage:
#   ./scripts/rbac-list-custom.sh [format]
#
# Formats:
#   table   - Human-readable table (default)
#   json    - JSON output
#   yaml    - YAML output
#   csv     - CSV format
#
# Examples:
#   ./scripts/rbac-list-custom.sh
#   ./scripts/rbac-list-custom.sh json
#   ./scripts/rbac-list-custom.sh csv > rbac-custom.csv

set -euo pipefail

FORMAT="${1:-table}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ${NC} $*" >&2; }
log_error() { echo -e "${RED}✗${NC} $*" >&2; }

# Validate format
if [[ ! "$FORMAT" =~ ^(table|json|yaml|csv)$ ]]; then
  log_error "Invalid format: $FORMAT"
  echo "Valid formats: table, json, yaml, csv" >&2
  exit 1
fi

# Function to check if subject should be included
is_custom_subject() {
  local kind="$1"
  local name="$2"

  # Include OIDC users and groups
  if [[ "$name" =~ ^oidc: ]]; then
    return 0
  fi

  # Exclude ALL service accounts for this report (focus on humans and groups only)
  if [[ "$kind" == "ServiceAccount" ]]; then
    return 1
  fi

  # Exclude system users and groups
  if [[ "$name" =~ ^system: ]]; then
    return 1
  fi

  # Exclude built-in groups
  if [[ "$kind" == "Group" ]] && [[ "$name" =~ ^(kubeadm:|crossplane:) ]]; then
    return 1
  fi

  return 1
}

# Collect ClusterRoleBindings
CLUSTER_BINDINGS=$(kubectl get clusterrolebindings -o json | jq -c '[
  .items[] |
  select(.subjects != null) |
  .subjects[] as $subject |
  select($subject.kind == "User" or $subject.kind == "Group" or $subject.kind == "ServiceAccount") |
  {
    type: "ClusterRoleBinding",
    binding: .metadata.name,
    namespace: "",
    subject_kind: $subject.kind,
    subject_name: $subject.name,
    role: .roleRef.name,
    created: .metadata.creationTimestamp,
    managed_by: .metadata.labels["rbac.openportal.dev/managed-by"] // "",
    description: .metadata.annotations["rbac.openportal.dev/description"] // ""
  }
] | .[]')

# Collect RoleBindings
ROLE_BINDINGS=$(kubectl get rolebindings -A -o json | jq -c '[
  .items[] |
  select(.subjects != null) |
  .subjects[] as $subject |
  select($subject.kind == "User" or $subject.kind == "Group" or $subject.kind == "ServiceAccount") |
  {
    type: "RoleBinding",
    binding: .metadata.name,
    namespace: .metadata.namespace,
    subject_kind: $subject.kind,
    subject_name: $subject.name,
    role: .roleRef.name,
    created: .metadata.creationTimestamp,
    managed_by: .metadata.labels["rbac.openportal.dev/managed-by"] // "",
    description: .metadata.annotations["rbac.openportal.dev/description"] // ""
  }
] | .[]')

# Combine and filter
ALL_BINDINGS=$(echo "$CLUSTER_BINDINGS"; echo "$ROLE_BINDINGS")

# Filter custom bindings using bash
CUSTOM_BINDINGS=""
while IFS= read -r binding; do
  if [[ -z "$binding" ]]; then
    continue
  fi

  SUBJECT_KIND=$(echo "$binding" | jq -r '.subject_kind')
  SUBJECT_NAME=$(echo "$binding" | jq -r '.subject_name')

  if is_custom_subject "$SUBJECT_KIND" "$SUBJECT_NAME"; then
    CUSTOM_BINDINGS="${CUSTOM_BINDINGS}${binding}"$'\n'
  fi
done <<< "$ALL_BINDINGS"

# Count bindings
BINDING_COUNT=$(echo "$CUSTOM_BINDINGS" | grep -c '{' || echo "0")

if [[ "$BINDING_COUNT" -eq 0 ]]; then
  if [[ "$FORMAT" == "table" ]]; then
    log_info "No custom RBAC bindings found"
    echo ""
    echo "Custom bindings include:"
    echo "  • OIDC users (oidc:user@example.com)"
    echo "  • OIDC groups (oidc:groupname)"
    echo "  • Custom service accounts (non-system namespaces)"
    echo ""
    echo "To create custom bindings:"
    echo "  ./scripts/rbac-add-admin.sh user@example.com"
    echo "  ./scripts/rbac-add-namespace-access.sh user@example.com namespace edit"
    echo "  ./scripts/rbac-create-group.sh groupname cluster-admin"
  elif [[ "$FORMAT" == "json" ]]; then
    echo "[]"
  elif [[ "$FORMAT" == "yaml" ]]; then
    echo "[]"
  elif [[ "$FORMAT" == "csv" ]]; then
    echo "type,binding_name,namespace,subject_kind,subject_name,role,managed_by,created"
  fi
  exit 0
fi

# Output based on format
case "$FORMAT" in
  json)
    echo "$CUSTOM_BINDINGS" | jq -s '.'
    ;;

  yaml)
    echo "$CUSTOM_BINDINGS" | jq -s '.' | yq eval -P - 2>/dev/null || {
      log_error "yq not found. Install with: brew install yq"
      exit 1
    }
    ;;

  csv)
    echo "type,binding_name,namespace,subject_kind,subject_name,role,managed_by,created"
    echo "$CUSTOM_BINDINGS" | jq -r '[.type, .binding, .namespace, .subject_kind, .subject_name, .role, .managed_by, .created] | @csv'
    ;;

  table)
    echo ""
    echo -e "${BOLD}Custom RBAC Bindings${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════${NC}"
    echo ""

    # OIDC Users
    OIDC_USERS=$(echo "$CUSTOM_BINDINGS" | jq -r 'select(.subject_kind == "User" and (.subject_name | startswith("oidc:")))' 2>/dev/null || echo "")
    if [[ -n "$OIDC_USERS" ]]; then
      echo -e "${BOLD}OIDC Users ($(echo "$OIDC_USERS" | grep -c '{' || echo "0")):${NC}"
      echo ""
      printf "%-40s %-25s %-25s %-20s\n" "USER" "TYPE" "ROLE" "SCOPE"
      echo "────────────────────────────────────────────────────────────────────────────────────────────────"
      echo "$OIDC_USERS" | jq -r '
        .subject_name as $user |
        .type as $type |
        .role as $role |
        (.namespace // "cluster-wide") as $scope |
        "\($user)\t\($type)\t\($role)\t\($scope)"
      ' | while IFS=$'\t' read -r user type role scope; do
        printf "%-40s %-25s %-25s %-20s\n" "${user#oidc:}" "$type" "$role" "$scope"
      done
      echo ""
    fi

    # OIDC Groups
    OIDC_GROUPS=$(echo "$CUSTOM_BINDINGS" | jq -r 'select(.subject_kind == "Group" and (.subject_name | startswith("oidc:")))' 2>/dev/null || echo "")
    if [[ -n "$OIDC_GROUPS" ]]; then
      echo -e "${BOLD}OIDC Groups ($(echo "$OIDC_GROUPS" | grep -c '{' || echo "0")):${NC}"
      echo ""
      printf "%-40s %-25s %-25s %-20s\n" "GROUP" "TYPE" "ROLE" "SCOPE"
      echo "────────────────────────────────────────────────────────────────────────────────────────────────"
      echo "$OIDC_GROUPS" | jq -r '
        .subject_name as $group |
        .type as $type |
        .role as $role |
        (.namespace // "cluster-wide") as $scope |
        "\($group)\t\($type)\t\($role)\t\($scope)"
      ' | while IFS=$'\t' read -r group type role scope; do
        printf "%-40s %-25s %-25s %-20s\n" "${group#oidc:}" "$type" "$role" "$scope"
      done
      echo ""
    fi


    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════${NC}"
    echo -e "Total: ${BOLD}${BINDING_COUNT}${NC} custom bindings"
    echo ""

    log_info "For detailed information, use: $0 json | jq"
    log_info "To export to CSV: $0 csv > rbac-custom.csv"
    echo ""
    ;;
esac
