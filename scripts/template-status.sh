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

# Check if catalog repo exists locally
CATALOG_DIR="$WORKSPACE_DIR/catalog"
if [ -d "$CATALOG_DIR" ]; then
    cd "$CATALOG_DIR"
    git pull --quiet 2>/dev/null || true
    cd "$WORKSPACE_DIR"
fi

# Simple table header  
printf "%-35s %-10s   %-10s   %-10s   %s\n" "Template" "Latest Tag" "In Catalog" "Unreleased" "Open PRs"
printf "%-35s %-10s   %-10s   %-10s   %s\n" "--------" "----------" "----------" "----------" "--------"

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
    
    # Check catalog version
    catalog_version="unknown"
    if [ -d "$CATALOG_DIR" ]; then
        # Try to find the template in catalog
        catalog_file="$CATALOG_DIR/templates/${template}.yaml"
        if [ -f "$catalog_file" ]; then
            # Extract version from package spec (e.g., ghcr.io/org/config:v1.0.3)
            catalog_version=$(grep "package:" "$catalog_file" 2>/dev/null | head -1 | sed 's/.*://' | tr -d ' ' || echo "unknown")
        fi
    fi
    
    # Compare catalog version with latest tag
    if [ "$catalog_version" = "unknown" ]; then
        catalog_display="${RED}not found${NC}"
    elif [ "$catalog_version" = "$latest_tag" ]; then
        catalog_display="${GREEN}${catalog_version}${NC}"
    else
        catalog_display="${YELLOW}${catalog_version}${NC}"
    fi
    
    # Count open PRs
    pr_count=$(gh pr list --repo "$ORG/$template" --state open --json number --jq '. | length' 2>/dev/null || echo "0")
    if [ "$pr_count" -gt "0" ]; then
        pr_display="${YELLOW}${pr_count}${NC}"
    else
        pr_display="${GREEN}0${NC}"
    fi
    
    # Print row
    printf "%-35s %-23b %-23b %-23b %b\n" "$template" "$tag_display" "$catalog_display" "$unreleased" "$pr_display"
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

echo ""

# Summary
outdated_count=0
for template in $TEMPLATES; do
    cd "$WORKSPACE_DIR/$template" 2>/dev/null || continue
    latest_tag=$(git tag -l 2>/dev/null | sort -V | tail -1)
    catalog_file="$CATALOG_DIR/templates/${template}.yaml"
    if [ -f "$catalog_file" ]; then
        catalog_version=$(grep "package:" "$catalog_file" 2>/dev/null | head -1 | sed 's/.*://' | tr -d ' ' || echo "unknown")
        if [ -n "$latest_tag" ] && [ "$catalog_version" != "$latest_tag" ] && [ "$catalog_version" != "unknown" ]; then
            outdated_count=$((outdated_count + 1))
        fi
    fi
done

if [ "$outdated_count" -gt "0" ]; then
    echo -e "${YELLOW}⚠ ${outdated_count} template(s) have newer versions not yet in catalog${NC}"
else
    echo -e "${GREEN}✓ All templates in catalog are up to date${NC}"
fi

echo ""

# Show catalog PRs
echo "Catalog PRs:"
catalog_prs=$(gh pr list --repo "$ORG/catalog" --state open --json number,url,title,author --jq '.[] | "  PR #\(.number): \(.title)\n    Author: \(.author.login)\n    URL: \(.url)"' 2>/dev/null)
if [ -n "$catalog_prs" ]; then
    echo -e "${YELLOW}Open catalog PRs:${NC}"
    echo "$catalog_prs"
else
    echo -e "${GREEN}No open catalog PRs${NC}"
fi