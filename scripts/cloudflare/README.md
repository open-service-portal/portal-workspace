# Cloudflare Debug Suite

This directory contains debugging and testing tools for the Cloudflare DNS provider integration with Crossplane.

## Overview

These scripts help diagnose and resolve issues with the cdloh/provider-cloudflare, particularly around the zoneIdRef pattern for DNS record management.

## Prerequisites

1. **Environment Configuration**: Set up `.env.openportal` with:
   ```bash
   CLOUDFLARE_USER_API_TOKEN=your-api-token
   CLOUDFLARE_ZONE_ID=your-zone-id
   CLOUDFLARE_ACCOUNT_ID=your-account-id
   DNS_ZONE=your-domain.com
   ```

2. **Cluster Setup**: Ensure the Cloudflare provider is installed:
   ```bash
   # Install provider (includes ProviderConfig)
   ./scripts/setup-cluster.sh
   
   # Configure credentials and import Zone
   ./scripts/config-openportal.sh
   ```

## Scripts

### setup.sh
Sets up test resources to validate the Cloudflare provider:
- Creates ProviderConfig with credentials
- Creates test DNS Records using zoneIdRef pattern
- Creates test XR if composition exists

```bash
./scripts/cloudflare/setup.sh
```

### validate.sh
Comprehensive validation of the Cloudflare setup:
- Checks provider health
- Validates credentials
- Tests API connectivity
- Verifies DNS records in both Kubernetes and Cloudflare
- Identifies common issues

```bash
./scripts/cloudflare/validate.sh
```

### test-xr.sh
Tests the CloudflareDNSRecord XR with zoneIdRef pattern:
- Creates test records using Zone references
- Validates zone resource dependencies
- Tests the composition pipeline

```bash
# Create test resources
./scripts/cloudflare/test-xr.sh create

# Check status
./scripts/cloudflare/test-xr.sh status

# Clean up
./scripts/cloudflare/test-xr.sh remove
```

### remove.sh
Removes all Cloudflare test resources:
- Deletes test DNS records
- Removes XRs and compositions
- Cleans up provider configuration
- Checks for orphaned resources in Cloudflare API

```bash
./scripts/cloudflare/remove.sh
```

### list-zones.sh
Helper script to discover available Zone resources:
- Lists all Zone resources in the cluster
- Shows zone status and external IDs
- Used by the template to provide zone selection

```bash
./scripts/cloudflare/list-zones.sh
```

## Workflow

### Testing Loop
When debugging Cloudflare issues, use this workflow:

```bash
# 1. Set up test resources
./scripts/cloudflare/setup.sh

# 2. Validate the setup
./scripts/cloudflare/validate.sh

# 3. If issues found, remove and retry
./scripts/cloudflare/remove.sh

# Repeat until working
```

### Best Practices

1. **Zone References**: Always use `zoneIdRef` pointing to a Zone resource, never direct `zoneId` values.

2. **External Name**: Don't set `crossplane.io/external-name` on Records - let Cloudflare generate the ID.

3. **Provider Refresh**: The cdloh provider works correctly when using the zoneIdRef pattern.

## Architecture

The scripts follow the zoneIdRef pattern:

1. **Zone Resource**: Created by `config-openportal.sh`, represents a Cloudflare DNS zone
2. **Records**: Reference the Zone resource by name using `zoneIdRef`
3. **No Direct IDs**: Never use direct Cloudflare Zone IDs in Records

Example:
```yaml
apiVersion: dns.cloudflare.upbound.io/v1alpha1
kind: Record
spec:
  forProvider:
    zoneIdRef:
      name: openportal-zone  # References the Zone resource
    name: myapp
    type: A
    value: 192.168.1.100
```

## Debugging Tips

1. **Check Provider Logs**:
   ```bash
   kubectl logs -n crossplane-system deployment/provider-cloudflare-* --tail=100
   ```

2. **Verify Zone Resource**:
   ```bash
   kubectl get zones.zone.cloudflare.upbound.io -o wide
   ```

3. **Test API Token**:
   ```bash
   curl -H "Authorization: Bearer $CLOUDFLARE_USER_API_TOKEN" \
        https://api.cloudflare.com/client/v4/user/tokens/verify
   ```

4. **List DNS Records via API**:
   ```bash
   curl -H "Authorization: Bearer $CLOUDFLARE_USER_API_TOKEN" \
        "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records"
   ```

## Integration with Templates

The Cloudflare DNS template (`template-cloudflare-dnsrecord`) uses these patterns:
- Accepts a `zone` parameter (defaults to "openportal-zone")
- Uses zoneIdRef to reference Zone resources
- Supports multiple zones through zone selection