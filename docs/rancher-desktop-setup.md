# Rancher Desktop Setup for Backstage

This guide walks through setting up Rancher Desktop as a local Kubernetes environment with Crossplane for Backstage development.

## Why Rancher Desktop?

Rancher Desktop provides a lightweight, open-source alternative to Docker Desktop that includes:
- Built-in Kubernetes cluster (K3s)
- Choice of container runtime (containerd or dockerd)
- No licensing restrictions
- Cross-platform support (macOS, Windows, Linux)
- Easy cluster reset and configuration

## Prerequisites

- macOS, Windows, or Linux operating system
- 8GB RAM minimum (16GB recommended)
- 20GB free disk space
- Admin/sudo access for installation

## Installation

### macOS

Using Homebrew:
```bash
brew install --cask rancher
```

Or download from: https://rancherdesktop.io/

### Windows

Download the installer from: https://rancherdesktop.io/

### Linux

Download the appropriate package (.deb, .rpm, or .AppImage) from: https://rancherdesktop.io/

For Ubuntu/Debian:
```bash
wget https://github.com/rancher-sandbox/rancher-desktop/releases/download/v1.12.0/rancher-desktop_1.12.0_amd64.deb
sudo dpkg -i rancher-desktop_1.12.0_amd64.deb
```

## Initial Configuration

1. **Launch Rancher Desktop**
   - On first launch, you'll see the setup wizard
   - Select Kubernetes version: Choose "stable" (recommended)
   - Container runtime: Select "containerd" (recommended for Kubernetes workloads)
   - Enable Kubernetes: Ensure this is checked

2. **Wait for Initialization**
   - Rancher Desktop will download and set up the Kubernetes cluster
   - This may take 5-10 minutes on first run

3. **Verify Installation**
   ```bash
   # Check Rancher Desktop CLI
   rdctl version
   
   # Check Kubernetes access
   kubectl cluster-info
   kubectl get nodes
   ```

## Automated Setup with Crossplane

We provide a script that automates the entire setup process:

```bash
# Run from the portal-workspace directory
./scripts/setup-rancher-k8s.sh
```

This script will:
1. Verify Rancher Desktop is installed and running
2. Configure Rancher Desktop settings (with Traefik disabled)
3. Install Crossplane v1.17.0
4. Install provider-kubernetes
5. Install NGINX Ingress Controller automatically
6. Create a service account for Backstage
7. Run a smoke test to verify everything works

**Note:** The script disables Traefik by default to avoid conflicts and automatically installs NGINX Ingress Controller for a consistent development experience.

## Manual Setup Steps

If you prefer to set up manually or the script fails:

### 1. Start Rancher Desktop

```bash
# Start Rancher Desktop (if not already running)
rdctl start

# Wait for Kubernetes to be ready
kubectl wait --for=condition=Ready nodes --all --timeout=300s
```

### 2. Install Helm (if not installed)

```bash
# macOS
brew install helm

# Linux
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### 3. Install Crossplane

```bash
# Add Helm repository
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update

# Install Crossplane
helm install crossplane \
  --namespace crossplane-system \
  --create-namespace \
  --version 1.17.0 \
  crossplane-stable/crossplane \
  --wait

# Verify installation
kubectl get pods -n crossplane-system
```

### 4. Install provider-kubernetes

```bash
# Apply provider configuration
cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-kubernetes
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-kubernetes:v0.14.0
EOF

# Wait for provider to be healthy
kubectl wait --for=condition=Healthy provider/provider-kubernetes --timeout=300s

# Create ProviderConfig
cat <<EOF | kubectl apply -f -
apiVersion: kubernetes.crossplane.io/v1alpha1
kind: ProviderConfig
metadata:
  name: kubernetes-provider
spec:
  credentials:
    source: InjectedIdentity
EOF
```

### 5. Verify Installation

Run the smoke test to create a ConfigMap via Crossplane:

```bash
# Create test namespace
kubectl create namespace crossplane-test

# Create ConfigMap via Crossplane
cat <<EOF | kubectl apply -f -
apiVersion: kubernetes.crossplane.io/v1alpha1
kind: Object
metadata:
  name: smoke-test-configmap
spec:
  forProvider:
    manifest:
      apiVersion: v1
      kind: ConfigMap
      metadata:
        name: crossplane-smoke-test
        namespace: crossplane-test
      data:
        message: "Crossplane is working!"
  providerConfigRef:
    name: kubernetes-provider
EOF

# Verify ConfigMap was created
kubectl get configmap crossplane-smoke-test -n crossplane-test
```

## Backstage Integration

### 1. Create Service Account

```bash
# Create service account
kubectl create serviceaccount backstage-k8s-sa -n default

# Create cluster role binding
kubectl create clusterrolebinding backstage-k8s-sa-binding \
  --clusterrole=cluster-admin \
  --serviceaccount=default:backstage-k8s-sa

# Generate token (valid for 10 years)
export K8S_SERVICE_ACCOUNT_TOKEN=$(kubectl create token backstage-k8s-sa -n default --duration=87600h)

