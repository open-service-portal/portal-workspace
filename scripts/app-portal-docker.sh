#!/bin/bash
# Build and run Backstage Docker container with SOPS secrets

set -e

# Configuration
IMAGE_NAME="app-portal"
REGISTRY="ghcr.io/open-service-portal"
CONTAINER_NAME="app-portal"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Change to app-portal directory
cd "$(dirname "$0")/../app-portal"

# Function to build the image
build_image() {
    echo -e "${YELLOW}Building Docker image...${NC}"
    
    # Set dummy env var for build (build doesn't need real secrets)
    export AUTH_GITHUB_APP_PRIVATE_KEY_FILE=/dev/null
    
    # Build backend
    echo "Building backend..."
    yarn build:backend
    
    # Build Docker image
    echo "Building Docker image..."
    yarn build-image
    
    # Tag with our image name
    docker tag backstage:latest ${IMAGE_NAME}:latest
    
    echo -e "${GREEN}✓ Docker image built successfully as ${IMAGE_NAME}:latest${NC}"
}

# Function to run the container
run_container() {
    echo -e "${YELLOW}Starting ${CONTAINER_NAME} container...${NC}"
    
    # Check if secrets exist, if not decrypt them
    if [ ! -f .env ] || [ ! -f github-app-key.pem ]; then
        echo "Decrypting secrets with SOPS..."
        sops -d --input-type dotenv --output-type dotenv .env.enc > .env
        sops -d github-app-key.pem.enc > github-app-key.pem
        echo -e "${GREEN}✓ Secrets decrypted${NC}"
    fi
    
    # Stop existing container if running
    docker stop ${CONTAINER_NAME} 2>/dev/null && docker rm ${CONTAINER_NAME} 2>/dev/null || true
    
    # Prepare docker run command
    DOCKER_CMD="docker run -d --name ${CONTAINER_NAME} \
        --env-file .env \
        -v $(pwd)/github-app-key.pem:/app/github-app-key.pem:ro \
        -e AUTH_GITHUB_APP_PRIVATE_KEY_FILE=/app/github-app-key.pem \
        -p 7007:7007"
    
    # Add app-config.local.yaml if it exists
    if [ -f app-config.local.yaml ]; then
        echo "Including app-config.local.yaml..."
        DOCKER_CMD="$DOCKER_CMD \
            -v $(pwd)/app-config.local.yaml:/app/app-config.local.yaml:ro"
        CONFIG_ARGS="--config app-config.yaml --config app-config.local.yaml"
    else
        CONFIG_ARGS="--config app-config.yaml"
    fi
    
    # Run the container
    eval "$DOCKER_CMD ${IMAGE_NAME}:latest node packages/backend $CONFIG_ARGS"
    
    echo -e "${GREEN}✓ Container started${NC}"
    echo "Backstage is available at: http://localhost:7007"
    echo ""
    echo "View logs: docker logs -f ${CONTAINER_NAME}"
    echo "Stop: docker stop ${CONTAINER_NAME}"
}

# Function to show logs
show_logs() {
    docker logs -f ${CONTAINER_NAME}
}

# Function to stop container
stop_container() {
    echo -e "${YELLOW}Stopping ${CONTAINER_NAME} container...${NC}"
    docker stop ${CONTAINER_NAME} && docker rm ${CONTAINER_NAME}
    echo -e "${GREEN}✓ Container stopped${NC}"
}

# Function to push image to registry
push_image() {
    echo -e "${YELLOW}Pushing image to GitHub Container Registry...${NC}"
    
    # Check if image exists
    if ! docker images ${IMAGE_NAME}:latest --format "{{.Repository}}" | grep -q ${IMAGE_NAME}; then
        echo -e "${RED}Error: Image ${IMAGE_NAME}:latest not found. Run 'build' first.${NC}"
        exit 1
    fi
    
    # Get version tag (use git tag if available, otherwise date)
    VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "v$(date +%Y%m%d-%H%M%S)")
    
    # Tag images
    echo "Tagging images..."
    docker tag ${IMAGE_NAME}:latest ${REGISTRY}/${IMAGE_NAME}:latest
    docker tag ${IMAGE_NAME}:latest ${REGISTRY}/${IMAGE_NAME}:${VERSION}
    
    # Push images
    echo "Pushing ${REGISTRY}/${IMAGE_NAME}:latest..."
    docker push ${REGISTRY}/${IMAGE_NAME}:latest
    
    echo "Pushing ${REGISTRY}/${IMAGE_NAME}:${VERSION}..."
    docker push ${REGISTRY}/${IMAGE_NAME}:${VERSION}
    
    echo -e "${GREEN}✓ Images pushed successfully${NC}"
    echo "  - ${REGISTRY}/${IMAGE_NAME}:latest"
    echo "  - ${REGISTRY}/${IMAGE_NAME}:${VERSION}"
}

# Main script
case "${1:-}" in
    build)
        build_image
        ;;
    run)
        run_container
        ;;
    push)
        push_image
        ;;
    logs)
        show_logs
        ;;
    stop)
        stop_container
        ;;
    restart)
        stop_container
        run_container
        ;;
    *)
        echo "Usage: $0 {build|run|push|logs|stop|restart}"
        echo ""
        echo "Commands:"
        echo "  build    - Build the Docker image"
        echo "  run      - Run the container (builds if needed)"
        echo "  push     - Push image to GitHub Container Registry"
        echo "  logs     - Show container logs"
        echo "  stop     - Stop and remove the container"
        echo "  restart  - Stop and restart the container"
        echo ""
        echo "The script will:"
        echo "  - Automatically decrypt secrets with SOPS"
        echo "  - Mount app-config.local.yaml if it exists"
        echo "  - Use only app-config.yaml (SQLite) for development"
        exit 1
        ;;
esac