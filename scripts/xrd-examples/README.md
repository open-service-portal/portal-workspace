# Crossplane v2 XRD Examples

Example Composite Resource Definitions for testing the TeraSky Kubernetes Ingestor's automatic template generation.

## Files

### [mongodb-xrd-v2.yaml](mongodb-xrd-v2.yaml)
MongoDB database XRD with configurable storage size and version.

### [cluster-xrd-v2.yaml](cluster-xrd-v2.yaml)
Kubernetes cluster XRD with node count and size parameters.

### [firewall-xrd-v2.yaml](firewall-xrd-v2.yaml)
Firewall rules XRD with source/destination IP and port configuration.

## Key Features

All XRDs include:
- Crossplane v2 API (`apiextensions.crossplane.io/v2`)
- TeraSky label: `terasky.backstage.io/generate-form: "true"`
- Complete OpenAPI schemas for form generation
- No `claimNames` section (removed in v2)

## Usage

```bash
# Apply all examples
kubectl apply -f mongodb-xrd-v2.yaml
kubectl apply -f cluster-xrd-v2.yaml
kubectl apply -f firewall-xrd-v2.yaml

# Verify XRDs
kubectl get xrds

# Check labels
kubectl get xrds -o json | jq '.items[].metadata.labels'
```

## Template Generation

After applying, the TeraSky Ingestor will:
1. Discover XRDs with the label (within 10 minutes)
2. Generate templates named `{xrd-name}-{version}`
3. Register them in Backstage catalog

Example: `xmongodbs.platform.example.com-v1alpha1`

## Documentation

See [TeraSky Kubernetes Ingestor docs](https://github.com/open-service-portal/app-portal/blob/main/docs/terasky-kubernetes-ingestor.md) for complete setup instructions.