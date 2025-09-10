#!/bin/bash
# template-release.sh - Create a new release for a template if changes exist
# Usage: ./template-release.sh <template-name> [version]
# Examples: 
#   ./template-release.sh template-whoami          # Interactive version selection
#   ./template-release.sh template-whoami v1.2.0   # Explicit version
#   ./template-release.sh template-whoami patch    # Auto-increment patch version
#   ./template-release.sh template-whoami minor    # Auto-increment minor version
#   ./template-release.sh template-whoami major    # Auto-increment major version

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if template name was provided
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo -e "${RED}Error: Invalid number of arguments${NC}"
    echo "Usage: $0 <template-name> [version]"
    echo "Examples:"
    echo "  $0 template-whoami          # Interactive version selection"
    echo "  $0 template-whoami v1.2.0   # Explicit version"
    echo "  $0 template-whoami patch    # Auto-increment patch"
    echo "  $0 template-whoami minor    # Auto-increment minor"
    echo "  $0 template-whoami major    # Auto-increment major"
    exit 1
fi

TEMPLATE_NAME=$1
VERSION_ARG=${2:-""}

# Get script and workspace directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE_DIR="${WORKSPACE_DIR}/${TEMPLATE_NAME}"

# Check if template directory exists
if [ ! -d "${TEMPLATE_DIR}" ]; then
    echo -e "${RED}Error: Template directory not found: ${TEMPLATE_DIR}${NC}"
    echo "Available templates:"
    ls -d "${WORKSPACE_DIR}"/template-* 2>/dev/null | xargs -n1 basename || echo "No templates found"
    exit 1
fi

cd "${TEMPLATE_DIR}"

# Ensure we're on main branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "${CURRENT_BRANCH}" != "main" ]; then
    echo -e "${YELLOW}Warning: Not on main branch (current: ${CURRENT_BRANCH})${NC}"
    read -p "Switch to main branch? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git checkout main
        git pull origin main
    else
        echo -e "${RED}Aborted: Must be on main branch to create release${NC}"
        exit 1
    fi
fi

# Get the latest tag
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
echo -e "Latest tag: ${YELLOW}${LATEST_TAG}${NC}"

# Check if there are changes since the last tag
if [ "${LATEST_TAG}" != "v0.0.0" ]; then
    CHANGES=$(git log ${LATEST_TAG}..HEAD --oneline)
    if [ -z "${CHANGES}" ]; then
        echo -e "${RED}Error: No changes since last tag ${LATEST_TAG}${NC}"
        echo "Nothing to release!"
        exit 1
    fi
    echo -e "${GREEN}Changes since ${LATEST_TAG}:${NC}"
    echo "${CHANGES}"
else
    echo -e "${GREEN}First release - all commits will be included${NC}"
    CHANGES=$(git log --oneline | head -10)
    echo "${CHANGES}"
fi

