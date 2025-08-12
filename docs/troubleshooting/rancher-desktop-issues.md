# Rancher Desktop Troubleshooting Guide

This guide covers common issues when using Rancher Desktop for local Kubernetes development with Backstage and Crossplane.

## Common Issues

### Rancher Desktop Won't Start

#### Symptoms
- Rancher Desktop UI doesn't open
- `rdctl` commands fail
- Error messages about VM or container runtime

#### Solutions

1. **Check System Requirements**
   ```bash
   # macOS: Ensure virtualization is enabled
   sysctl -a | grep -E "machdep.cpu.features|VMX"
   
   # Linux: Check virtualization support
   egrep -c '(vmx|svm)' /proc/cpuinfo
   ```

2. **Reset Rancher Desktop**
   ```bash
   # Factory reset (removes all data)
   rdctl factory-reset
   
   # Start fresh
   rdctl start
   ```

3. **Check Logs**
   ```bash
   # View logs
   rdctl shell cat /var/log/rancher-desktop.log
   
   # macOS log location
   ~/Library/Logs/rancher-desktop/
   ```

### kubectl Connection Issues

#### Symptoms
- `kubectl: command not found`
- `The connection to the server localhost:6443 was refused`
- Wrong context selected

#### Solutions

1. **Ensure Rancher Desktop is Running**
   ```bash
   rdctl start
   rdctl version
   ```

2. **Check kubectl Path**
   ```bash
   # Rancher Desktop should add kubectl to PATH
   which kubectl
   
   # If not found, add manually
   export PATH="$HOME/.rd/bin:$PATH"
   ```

3. **Verify Context**
   ```bash
   # Check current context
   kubectl config current-context
   
   # Switch to rancher-desktop
   kubectl config use-context rancher-desktop
   
   # Verify connection
   kubectl cluster-info
   ```

### Kubeconfig Issues

#### Symptoms
- Cannot find kubeconfig
- Authentication errors
- Context not found

#### Solutions

1. **Check Kubeconfig Location**
   ```bash
   # Default location
   ls -la ~/.kube/config
   
   # Check KUBECONFIG environment variable
   echo $KUBECONFIG
   ```

2. **Export Kubeconfig**
   ```bash
   # Export current config
   kubectl config view --raw > rancher-desktop.kubeconfig
   
   # Use exported config
   export KUBECONFIG=$(pwd)/rancher-desktop.kubeconfig
   ```

3. **Verify Kubeconfig Contents**
   ```bash
   # Check clusters
   kubectl config get-clusters
   
   # Check contexts
   kubectl config get-contexts
   
   # View full config (sanitized)
   kubectl config view
   ```

4. **Reset Kubeconfig**
   ```bash
   # Backup existing config
   cp ~/.kube/config ~/.kube/config.backup
   
   # Restart Rancher Desktop to regenerate
   rdctl stop
   rdctl start
   ```

### Crossplane Installation Failures

#### Symptoms
- Helm install hangs or fails
- Crossplane pods not starting
- CRDs not installed

#### Solutions

1. **Check Helm Repository**
   ```bash
   # Update helm repos
   helm repo update
   
   # List repos
   helm repo list
   ```

2. **Namespace Issues**
   ```bash
   # Ensure namespace exists
   kubectl create namespace crossplane-system
   
   # Check for existing installation
   helm list -n crossplane-system
   ```

3. **Resource Constraints**
   ```bash
   # Check node resources
   kubectl describe nodes
   
   # Increase Rancher Desktop resources
   rdctl set --memory=8 --cpus=4
   ```

### Provider Not Becoming Healthy

#### Symptoms
- Provider stuck in "Installing" state
- Provider pod CrashLoopBackOff
- Timeout waiting for provider

#### Solutions

1. **Check Provider Logs**
   ```bash
   # Get provider pod
   kubectl get pods -n crossplane-system | grep provider
   
   # View logs
   kubectl logs -n crossplane-system <provider-pod-name>
   ```

2. **Network Issues**
   ```bash
   # Test registry access
   nerdctl pull xpkg.upbound.io/crossplane-contrib/provider-kubernetes:v0.14.0
   
   # Check DNS
   kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup xpkg.upbound.io
   ```

3. **RBAC Issues**
   ```bash
   # Check service account
   kubectl get sa -n crossplane-system
   
   # Verify cluster role bindings
   kubectl get clusterrolebindings | grep crossplane
   ```

### Docker Desktop and Rancher Desktop Conflicts

#### Symptoms
- Symlink warnings in Rancher Desktop UI
- Messages like "The file ~/.docker/cli-plugins/docker-buildx should be a symlink to ~/.rd/bin/docker-buildx"
- Both Docker Desktop and Rancher Desktop installed on the same machine

