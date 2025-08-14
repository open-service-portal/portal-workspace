# Kubernetes Deployment Guide

This guide covers deploying Backstage to Kubernetes for both local development and production environments.

## Overview

We use a GitOps approach with:
- **Flux** for continuous deployment
- **SOPS** with age encryption for secret management
- **Kustomize** for environment-specific configurations

## Table of Contents
- [Prerequisites](#prerequisites)
- [Local Development Setup](#local-development-setup)
- [Production Deployment](#production-deployment)
- [Secret Management](#secret-management)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools
- `kubectl` - Kubernetes CLI
- `helm` - Package manager for Kubernetes
- `sops` - Secret encryption tool
- `age` - Encryption tool used by SOPS
- `flux` CLI (optional, for GitOps)

### Installation
```bash
# macOS
brew install kubectl helm sops age fluxcd/tap/flux

# Linux
# Install kubectl: https://kubernetes.io/docs/tasks/tools/
# Install helm: https://helm.sh/docs/intro/install/
# Install sops: https://github.com/getsops/sops/releases
# Install age: https://github.com/FiloSottile/age/releases
# Install flux: https://fluxcd.io/flux/installation/
```

---

## Local Development Setup

### Step 1: Prepare Your Kubernetes Cluster

You can use any local Kubernetes:
- **Kind**: `kind create cluster --name backstage-local`
- **Rancher Desktop**: Enable Kubernetes in settings
- **Minikube**: `minikube start`
- **Docker Desktop**: Enable Kubernetes in settings

### Step 2: Setup Cluster Components

```bash
# Run the universal setup script
./scripts/setup-cluster.sh

# This installs:
# - NGINX Ingress Controller
# - Flux GitOps toolkit
# - Crossplane v1.17
# - Backstage service account
```

### Step 3: Generate Your Personal Age Key

```bash
# Generate your personal age key (one-time)
./scripts/manage-sops-keys.sh generate

# Show your public key
./scripts/manage-sops-keys.sh show

# Share your public key with the team to be added to .sops.yaml
```

### Step 4: Configure Secrets

For local development, you have two options:

#### Option A: Use Your Personal Key (Simplest for Local)
```bash
# Your personal key is already in the default location
# SOPS will use it automatically

# Encrypt secrets
./scripts/encrypt-secrets.sh

# For local testing without Flux, decrypt manually:
sops -d deploy-backstage/base/backstage/secret.enc.yaml | kubectl apply -f -
```

#### Option B: Use Project Key (Mimics Production)
```bash
# Get the project key from your team's secure storage
# Save it locally (NOT in the repo!)
mkdir -p ~/.config/sops/project-keys
# Save project key to: ~/.config/sops/project-keys/open-service-portal.txt

# Upload to your local cluster
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=~/.config/sops/project-keys/open-service-portal.txt
```

### Step 5: Deploy Backstage

#### Without Flux (Direct Apply)
```bash
# Apply the manifests directly
kubectl apply -k deploy-backstage/overlays/development/

# Check deployment
kubectl get pods -n backstage
kubectl get ingress -n backstage
```

#### With Flux (GitOps)
```bash
# Fork and clone deploy-backstage to your GitHub
# Update the GitRepository URL in clusters/local/backstage/source.yaml

# Apply Flux resources
kubectl apply -f deploy-backstage/clusters/local/backstage/source.yaml
kubectl apply -f deploy-backstage/clusters/local/backstage/kustomization.yaml

# Watch Flux sync
flux get kustomizations -n flux-system --watch
```

### Step 6: Access Backstage

```bash
# Get the ingress URL
kubectl get ingress -n backstage

# For local clusters, you might need port-forwarding
kubectl port-forward -n backstage svc/backstage 7007:80

# Access at http://localhost:7007
```

---

## Production Deployment

### Step 1: Cluster Setup

For production clusters (EKS, GKE, AKS, etc.):

```bash
# Ensure kubectl is configured for production cluster
kubectl config current-context

# Run setup (same script, works everywhere)
./scripts/setup-cluster.sh
```

### Step 2: Project Key Management

Production uses a dedicated project key that's shared among CI/CD systems and the cluster.

#### Generate Project Key (One-time by Team Lead)
```bash
# Generate project-specific key
age-keygen -o project-key.txt

# Store securely in your secrets manager:
# - AWS Secrets Manager
# - Azure Key Vault
# - HashiCorp Vault
# - 1Password Team

# Get the public key
age-keygen -y project-key.txt
# Add this public key to deploy-backstage/.sops.yaml
```

#### Upload Project Key to Cluster
```bash
# From your secure environment (CI/CD or secure workstation)
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=project-key.txt

# Verify
kubectl get secret sops-age -n flux-system
```

### Step 3: Configure Production Secrets

```bash
# On a secure workstation with access to project key
export SOPS_AGE_KEY_FILE=/path/to/project-key.txt

# Create production secrets
cd deploy-backstage
sops -e production-secret.yaml > base/backstage/secret.enc.yaml

# Commit encrypted secret
git add base/backstage/secret.enc.yaml
git commit -m "Update production secrets"
git push
```

### Step 4: Deploy with Flux

```bash
# Bootstrap Flux (one-time)
flux bootstrap github \
  --owner=open-service-portal \
  --repository=deploy-backstage \
  --branch=main \
  --path=clusters/production

# Flux will automatically:
# 1. Pull the repository
# 2. Decrypt secrets using sops-age secret
# 3. Apply manifests
# 4. Keep everything in sync
```

### Step 5: Configure DNS and TLS

```yaml
# deploy-backstage/overlays/production/ingress-patch.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: backstage
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
    - hosts:
        - backstage.yourdomain.com
      secretName: backstage-tls
  rules:
    - host: backstage.yourdomain.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: backstage
                port:
                  number: 80
```

---

## Secret Management

### Key Types and Usage

| Key Type | Purpose | Who Has It | Where It's Used |
|----------|---------|------------|-----------------|
| Personal Key | Individual developer access | Each developer | Local development, encrypting secrets |
| Project Key | Production decryption | CI/CD, Ops team | Kubernetes cluster, CI/CD pipelines |
| Team Keys | Shared team access | All team members | Reading/updating secrets |

### SOPS Configuration (.sops.yaml)

```yaml
# deploy-backstage/.sops.yaml
creation_rules:
  - path_regex: .*\.enc\.yaml$
    age: >-
      age1personal...,  # Alice (developer)
      age1personal...,  # Bob (developer)
      age1project...    # Project key (in cluster & CI/CD)
```

### Secret Workflow

#### Adding a New Secret
```bash
# 1. Decrypt existing secret
sops deploy-backstage/base/backstage/secret.enc.yaml

# 2. Edit and save

# 3. Re-encrypt (automatic on save)
```

#### Adding a New Team Member
```bash
# 1. Get their public key
./scripts/manage-sops-keys.sh show  # (they run this)

# 2. Add to .sops.yaml
vim deploy-backstage/.sops.yaml

# 3. Update existing secrets
cd deploy-backstage
sops updatekeys base/backstage/secret.enc.yaml

# 4. Commit changes
git add .sops.yaml base/backstage/secret.enc.yaml
git commit -m "Add Alice's public key to SOPS"
git push
```

#### Rotating Secrets
```bash
# 1. Update the secret values
sops deploy-backstage/base/backstage/secret.enc.yaml

# 2. Flux automatically deploys (or manually apply)
kubectl apply -k deploy-backstage/overlays/production/

# 3. Restart pods if needed
kubectl rollout restart deployment/backstage -n backstage
```

---

## Troubleshooting

### Common Issues

#### SOPS Can't Decrypt
```bash
# Check if you have the right key
sops -d --verbose deploy-backstage/base/backstage/secret.enc.yaml

# Check available keys
ls -la ~/.config/sops/age/

# Try with specific key
export SOPS_AGE_KEY_FILE=/path/to/key.txt
sops -d deploy-backstage/base/backstage/secret.enc.yaml
```

#### Flux Can't Decrypt in Cluster
```bash
# Check if sops-age secret exists
kubectl get secret sops-age -n flux-system

# Check Flux logs
kubectl logs -n flux-system deployment/kustomize-controller

# Re-create secret if needed
kubectl delete secret sops-age -n flux-system
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=/path/to/project-key.txt
```

#### Ingress Not Working
```bash
# Check ingress controller
kubectl get pods -n ingress-nginx

# Check ingress resource
kubectl describe ingress backstage -n backstage

# For local development, use port-forward
kubectl port-forward -n backstage svc/backstage 7007:80
```

### Verification Commands

```bash
# Verify cluster setup
./scripts/manage-sops-keys.sh verify

# Check all components
kubectl get pods -n flux-system
kubectl get pods -n backstage
kubectl get ingress -n backstage

# Check Flux sync status
flux get all -n flux-system

# View logs
kubectl logs -n backstage -l app=backstage --tail=100
```

---

## Security Best Practices

1. **Never commit unencrypted secrets**
2. **Never commit private keys** (age keys)
3. **Use separate keys for production**
4. **Rotate secrets regularly**
5. **Audit .sops.yaml changes** (who has access)
6. **Use RBAC in Kubernetes** to limit secret access
7. **Store project keys in secure vaults**, not on developer machines

---

## CI/CD Integration

### GitHub Actions Example
```yaml
# .github/workflows/deploy.yml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup SOPS
        run: |
          curl -LO https://github.com/getsops/sops/releases/download/v3.8.1/sops-v3.8.1.linux.amd64
          chmod +x sops-v3.8.1.linux.amd64
          sudo mv sops-v3.8.1.linux.amd64 /usr/local/bin/sops
      
      - name: Decrypt and validate secrets
        env:
          SOPS_AGE_KEY: ${{ secrets.PROJECT_AGE_KEY }}
        run: |
          echo "$SOPS_AGE_KEY" > /tmp/key.txt
          export SOPS_AGE_KEY_FILE=/tmp/key.txt
          sops -d deploy-backstage/base/backstage/secret.enc.yaml > /dev/null
          rm /tmp/key.txt
      
      # Flux handles actual deployment via GitOps
```

---

## Summary

### Local Development Flow
1. Personal age key for encryption/decryption
2. Direct `kubectl apply` or local Flux
3. Port-forwarding for access
4. Development overlay configuration

### Production Flow
1. Project key in cluster and CI/CD
2. Flux GitOps for deployment
3. Proper DNS and TLS
4. Production overlay configuration
5. Automated sync from Git

### Key Differences
| Aspect | Local | Production |
|--------|-------|------------|
| Key Used | Personal | Project |
| Deployment | Manual or Flux | Always Flux |
| Access | Port-forward | Ingress/DNS |
| TLS | Optional | Required |
| Resources | Minimal | Full |
| Replicas | 1 | Multiple |