# Parse current version and increment
if [[ ${LATEST_TAG} =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    MAJOR=${BASH_REMATCH[1]}
    MINOR=${BASH_REMATCH[2]}
    PATCH=${BASH_REMATCH[3]}
else
    echo -e "${YELLOW}Warning: Could not parse version from ${LATEST_TAG}, starting fresh${NC}"
    MAJOR=0
    MINOR=0
    PATCH=0
fi

# Handle version argument
if [ -n "${VERSION_ARG}" ]; then
    case ${VERSION_ARG} in
        patch)
            NEW_VERSION="v${MAJOR}.${MINOR}.$((PATCH + 1))"
            VERSION_TYPE="patch"
            ;;
        minor)
            NEW_VERSION="v${MAJOR}.$((MINOR + 1)).0"
            VERSION_TYPE="minor"
            ;;
        major)
            NEW_VERSION="v$((MAJOR + 1)).0.0"
            VERSION_TYPE="major"
            ;;
        v[0-9]*)
            # Explicit version provided
            NEW_VERSION="${VERSION_ARG}"
            # Validate version format
            if ! [[ ${NEW_VERSION} =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo -e "${RED}Error: Invalid version format: ${VERSION_ARG}${NC}"
                echo "Version must be in format: v1.2.3"
                exit 1
            fi
            # Check version is higher than latest
            if [ "${NEW_VERSION}" = "${LATEST_TAG}" ]; then
                echo -e "${RED}Error: Version ${NEW_VERSION} already exists${NC}"
                exit 1
            fi
            # Determine version type based on change
            if [[ ${NEW_VERSION} =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
                NEW_MAJOR=${BASH_REMATCH[1]}
                NEW_MINOR=${BASH_REMATCH[2]}
                NEW_PATCH=${BASH_REMATCH[3]}
                if [ ${NEW_MAJOR} -gt ${MAJOR} ]; then
                    VERSION_TYPE="major"
                elif [ ${NEW_MINOR} -gt ${MINOR} ]; then
                    VERSION_TYPE="minor"
                else
                    VERSION_TYPE="patch"
                fi
            fi
            ;;
        *)
            echo -e "${RED}Error: Invalid version argument: ${VERSION_ARG}${NC}"
            echo "Valid options: patch, minor, major, or v1.2.3"
            exit 1
            ;;
    esac
    echo -e "Using version: ${GREEN}${NEW_VERSION}${NC} (${VERSION_TYPE} release)"
else
    # Interactive mode - ask for version bump type
    echo
    echo "Select version bump type:"
    echo "  1) Patch (${MAJOR}.${MINOR}.$((PATCH + 1))) - Bug fixes"
    echo "  2) Minor (${MAJOR}.$((MINOR + 1)).0) - New features"
    echo "  3) Major ($((MAJOR + 1)).0.0) - Breaking changes"
    read -p "Choice (1/2/3): " -n 1 -r VERSION_CHOICE
    echo

    case ${VERSION_CHOICE} in
        1)
            NEW_VERSION="v${MAJOR}.${MINOR}.$((PATCH + 1))"
            VERSION_TYPE="patch"
            ;;
        2)
            NEW_VERSION="v${MAJOR}.$((MINOR + 1)).0"
            VERSION_TYPE="minor"
            ;;
        3)
            NEW_VERSION="v$((MAJOR + 1)).0.0"
            VERSION_TYPE="major"
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            exit 1
            ;;
    esac
fi

echo -e "New version will be: ${GREEN}${NEW_VERSION}${NC}"

# Generate commit message summary
COMMIT_SUMMARY=$(git log ${LATEST_TAG}..HEAD --pretty=format:"- %s" 2>/dev/null | head -5)

# Create tag message
TAG_MESSAGE="Release ${NEW_VERSION}

Type: ${VERSION_TYPE}

Changes:
${COMMIT_SUMMARY}"

# Confirm before creating tag (skip in non-interactive mode)
if [ -n "${VERSION_ARG}" ]; then
    echo
    echo "Tag message:"
    echo "---"
    echo "${TAG_MESSAGE}"
    echo "---"
    echo -e "${GREEN}Creating tag ${NEW_VERSION} (non-interactive mode)...${NC}"
else
    echo
    echo "Tag message:"
    echo "---"
    echo "${TAG_MESSAGE}"
    echo "---"
    echo
    read -p "Create tag ${NEW_VERSION}? (y/n) " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Aborted by user${NC}"
        exit 0
    fi
fi

# Create and push tag
echo -e "${GREEN}Creating tag ${NEW_VERSION}...${NC}"
git tag -a "${NEW_VERSION}" -m "${TAG_MESSAGE}"

echo -e "${GREEN}Pushing tag to origin...${NC}"
git push origin "${NEW_VERSION}"

# Success message
echo
echo -e "${GREEN}✅ Successfully created release ${NEW_VERSION} for ${TEMPLATE_NAME}${NC}"
echo
echo "GitHub Release URL:"
echo "https://github.com/open-service-portal/${TEMPLATE_NAME}/releases/tag/${NEW_VERSION}"

# Wait for GitHub Actions to trigger
echo
echo -e "${YELLOW}Waiting for GitHub Actions to process release...${NC}"
sleep 5

# Check if workflow exists and get its status
echo -e "Checking GitHub Actions status..."
WORKFLOW_RUNS=$(gh run list --repo "open-service-portal/${TEMPLATE_NAME}" --limit 1 --json status,event,headBranch,conclusion,url 2>/dev/null)

