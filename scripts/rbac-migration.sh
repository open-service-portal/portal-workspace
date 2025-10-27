#!/usr/bin/env bash
#
# RBAC Migration Script - OpenPortal Cluster
# Purpose: Migrate from organization-wide cluster-admin to explicit user-based RBAC
#
# Usage:
#   ./scripts/rbac-migration.sh <admin1@example.com> <admin2@example.com> [admin3@example.com ...]
#
# Example:
#   ./scripts/rbac-migration.sh admin1@company.com admin2@company.com admin3@company.com

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -eq 0 ]]; then
  echo "Error: At least one admin email is required"
  echo "Usage: $0 <admin1@example.com> <admin2@example.com> [admin3@example.com ...]"
  exit 1
fi

# Add explicit admins
for admin_email in "$@"; do
  "${SCRIPT_DIR}/rbac-add-admin.sh" "$admin_email"
done

# Remove organization-wide admin binding
kubectl delete clusterrolebinding cloudspace-admin-role

echo ""
echo "✓ Migration complete"
