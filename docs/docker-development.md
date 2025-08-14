# Docker Development Guide

This guide explains how to build and run Backstage in Docker containers for local development and production deployments.

## Overview

The Backstage Docker image:
- Runs the backend server which also serves the frontend as static files
- Requires secrets to be provided at runtime (not baked into the image)
- Supports both SQLite (development) and PostgreSQL (production)
- Exposes port 7007 for both API and web interface

## Prerequisites

- Docker or Rancher Desktop installed and running
- SOPS configured with your SSH key (for secret decryption)
- Node.js and Yarn (for building the application)

## Quick Start

Use the provided script for the easiest experience:

```bash
# From the workspace directory
cd app-portal

# Build the Docker image
../scripts/backstage-docker.sh build

# Run the container (auto-decrypts secrets)
../scripts/backstage-docker.sh run

# View logs
../scripts/backstage-docker.sh logs

# Stop the container
../scripts/backstage-docker.sh stop
```

Access Backstage at http://localhost:7007

## Building the Docker Image

### Security Best Practice

The Docker image is built WITHOUT secrets. This follows Docker security best practices:
- No secrets in the image layers
- Image can be safely pushed to registries
- Secrets are only provided at runtime

### Build Process

1. **Build the backend** (required before Docker build):
```bash
cd app-portal
yarn build:backend
```

2. **Build the Docker image**:
```bash
yarn build-image
```

This creates an image tagged as `backstage:latest`.

### What's in the Image?

- Node.js 20 runtime on Debian Bookworm Slim
- Backstage backend application
- Frontend static files (pre-built)
- Configuration files (app-config.yaml)
- All production dependencies

### What's NOT in the Image?

- Environment variables with secrets
- Private keys (.pem files)
- Decrypted .env files
- app-config.local.yaml (mounted at runtime if needed)

## Running the Container

### With SOPS (Recommended)

1. **Decrypt secrets**:
```bash
cd app-portal
sops -d --input-type dotenv --output-type dotenv .env.enc > .env
sops -d github-app-key.pem.enc > github-app-key.pem
```

2. **Run the container**:
```bash
docker run -d --name backstage \
  --env-file .env \
  -v $(pwd)/github-app-key.pem:/app/github-app-key.pem:ro \
  -e AUTH_GITHUB_APP_PRIVATE_KEY_FILE=/app/github-app-key.pem \
  -p 7007:7007 \
  backstage:latest
```

### With Local Configuration

If you have an `app-config.local.yaml` with additional configuration (e.g., Kubernetes):

```bash
docker run -d --name backstage \
  --env-file .env \
  -v $(pwd)/github-app-key.pem:/app/github-app-key.pem:ro \
  -v $(pwd)/app-config.local.yaml:/app/app-config.local.yaml:ro \
  -e AUTH_GITHUB_APP_PRIVATE_KEY_FILE=/app/github-app-key.pem \
  -p 7007:7007 \
  backstage:latest \
  node packages/backend --config app-config.yaml --config app-config.local.yaml
```

### Environment Variables

Required environment variables (stored in `.env`):
- `AUTH_GITHUB_CLIENT_ID` - GitHub App OAuth Client ID
- `AUTH_GITHUB_CLIENT_SECRET` - GitHub App OAuth Client Secret
- `AUTH_GITHUB_APP_ID` - GitHub App ID
- `AUTH_GITHUB_APP_INSTALLATION_ID` - GitHub App Installation ID
- `AUTH_GITHUB_APP_PRIVATE_KEY_FILE` - Path to private key inside container

Optional:
- `K8S_SERVICE_ACCOUNT_TOKEN` - For Kubernetes integration
- `APP_CONFIG_app_title` - Custom app title

## Production Deployment

For production, you'll typically want to:

1. **Use PostgreSQL instead of SQLite**:
```bash
docker run -d --name backstage \
  --env-file .env \
  -e POSTGRES_HOST=your-postgres-host \
  -e POSTGRES_PORT=5432 \
  -e POSTGRES_USER=backstage \
  -e POSTGRES_PASSWORD=your-password \
  -v $(pwd)/github-app-key.pem:/app/github-app-key.pem:ro \
  -e AUTH_GITHUB_APP_PRIVATE_KEY_FILE=/app/github-app-key.pem \
  -p 7007:7007 \
  backstage:latest
```

2. **Use Docker Compose** (see `deploy-backstage` repository)

3. **Deploy to Kubernetes** (see `deploy-backstage` repository)

## Troubleshooting

### Container won't start

Check logs for errors:
```bash
docker logs backstage
```

Common issues:
- Missing environment variables
- Private key file not mounted correctly
- Port 7007 already in use

### Authentication errors

Ensure:
- All GitHub App environment variables are set
- Private key file is mounted and readable
- GitHub App is properly installed in your organization

### Database connection errors

If you see PostgreSQL connection errors but want to use SQLite:
```bash
# Run with only base config (uses SQLite)
docker run -d --name backstage \
  --env-file .env \
  -v $(pwd)/github-app-key.pem:/app/github-app-key.pem:ro \
  -e AUTH_GITHUB_APP_PRIVATE_KEY_FILE=/app/github-app-key.pem \
  -p 7007:7007 \
  backstage:latest \
  node packages/backend --config app-config.yaml
```

## Docker Compose Example

Create a `docker-compose.yml`:

```yaml
version: '3.8'

services:
  backstage:
    image: backstage:latest
    ports:
      - "7007:7007"
    env_file:
      - .env
    environment:
      AUTH_GITHUB_APP_PRIVATE_KEY_FILE: /app/github-app-key.pem
    volumes:
      - ./github-app-key.pem:/app/github-app-key.pem:ro
      - ./app-config.local.yaml:/app/app-config.local.yaml:ro
    command: >
      node packages/backend
      --config app-config.yaml
      --config app-config.local.yaml
```

Run with:
```bash
docker-compose up -d
```

## Security Considerations

1. **Never build secrets into the image**
   - Use environment variables at runtime
   - Mount secret files as volumes

2. **Use read-only mounts** for sensitive files:
   ```bash
   -v $(pwd)/github-app-key.pem:/app/github-app-key.pem:ro
   ```

3. **Rotate secrets regularly**
   - Update SOPS-encrypted files
   - Rebuild containers with new secrets

4. **Limit container privileges**
   - Run as non-root user (already configured)
   - Use security options if needed

## Next Steps

- For Kubernetes deployment, see the [deploy-backstage](https://github.com/open-service-portal/deploy-backstage) repository
- For secret management, see [SOPS documentation](./sops-secret-management.md)
- For local Kubernetes setup, see [Local Kubernetes Setup](./local-kubernetes-setup.md)