if [ -n "${WORKFLOW_RUNS}" ] && [ "${WORKFLOW_RUNS}" != "[]" ]; then
    RUN_STATUS=$(echo "${WORKFLOW_RUNS}" | jq -r '.[0].status')
    RUN_URL=$(echo "${WORKFLOW_RUNS}" | jq -r '.[0].url')
    
    echo -e "Workflow status: ${YELLOW}${RUN_STATUS}${NC}"
    echo "Workflow URL: ${RUN_URL}"
    
    # Wait for workflow to complete (max 2 minutes)
    COUNTER=0
    while [ "${RUN_STATUS}" = "in_progress" ] || [ "${RUN_STATUS}" = "queued" ]; do
        if [ $COUNTER -gt 24 ]; then  # 24 * 5 seconds = 2 minutes
            echo -e "${YELLOW}Workflow still running after 2 minutes${NC}"
            break
        fi
        echo -n "."
        sleep 5
        COUNTER=$((COUNTER + 1))
        WORKFLOW_RUNS=$(gh run list --repo "open-service-portal/${TEMPLATE_NAME}" --limit 1 --json status,conclusion)
        RUN_STATUS=$(echo "${WORKFLOW_RUNS}" | jq -r '.[0].status')
    done
    
    echo
    RUN_CONCLUSION=$(echo "${WORKFLOW_RUNS}" | jq -r '.[0].conclusion')
    if [ "${RUN_CONCLUSION}" = "success" ]; then
        echo -e "${GREEN}✅ GitHub Actions workflow completed successfully${NC}"
    elif [ "${RUN_CONCLUSION}" = "failure" ]; then
        echo -e "${RED}❌ GitHub Actions workflow failed${NC}"
        echo "Please check: ${RUN_URL}"
    else
        echo -e "${YELLOW}⏳ GitHub Actions workflow status: ${RUN_STATUS}${NC}"
        echo "Check progress at: ${RUN_URL}"
    fi
else
    echo -e "${YELLOW}No GitHub Actions workflow found (might not be configured)${NC}"
fi

# Check for catalog PR
echo
echo -e "${GREEN}Looking for catalog PR...${NC}"
sleep 3

# Search for PRs created in the last few minutes
CATALOG_PRS=$(gh pr list --repo "open-service-portal/catalog" --limit 5 --json title,url,createdAt,author --jq '.[] | select(.author.login == "github-actions[bot]")' 2>/dev/null)

if [ -n "${CATALOG_PRS}" ]; then
    # Get the most recent PR URL
    PR_URL=$(echo "${CATALOG_PRS}" | jq -r '.url' | head -1)
    PR_TITLE=$(echo "${CATALOG_PRS}" | jq -r '.title' | head -1)
    
    if [[ "${PR_TITLE}" == *"${TEMPLATE_NAME}"* ]] || [[ "${PR_TITLE}" == *"${NEW_VERSION}"* ]]; then
        echo -e "${GREEN}✅ Catalog PR found:${NC}"
        echo "Title: ${PR_TITLE}"
        echo "URL: ${PR_URL}"
        echo
        echo -e "${YELLOW}To merge the catalog PR:${NC}"
        echo "gh pr merge ${PR_URL} --auto --squash"
    else
        echo -e "${YELLOW}Recent catalog PR found but might be for different template:${NC}"
        echo "URL: ${PR_URL}"
        echo
        echo "Check all catalog PRs at:"
        echo "https://github.com/open-service-portal/catalog/pulls"
    fi
else
    echo -e "${YELLOW}No catalog PR found yet (might take a few moments)${NC}"
    echo "Check for new PRs at:"
    echo "https://github.com/open-service-portal/catalog/pulls"
fi

echo
echo -e "${GREEN}Release process complete!${NC}"
echo
echo "Next steps:"
echo "1. Check GitHub Actions: https://github.com/open-service-portal/${TEMPLATE_NAME}/actions"
echo "2. Review catalog PR: https://github.com/open-service-portal/catalog/pulls"
echo "3. Deploy to cluster: flux reconcile source git catalog"