#!/bin/bash
# Test Script for Backstage New Frontend System Examples
#
# This script helps you quickly test code examples from the documentation
# in a clean Docker environment.
#
# Usage:
#   ./test-script.sh [example-name]
#
# Examples:
#   ./test-script.sh auth-oidc
#   ./test-script.sh app-basic
#   ./test-script.sh api-custom

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOCKER_IMAGE="backstage-test"
CONTAINER_NAME="backstage-test-container"
FRONTEND_PORT=3000
BACKEND_PORT=7007

# Functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if Docker is running
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
    log_success "Docker is running"
}

# Build Docker image
build_image() {
    log_info "Building Docker image..."
    if docker build -t $DOCKER_IMAGE -f Dockerfile.test . ; then
        log_success "Docker image built successfully"
    else
        log_error "Failed to build Docker image"
        exit 1
    fi
}

# Stop and remove existing container
cleanup_container() {
    if docker ps -a | grep -q $CONTAINER_NAME; then
        log_info "Removing existing container..."
        docker rm -f $CONTAINER_NAME > /dev/null 2>&1 || true
        log_success "Existing container removed"
    fi
}

# Test auth-oidc example
test_auth_oidc() {
    log_info "Testing OIDC/PKCE auth example..."

    docker run -d --name $CONTAINER_NAME \
        -p $FRONTEND_PORT:3000 \
        -p $BACKEND_PORT:7007 \
        -v "$(pwd)/auth-providers:/examples" \
        $DOCKER_IMAGE \
        sleep infinity

    log_info "Copying example files..."
    docker exec $CONTAINER_NAME bash -c "
        cd /app/packages/app/src
        mkdir -p apis modules/auth modules/signInPage
        cp /examples/custom-oidc-ref.ts apis/ 2>/dev/null || echo 'Ref file not found'
    "

    log_success "Example setup complete"
    log_info "Next steps:"
    echo "  1. Edit App.tsx to import and use the OIDC auth API"
    echo "  2. Start the app: docker exec -it $CONTAINER_NAME yarn dev"
    echo "  3. Open browser: http://localhost:$FRONTEND_PORT"
    echo ""
    echo "To access container: docker exec -it $CONTAINER_NAME bash"
}

# Test basic app example
test_app_basic() {
    log_info "Testing basic app creation..."

    docker run -d --name $CONTAINER_NAME \
        -p $FRONTEND_PORT:3000 \
        -p $BACKEND_PORT:7007 \
        $DOCKER_IMAGE \
        bash -c "cd /app && yarn dev"

    log_success "Basic app started"
    log_info "App running at:"
    echo "  Frontend: http://localhost:$FRONTEND_PORT"
    echo "  Backend: http://localhost:$BACKEND_PORT"
    echo ""
    echo "To view logs: docker logs -f $CONTAINER_NAME"
}

# Show usage
usage() {
    echo "Usage: $0 [example-name]"
    echo ""
    echo "Available examples:"
    echo "  auth-oidc    - Test OIDC/PKCE authentication"
    echo "  app-basic    - Test basic app creation"
    echo "  api-custom   - Test custom utility API"
    echo ""
    echo "Examples:"
    echo "  $0 auth-oidc"
    echo "  $0 app-basic"
}

# Main execution
main() {
    local example="${1:-}"

    if [ -z "$example" ]; then
        usage
        exit 1
    fi

    log_info "Starting test environment for: $example"
    echo ""

    check_docker
    cleanup_container

    # Check if image exists, build if not
    if ! docker images | grep -q $DOCKER_IMAGE; then
        log_warning "Docker image not found, building..."
        build_image
    else
        log_success "Docker image found"
    fi

    case "$example" in
        auth-oidc)
            test_auth_oidc
            ;;
        app-basic)
            test_app_basic
            ;;
        api-custom)
            log_error "API custom example not yet implemented"
            exit 1
            ;;
        *)
            log_error "Unknown example: $example"
            usage
            exit 1
            ;;
    esac

    echo ""
    log_success "Test environment ready!"
    echo ""
    log_info "Useful commands:"
    echo "  View logs:     docker logs -f $CONTAINER_NAME"
    echo "  Access shell:  docker exec -it $CONTAINER_NAME bash"
    echo "  Stop:          docker stop $CONTAINER_NAME"
    echo "  Remove:        docker rm -f $CONTAINER_NAME"
    echo "  Cleanup all:   docker rm -f $CONTAINER_NAME && docker rmi $DOCKER_IMAGE"
}

# Run main function
main "$@"
