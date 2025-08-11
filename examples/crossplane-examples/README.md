# Crossplane Examples

This directory contains example Crossplane resources to get you started with infrastructure as code using Crossplane.

## Files

- `provider-kubernetes.yaml` - Installs the Kubernetes provider for Crossplane
- `simple-app-xrd.yaml` - Defines a Composite Resource Definition (XRD) for applications
- `simple-app-composition.yaml` - Defines how to compose Kubernetes resources for an application
- `example-app-claim.yaml` - Example claim to create an application instance

## Usage

1. **Install the Kubernetes Provider**:
   ```bash
   kubectl apply -f provider-kubernetes.yaml
   
   # Wait for provider to be ready
   kubectl wait --for=condition=Healthy provider/provider-kubernetes --timeout=300s
   ```

2. **Create the XRD and Composition**:
   ```bash
   kubectl apply -f simple-app-xrd.yaml
   kubectl apply -f simple-app-composition.yaml
   
   # Verify they were created
   kubectl get xrd
   kubectl get composition
   ```

3. **Deploy an Application**:
   ```bash
   kubectl apply -f example-app-claim.yaml
   
   # Check the status
   kubectl get application
   kubectl describe application my-nginx-app
   ```

4. **Verify Resources Were Created**:
   ```bash
   # Check namespace
   kubectl get namespace my-app
   
   # Check deployment
   kubectl get deployment -n my-app
   
   # Check service
   kubectl get service -n my-app
   ```

5. **Access the Application** (if using NodePort):
   ```bash
   # Get the NodePort
   kubectl get service -n my-app -o jsonpath='{.items[0].spec.ports[0].nodePort}'
   
   # Access via localhost (Kind maps NodePorts 30000-30001)
   curl http://localhost:30000
   ```

## Customization

You can create your own applications by modifying the claim:

```yaml
apiVersion: example.io/v1alpha1
kind: Application
metadata:
  name: my-custom-app
spec:
  parameters:
    namespace: custom-namespace
    image: your-image:tag
    replicas: 3
    port: 8080
    serviceType: ClusterIP
```

## Cleanup

To remove all resources:

```bash
# Delete the application
kubectl delete -f example-app-claim.yaml

# Delete composition and XRD
kubectl delete -f simple-app-composition.yaml
kubectl delete -f simple-app-xrd.yaml

# Uninstall provider
kubectl delete -f provider-kubernetes.yaml
```