#### Solutions

**Option 1: Use Rancher Desktop Exclusively**
```bash
# Remove Docker Desktop symlinks
rm ~/.docker/cli-plugins/docker-buildx
rm ~/.docker/cli-plugins/docker-compose

# Create symlinks to Rancher Desktop
ln -s ~/.rd/bin/docker-buildx ~/.docker/cli-plugins/docker-buildx
ln -s ~/.rd/bin/docker-compose ~/.docker/cli-plugins/docker-compose

# Stop Docker Desktop
osascript -e 'quit app "Docker"'  # macOS
```

**Option 2: Keep Both Installed (Side-by-Side)**
- Keep Docker Desktop symlinks as-is (ignore Rancher warnings)
- Use Docker Desktop for Docker operations
- Use Rancher Desktop for Kubernetes (disable dockerd in Rancher settings)
- Access Rancher tools directly: `~/.rd/bin/docker-buildx`

**Option 3: Switch Between Them**
- Only run one at a time
- Docker Desktop manages symlinks when running
- Rancher Desktop can use its own binaries from `~/.rd/bin/`

### Container Runtime Issues

#### Symptoms
- Images not pulling
- Containers not starting
- Permission errors

#### Solutions

1. **Switch Container Engine**
   ```bash
   # Switch to dockerd
   rdctl set --container-engine=dockerd
   
   # Or switch to containerd
   rdctl set --container-engine=containerd
   ```

2. **Clear Image Cache**
   ```bash
   # For containerd
   rdctl shell nerdctl system prune -a
   
   # For dockerd
   rdctl shell docker system prune -a
   ```

### Performance Issues

#### Symptoms
- Slow pod startup
- High CPU/memory usage
- UI unresponsive

#### Solutions

1. **Adjust Resources**
   ```bash
   # Increase allocated resources
   rdctl set --memory=16 --cpus=6
   
   # Check current settings
   rdctl list-settings
   ```

2. **Disable Unnecessary Features**
   ```bash
   # Disable Traefik if not needed
   # (Configure in Rancher Desktop UI)
   ```

3. **Use Specific Kubernetes Version**
   ```bash
   # Use stable version instead of latest
   rdctl set --kubernetes-version=1.28.5
   ```

## Backstage-Specific Issues

### Service Account Token Issues

#### Symptoms
- Backstage can't connect to cluster
- Authentication errors in logs

#### Solutions

1. **Regenerate Token**
   ```bash
   # Delete old token
   kubectl delete serviceaccount backstage-k8s-sa -n default
   
   # Recreate
   kubectl create serviceaccount backstage-k8s-sa -n default
   kubectl create clusterrolebinding backstage-k8s-sa-binding \
     --clusterrole=cluster-admin \
     --serviceaccount=default:backstage-k8s-sa
   
   # Generate new token
   export K8S_SERVICE_ACCOUNT_TOKEN=$(kubectl create token backstage-k8s-sa -n default --duration=8760h)
   ```

2. **Verify Token**
   ```bash
   # Test token
   kubectl --token=$K8S_SERVICE_ACCOUNT_TOKEN get nodes
   ```

### Certificate Issues

#### Symptoms
- TLS verification errors
- Certificate expired warnings

#### Solutions

1. **Skip TLS Verify (Development Only)**
   ```yaml
   # In app-config.yaml
   kubernetes:
     clusterLocatorMethods:
       - type: 'config'
         clusters:
           - url: https://127.0.0.1:6443
             skipTLSVerify: true
   ```

2. **Get Cluster CA Certificate**
   ```bash
   # Extract CA cert
   kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d > ca.crt
   ```

## Diagnostic Commands

### Health Checks
```bash
# Rancher Desktop status
rdctl version
rdctl list-settings

# Kubernetes status
kubectl version
kubectl get nodes
kubectl get pods --all-namespaces

# Crossplane status
kubectl get providers
kubectl get pods -n crossplane-system
helm list -n crossplane-system
```

### Log Collection
```bash
# Collect all relevant logs
mkdir rancher-debug
rdctl shell journalctl > rancher-debug/system.log
kubectl logs -n crossplane-system -l app=crossplane > rancher-debug/crossplane.log
kubectl get events --all-namespaces > rancher-debug/events.log
```

## Getting Help

1. **Rancher Desktop**
   - GitHub Issues: https://github.com/rancher-sandbox/rancher-desktop/issues
   - Documentation: https://docs.rancherdesktop.io/

2. **Crossplane**
   - Slack: https://crossplane.slack.com/
   - GitHub: https://github.com/crossplane/crossplane

3. **Backstage**
   - Discord: https://discord.gg/backstage
   - GitHub: https://github.com/backstage/backstage