# Display token
echo "Service Account Token: $K8S_SERVICE_ACCOUNT_TOKEN"
```

### 2. Configure Backstage

Add to your `app-config.local.yaml` (create if it doesn't exist):

```yaml
kubernetes:
  serviceLocatorMethod:
    type: 'multiTenant'
  clusterLocatorMethods:
    - type: 'config'
      clusters:
        - url: https://127.0.0.1:6443
          name: rancher-desktop
          authProvider: 'serviceAccount'
          skipTLSVerify: true
          serviceAccountToken: ${K8S_SERVICE_ACCOUNT_TOKEN}

# For Crossplane plugin (if installed)
crossplane:
  providers:
    - name: crossplane-provider-kubernetes
      package: xpkg.upbound.io/crossplane-contrib/provider-kubernetes:v0.14.0
```

### 3. Set Environment Variable

```bash
# Add to your .envrc file (if using direnv) or shell profile
export K8S_SERVICE_ACCOUNT_TOKEN='<your-token-here>'

# If using direnv, allow the .envrc file
direnv allow
```

## Rancher Desktop Settings

### Recommended Configuration

1. **Kubernetes Settings**
   - Version: stable
   - Port: 6443 (default)
   - Enable Traefik: **Disabled** (to avoid conflicts)

2. **Container Runtime**
   - Engine: containerd (recommended for Kubernetes)
   - Namespace: k8s.io (default)

3. **Resources**
   - Memory: 4GB minimum, 8GB recommended
   - CPU: 2 cores minimum, 4 cores recommended

### Configuration via CLI

```bash
# Set container engine
rdctl set --container-engine=containerd

# Enable Kubernetes
rdctl set --kubernetes-enabled=true

# Set Kubernetes version
rdctl set --kubernetes-version=stable

# Disable Traefik ingress controller
rdctl set --kubernetes.options.traefik=false

# Configure resources (example)
rdctl set --memory=8 --cpus=4
```

## Ingress Controllers

### Why Disable Traefik?

Rancher Desktop includes Traefik as the default ingress controller. We disable it by default because:
- It can conflict with other ingress controllers (NGINX, Contour, etc.)
- Backstage applications often use NGINX Ingress
- It simplifies the networking setup for development
- You can always re-enable it if needed

### Installing NGINX Ingress Controller

If you need an ingress controller, we recommend NGINX:

```bash
# Add NGINX Ingress Helm repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install NGINX Ingress
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.service.ports.http=80 \
  --set controller.service.ports.https=443

# Verify installation
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

### Re-enabling Traefik

If you prefer to use Traefik:

```bash
# Enable Traefik
rdctl set --kubernetes.options.traefik=true

# Restart Rancher Desktop for changes to take effect
rdctl stop
rdctl start
```

## Common Use Cases

### Reset Kubernetes Cluster

```bash
# Reset cluster (removes all resources)
rdctl reset-kubernetes

# Wait for cluster to restart
kubectl wait --for=condition=Ready nodes --all --timeout=300s
```

### Switch Kubernetes Versions

```bash
# List available versions
rdctl list-settings

# Switch version
rdctl set --kubernetes-version=1.28.5
```

### Access Container Registry

Rancher Desktop includes a local registry accessible at:
- `localhost:5000` (when using dockerd)
- Use `nerdctl` for containerd runtime

## Troubleshooting

### Issue: Rancher Desktop won't start

```bash
# Check logs
rdctl shell cat /var/log/rancher-desktop.log

# Reset Rancher Desktop
rdctl factory-reset
```

### Issue: kubectl connection refused

```bash
# Ensure Rancher Desktop is running
rdctl start

# Check kubectl context
kubectl config current-context
kubectl config use-context rancher-desktop
```

### Issue: Crossplane pods not starting

```bash
# Check pod status
kubectl get pods -n crossplane-system

# Check logs
kubectl logs -n crossplane-system -l app=crossplane

# Check events
kubectl get events -n crossplane-system
```

### Issue: Provider not becoming healthy

```bash
# Check provider status
kubectl get providers

# Describe provider
kubectl describe provider provider-kubernetes

# Check provider pod logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-kubernetes
```

## Comparison with Kind

| Feature | Rancher Desktop | Kind |
|---------|----------------|------|
| Installation | Desktop app | CLI tool |
| Resource Usage | Higher | Lower |
| Built-in UI | Yes | No |
| Container Runtime | containerd/dockerd | containerd |
| Kubernetes Distro | K3s | Standard |
| Ingress | Traefik (disabled by default) | Requires setup |
| Reset Speed | Fast | Recreate cluster |
| Multi-cluster | No | Yes |

## Next Steps

1. Explore Crossplane compositions in `examples/crossplane-examples/`
2. Install additional Crossplane providers
3. Set up GitOps with Flux or ArgoCD
4. Configure monitoring with Prometheus
5. Integrate with your Backstage plugins

## Additional Resources

- [Rancher Desktop Documentation](https://docs.rancherdesktop.io/)
- [Crossplane Documentation](https://docs.crossplane.io/)
- [Backstage Kubernetes Plugin](https://backstage.io/docs/features/kubernetes/)
- [K3s Documentation](https://docs.k3s.io/)