# DNS Management with External-DNS

This guide explains how DNS management works in the Open Service Portal platform using External-DNS.

## Overview

We use [External-DNS](https://github.com/kubernetes-sigs/external-dns) to manage DNS records across different providers. This approach provides:

- **Namespace Isolation**: DNS records can be created in any namespace
- **Provider Flexibility**: Support for multiple DNS providers (Cloudflare, Route53, Azure DNS, etc.)
- **GitOps Compatible**: DNS records defined as Kubernetes resources
- **Automatic Lifecycle Management**: Records are created/updated/deleted automatically

## Architecture

```
┌─────────────────────────┐
│  CloudflareDNSRecord    │  (XR in user namespace)
│  namespace: my-app      │
└───────────┬─────────────┘
            │ Creates via Composition
            ▼
┌─────────────────────────┐
│    DNSEndpoint CRD      │  (in same namespace)
│  namespace: my-app      │
└───────────┬─────────────┘
            │ Watched by
            ▼
┌─────────────────────────┐
│    External-DNS         │  (controller in external-dns namespace)
│  namespace: external-dns│
└───────────┬─────────────┘
            │ Creates
            ▼
┌─────────────────────────┐
│   Cloudflare DNS API    │  (actual DNS record)
└─────────────────────────┘
```

## Installation

External-DNS is installed automatically by the `cluster-setup.sh` script. It includes:

1. **Custom CRD**: `dnsendpoints.externaldns.openportal.dev`
2. **Controller Deployment**: External-DNS controller in `external-dns` namespace
3. **RBAC**: Permissions to watch DNSEndpoint resources across all namespaces

## Configuration

### Environment Files

Create an environment file for your cluster context:

```bash
# For local development (e.g., rancher-desktop)
cp .env.rancher-desktop.example .env.rancher-desktop
```

Example `.env.rancher-desktop`:
```bash
# Base domain for applications (used by templates)
BASE_DOMAIN=localhost

# Optional: Real DNS via Cloudflare
CLOUDFLARE_API_TOKEN=your-api-token-here
CLOUDFLARE_ZONE_NAME=openportal.dev
```

### Apply Configuration

```bash
# Auto-detect cluster and apply configuration
./scripts/cluster-config.sh

# This will:
# - Create/update Cloudflare credentials if provided
# - Update EnvironmentConfigs with BASE_DOMAIN
# - Configure Flux to watch catalog-orders
```

## Creating DNS Records

### Method 1: Using CloudflareDNSRecord XR (Recommended)

The CloudflareDNSRecord template provides a high-level abstraction:

```yaml
apiVersion: openportal.dev/v1alpha1
kind: CloudflareDNSRecord
metadata:
  name: my-app-dns
  namespace: my-namespace
spec:
  name: my-app           # Subdomain (becomes my-app.openportal.dev)
  type: A                # Record type (A, AAAA, CNAME, TXT, etc.)
  value: "192.168.1.100" # IP address or target
  ttl: 300               # TTL in seconds (optional, default: 300)
```

### Method 2: Direct DNSEndpoint (Advanced)

For more control, create DNSEndpoint resources directly:

```yaml
apiVersion: externaldns.openportal.dev/v1alpha1
kind: DNSEndpoint
metadata:
  name: my-app-endpoint
  namespace: my-namespace
spec:
  endpoints:
  - dnsName: my-app.openportal.dev
    recordType: A
    targets: 
    - "192.168.1.100"
    recordTTL: 300
```

### Method 3: Via Ingress (Automatic)

External-DNS can automatically create records from Ingress resources:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  namespace: my-namespace
  annotations:
    # External-DNS will create DNS record automatically
    external-dns.alpha.kubernetes.io/hostname: my-app.openportal.dev
spec:
  rules:
  - host: my-app.openportal.dev
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app
            port:
              number: 80
```

## Provider Configuration

### Cloudflare

For production use with Cloudflare:

1. **Create API Token** in Cloudflare dashboard with:
   - Zone:DNS:Edit permissions
   - Zone:Zone:Read permissions
   - Scoped to your DNS zone

2. **Configure credentials** in your environment file:
   ```bash
   CLOUDFLARE_API_TOKEN=your-api-token
   CLOUDFLARE_ZONE_NAME=openportal.dev
   ```

3. **Apply configuration**:
   ```bash
   ./scripts/cluster-config.sh
   ```

### Local Development (Mock Provider)

For local development without real DNS:

```bash
# .env.rancher-desktop
BASE_DOMAIN=localhost
# No Cloudflare credentials needed
```

External-DNS will run in "dry-run" mode, logging what it would do without making actual DNS changes.

## Ownership and TXT Records

External-DNS uses TXT records to track ownership of DNS records. For each DNS record created, it also creates:

1. **Ownership TXT record**: `_owner.my-app.openportal.dev`
   - Contains the External-DNS instance identifier
   - Prevents conflicts between multiple External-DNS instances

2. **Heritage TXT record**: `heritage=external-dns`
   - Identifies records managed by External-DNS
   - Prevents accidental deletion of manually created records

## Namespace Isolation

Unlike provider-cloudflare, External-DNS supports full namespace isolation:

- DNSEndpoint resources can be created in any namespace
- External-DNS controller watches all namespaces
- RBAC can be configured to limit which namespaces users can create records in

## Monitoring and Debugging

### Check External-DNS Status

```bash
# View External-DNS pods
kubectl get pods -n external-dns

# Check logs
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns

# View events
kubectl get events -n external-dns --sort-by='.lastTimestamp'
```

### List DNS Records

```bash
# List all DNSEndpoint resources
kubectl get dnsendpoints -A

# View specific DNSEndpoint
kubectl describe dnsendpoint my-app-endpoint -n my-namespace

# Check CloudflareDNSRecord XRs
kubectl get cloudflarednsrecord -A
```

### Debug DNS Resolution

```bash
# Test DNS resolution
nslookup my-app.openportal.dev

# Check Cloudflare DNS records (if using Cloudflare)
curl -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" | jq
```

## Template Management

### Check Template Status

```bash
# View all templates and their release status
./scripts/template-status.sh

# Reload templates after updates
./scripts/template-reload.sh
```

### Update CloudflareDNSRecord Template

The template is managed via GitOps:

1. **Update template** in `template-cloudflare-dnsrecord` repository
2. **Create release**: Tag with semantic version (e.g., v2.0.0)
3. **Update catalog**: Update version in `catalog/templates/cloudflare-dnsrecord.yaml`
4. **Flux syncs**: Automatically applies updates to cluster

## Migration from provider-cloudflare

If migrating from provider-cloudflare to External-DNS:

1. **List existing records**:
   ```bash
   kubectl get record.dns.cloudflare.upbound.io -A
   ```

2. **Create equivalent DNSEndpoints**:
   ```bash
   # For each existing record, create a DNSEndpoint
   kubectl apply -f dns-endpoints.yaml
   ```

3. **Verify records are created**:
   ```bash
   # Check External-DNS logs
   kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns
   ```

4. **Delete old provider resources**:
   ```bash
   kubectl delete record.dns.cloudflare.upbound.io --all -A
   ```

## Troubleshooting

### External-DNS Not Creating Records

1. **Check credentials**:
   ```bash
   kubectl get secret cloudflare-api-token -n external-dns -o yaml
   ```

2. **Check permissions**:
   - Verify API token has correct Cloudflare permissions
   - Check RBAC for DNSEndpoint resources

3. **Check filters**:
   ```bash
   # External-DNS only processes records matching domain filter
   kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns | grep domain-filter
   ```

### Records Not Resolving

1. **Check record creation**:
   ```bash
   # In Cloudflare dashboard or via API
   curl -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
     -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}"
   ```

2. **Check DNS propagation**:
   ```bash
   # May take time to propagate
   dig my-app.openportal.dev @1.1.1.1
   ```

3. **Check TXT ownership records**:
   ```bash
   dig TXT _owner.my-app.openportal.dev
   ```

### Conflicts with Existing Records

If External-DNS reports conflicts:

1. **Check ownership**:
   - External-DNS only manages records it created
   - Check for TXT ownership records

2. **Force ownership** (careful!):
   ```yaml
   # In DNSEndpoint, add annotation
   metadata:
     annotations:
       external-dns.alpha.kubernetes.io/force: "true"
   ```

## Best Practices

1. **Use XRs for abstraction**: CloudflareDNSRecord XR provides better UX than raw DNSEndpoints
2. **Set appropriate TTLs**: Lower TTLs (300s) for development, higher (3600s) for production
3. **Monitor External-DNS logs**: Regular monitoring helps catch issues early
4. **Use namespace isolation**: Create DNS records in appropriate namespaces for better RBAC
5. **Document DNS dependencies**: Keep track of which services depend on which DNS records

## Additional Resources

- [External-DNS Documentation](https://github.com/kubernetes-sigs/external-dns)
- [External-DNS Cloudflare Tutorial](https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/cloudflare.md)
- [DNSEndpoint CRD Specification](https://github.com/kubernetes-sigs/external-dns/blob/master/docs/contributing/crd-source.md)
- [CloudflareDNSRecord Template](https://github.com/open-service-portal/template-cloudflare-dnsrecord)