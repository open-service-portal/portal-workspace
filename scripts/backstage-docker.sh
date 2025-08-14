#!/bin/bash
# Build and run Backstage Docker container with SOPS secrets

set -e

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
    
    echo -e "${GREEN}✓ Docker image built successfully${NC}"
}

# Function to run the container
run_container() {
    echo -e "${YELLOW}Starting Backstage container...${NC}"
    
    # Check if secrets exist, if not decrypt them
    if [ ! -f .env ] || [ ! -f github-app-key.pem ]; then
        echo "Decrypting secrets with SOPS..."
        sops -d --input-type dotenv --output-type dotenv .env.enc > .env
        sops -d github-app-key.pem.enc > github-app-key.pem
        echo -e "${GREEN}✓ Secrets decrypted${NC}"
    fi
    
    # Stop existing container if running
    docker stop backstage 2>/dev/null && docker rm backstage 2>/dev/null || true
    
    # Prepare docker run command
    DOCKER_CMD="docker run -d --name backstage \
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
    eval "$DOCKER_CMD backstage:latest node packages/backend $CONFIG_ARGS"
    
    echo -e "${GREEN}✓ Container started${NC}"
    echo "Backstage is available at: http://localhost:7007"
    echo ""
    echo "View logs: docker logs -f backstage"
    echo "Stop: docker stop backstage"
}

# Function to show logs
show_logs() {
    docker logs -f backstage
}

# Function to stop container
stop_container() {
    echo -e "${YELLOW}Stopping Backstage container...${NC}"
    docker stop backstage && docker rm backstage
    echo -e "${GREEN}✓ Container stopped${NC}"
}

# Main script
case "${1:-}" in
    build)
        build_image
        ;;
    run)
        run_container
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
        echo "Usage: $0 {build|run|logs|stop|restart}"
        echo ""
        echo "Commands:"
        echo "  build    - Build the Docker image"
        echo "  run      - Run the container (builds if needed)"
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