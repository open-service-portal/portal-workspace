#!/bin/bash
# Template Status Report - Simple version
# Shows: latest tag, unreleased changes, open PRs

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"
ORG="open-service-portal"

# Find all template directories
cd "$WORKSPACE_DIR"
TEMPLATES=$(ls -d template-*/ 2>/dev/null | sed 's/\///' | sort)

if [ -z "$TEMPLATES" ]; then
    echo "No template directories found in $WORKSPACE_DIR"
    exit 1
fi

# Simple table header
printf "%-35s %-12s %-18s %s\n" "Template" "Latest Tag" "Unreleased" "Open PRs"
printf "%-35s %-12s %-18s %s\n" "--------" "----------" "----------" "--------"

# Process each template
for template in $TEMPLATES; do
    cd "$WORKSPACE_DIR/$template" 2>/dev/null || continue
    
    # Fetch latest changes
    git fetch --tags --quiet 2>/dev/null || true
    
    # Get latest tag
    latest_tag=$(git tag -l 2>/dev/null | sort -V | tail -1)
    if [ -z "$latest_tag" ]; then
        latest_tag="none"
        tag_display="${RED}none${NC}"
    else
        tag_display="${GREEN}${latest_tag}${NC}"
    fi
    
    # Check for unreleased commits
    if [ "$latest_tag" = "none" ]; then
        # No tags, count all commits
        commit_count=$(git rev-list --count HEAD 2>/dev/null || echo "0")
        if [ "$commit_count" -gt "0" ]; then
            unreleased="${YELLOW}${commit_count} commits${NC}"
        else
            unreleased="${GREEN}no commits${NC}"
        fi
    else
        # Count commits after latest tag
        unreleased_count=$(git rev-list ${latest_tag}..HEAD --count 2>/dev/null || echo "0")
        if [ "$unreleased_count" -gt "0" ]; then
            unreleased="${YELLOW}${unreleased_count} commits${NC}"
        else
            unreleased="${GREEN}none${NC}"
        fi
    fi
    
    # Count open PRs
    pr_count=$(gh pr list --repo "$ORG/$template" --state open --json number --jq '. | length' 2>/dev/null || echo "0")
    if [ "$pr_count" -gt "0" ]; then
        pr_display="${YELLOW}${pr_count}${NC}"
    else
        pr_display="${GREEN}0${NC}"
    fi
    
    # Print row
    printf "%-35s %-21b %-27b %b\n" "$template" "$tag_display" "$unreleased" "$pr_display"
done

echo ""

# Show PR links if any exist
has_prs=false
for template in $TEMPLATES; do
    pr_urls=$(gh pr list --repo "$ORG/$template" --state open --json number,url --jq '.[] | "  PR #\(.number): \(.url)"' 2>/dev/null)
    if [ -n "$pr_urls" ]; then
        if [ "$has_prs" = false ]; then
            echo "Open PRs:"
            has_prs=true
        fi
        echo -e "${YELLOW}$template:${NC}"
        echo "$pr_urls"
    fi
done

if [ "$has_prs" = false ]; then
    echo -e "${GREEN}No open PRs across all templates${NC}"
fi