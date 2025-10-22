#!/bin/bash

# Check all repositories for uncommitted changes and pull latest from main
# Usage: ./repos-sync.sh [--pull]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
PULL_MODE=false
if [[ "$1" == "--pull" ]]; then
    PULL_MODE=true
fi

# Get the workspace root directory
WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Repository Sync Status${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Track overall status
HAS_CHANGES=false
HAS_ERRORS=false

# Find all git repositories (excluding hidden directories and node_modules)
REPOS=$(find "$WORKSPACE_ROOT" -maxdepth 2 -type d -name ".git" 2>/dev/null | sed 's|/.git||' | sort)

# Function to check repository status
check_repo() {
    local repo=$1
    local repo_name=$(basename "$repo")
    
    echo -e "${YELLOW}Checking: ${repo_name}${NC}"
    cd "$repo"
    
    # Get current branch
    current_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    
    # Check for uncommitted changes
    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo -e "  ${RED}✗ Has uncommitted changes${NC}"
        echo -e "  Current branch: ${current_branch}"
        git status --short | head -5 | sed 's/^/    /'
        HAS_CHANGES=true
        echo ""
        return 1
    fi
    
    # Check for untracked files
    if [[ -n $(git ls-files --others --exclude-standard) ]]; then
        echo -e "  ${YELLOW}⚠ Has untracked files${NC}"
        git ls-files --others --exclude-standard | head -5 | sed 's/^/    /'
    fi
    
    # Check if we're on main/master branch
    main_branch="main"
    if ! git show-ref --verify --quiet refs/heads/main; then
        if git show-ref --verify --quiet refs/heads/master; then
            main_branch="master"
        fi
    fi
    
    if [[ "$current_branch" != "$main_branch" ]]; then
        echo -e "  ${YELLOW}⚠ Not on $main_branch branch (current: $current_branch)${NC}"
        
        if [[ "$PULL_MODE" == true ]]; then
            echo -e "  Switching to $main_branch..."
            if git checkout "$main_branch" 2>/dev/null; then
                echo -e "  ${GREEN}✓ Switched to $main_branch${NC}"
                current_branch=$main_branch
            else
                echo -e "  ${RED}✗ Failed to switch to $main_branch${NC}"
                HAS_ERRORS=true
                echo ""
                return 1
            fi
        fi
    else
        echo -e "  ${GREEN}✓ On $main_branch branch${NC}"
    fi
    
    # Pull latest if in pull mode and on main branch
    if [[ "$PULL_MODE" == true && "$current_branch" == "$main_branch" ]]; then
        echo -e "  Pulling latest from origin/$main_branch..."
        
        # First fetch to see if there are updates
        git fetch origin "$main_branch" --quiet
        
        # Check if we're behind
        LOCAL=$(git rev-parse HEAD)
        REMOTE=$(git rev-parse "origin/$main_branch")
        
        if [[ "$LOCAL" != "$REMOTE" ]]; then
            if git pull origin "$main_branch" --ff-only 2>/dev/null; then
                echo -e "  ${GREEN}✓ Successfully pulled latest changes${NC}"
                
                # Show what was updated
                git log --oneline HEAD@{1}..HEAD | head -5 | sed 's/^/    /'
            else
                echo -e "  ${RED}✗ Failed to pull (may need merge or rebase)${NC}"
                HAS_ERRORS=true
            fi
        else
            echo -e "  ${GREEN}✓ Already up to date${NC}"
        fi
    elif [[ "$PULL_MODE" == false ]]; then
        # Just check if we're behind origin
        git fetch origin "$main_branch" --quiet 2>/dev/null || true
        
        if git show-ref --verify --quiet "refs/remotes/origin/$main_branch"; then
            LOCAL=$(git rev-parse HEAD 2>/dev/null || echo "none")
            REMOTE=$(git rev-parse "origin/$main_branch" 2>/dev/null || echo "none")
            
            if [[ "$LOCAL" != "$REMOTE" && "$LOCAL" != "none" && "$REMOTE" != "none" ]]; then
                BEHIND=$(git rev-list --count HEAD.."origin/$main_branch" 2>/dev/null || echo "0")
                AHEAD=$(git rev-list --count "origin/$main_branch"..HEAD 2>/dev/null || echo "0")
                
                if [[ "$BEHIND" -gt 0 ]]; then
                    echo -e "  ${YELLOW}⚠ Behind origin/$main_branch by $BEHIND commit(s)${NC}"
                fi
                if [[ "$AHEAD" -gt 0 ]]; then
                    echo -e "  ${YELLOW}⚠ Ahead of origin/$main_branch by $AHEAD commit(s)${NC}"
                fi
            fi
        fi
    fi
    
    echo ""
    return 0
}

# Process each repository
for repo in $REPOS; do
    # Skip certain directories
    if [[ "$repo" == *"backstage"* ]] || [[ "$repo" == *"backstage-terasky-plugins-fork"* ]]; then
        # These are reference repos, skip them
        continue
    fi

    check_repo "$repo" || true
done

# Check for nested plugin repositories (depth > 2)
# These are git repositories inside other repositories (e.g., app-portal/plugins/ingestor)
NESTED_PLUGIN_PATH="$WORKSPACE_ROOT/app-portal/plugins/ingestor"
if [[ -d "$NESTED_PLUGIN_PATH/.git" ]]; then
    repo_name=$(basename "$NESTED_PLUGIN_PATH")
    echo -e "${YELLOW}Checking: app-portal/plugins/${repo_name} (nested plugin)${NC}"
    cd "$NESTED_PLUGIN_PATH"

    # Get current branch
    current_branch=$(git branch --show-current 2>/dev/null || echo "unknown")

    # Check for uncommitted changes
    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo -e "  ${RED}✗ Has uncommitted changes${NC}"
        echo -e "  Current branch: ${current_branch}"
        git status --short | head -5 | sed 's/^/    /'
        HAS_CHANGES=true
        echo ""
    else
        # Check for untracked files
        if [[ -n $(git ls-files --others --exclude-standard) ]]; then
            echo -e "  ${YELLOW}⚠ Has untracked files${NC}"
            git ls-files --others --exclude-standard | head -5 | sed 's/^/    /'
        fi

        # Check if we're on main/master branch
        main_branch="main"
        if ! git show-ref --verify --quiet refs/heads/main; then
            if git show-ref --verify --quiet refs/heads/master; then
                main_branch="master"
            fi
        fi

        if [[ "$current_branch" != "$main_branch" ]]; then
            echo -e "  ${YELLOW}⚠ Not on $main_branch branch (current: $current_branch)${NC}"

            if [[ "$PULL_MODE" == true ]]; then
                echo -e "  Switching to $main_branch..."
                if git checkout "$main_branch" 2>/dev/null; then
                    echo -e "  ${GREEN}✓ Switched to $main_branch${NC}"
                    current_branch=$main_branch
                else
                    echo -e "  ${RED}✗ Failed to switch to $main_branch${NC}"
                    HAS_ERRORS=true
                    echo ""
                fi
            fi
        else
            echo -e "  ${GREEN}✓ On $main_branch branch${NC}"
        fi

        # Pull latest if in pull mode and on main branch
        if [[ "$PULL_MODE" == true && "$current_branch" == "$main_branch" ]]; then
            echo -e "  Pulling latest from origin/$main_branch..."

            # First fetch to see if there are updates
            git fetch origin "$main_branch" --quiet

            # Check if we're behind
            LOCAL=$(git rev-parse HEAD)
            REMOTE=$(git rev-parse "origin/$main_branch")

            if [[ "$LOCAL" != "$REMOTE" ]]; then
                if git pull origin "$main_branch" --ff-only 2>/dev/null; then
                    echo -e "  ${GREEN}✓ Successfully pulled latest changes${NC}"

                    # Show what was updated
                    git log --oneline HEAD@{1}..HEAD | head -5 | sed 's/^/    /'
                else
                    echo -e "  ${RED}✗ Failed to pull (may need merge or rebase)${NC}"
                    HAS_ERRORS=true
                fi
            else
                echo -e "  ${GREEN}✓ Already up to date${NC}"
            fi
        elif [[ "$PULL_MODE" == false ]]; then
            # Just check if we're behind origin
            git fetch origin "$main_branch" --quiet 2>/dev/null || true

            if git show-ref --verify --quiet "refs/remotes/origin/$main_branch"; then
                LOCAL=$(git rev-parse HEAD 2>/dev/null || echo "none")
                REMOTE=$(git rev-parse "origin/$main_branch" 2>/dev/null || echo "none")

                if [[ "$LOCAL" != "$REMOTE" && "$LOCAL" != "none" && "$REMOTE" != "none" ]]; then
                    BEHIND=$(git rev-list --count HEAD.."origin/$main_branch" 2>/dev/null || echo "0")
                    AHEAD=$(git rev-list --count "origin/$main_branch"..HEAD 2>/dev/null || echo "0")

                    if [[ "$BEHIND" -gt 0 ]]; then
                        echo -e "  ${YELLOW}⚠ Behind origin/$main_branch by $BEHIND commit(s)${NC}"
                    fi
                    if [[ "$AHEAD" -gt 0 ]]; then
                        echo -e "  ${YELLOW}⚠ Ahead of origin/$main_branch by $AHEAD commit(s)${NC}"
                    fi
                fi
            fi
        fi

        echo ""
    fi
fi

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}========================================${NC}"

if [[ "$HAS_CHANGES" == true ]]; then
    echo -e "${RED}⚠ Some repositories have uncommitted changes${NC}"
    echo -e "Please commit or stash changes before pulling"
elif [[ "$HAS_ERRORS" == true ]]; then
    echo -e "${RED}⚠ Some operations failed${NC}"
    echo -e "Please check the errors above"
elif [[ "$PULL_MODE" == true ]]; then
    echo -e "${GREEN}✓ All repositories synced successfully${NC}"
else
    echo -e "${GREEN}✓ All repositories are clean${NC}"
    echo -e ""
    echo -e "Run with ${YELLOW}--pull${NC} to switch to main and pull latest:"
    echo -e "  ./scripts/sync-repos.sh --pull"
fi

# Return to workspace root
cd "$WORKSPACE_ROOT"