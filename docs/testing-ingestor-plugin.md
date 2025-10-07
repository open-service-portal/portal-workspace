# Testing Plan: Ingestor Plugin & Annotation Changes

**Date**: 2025-10-07
**Cluster**: Rancher Desktop (rancher-desktop context)
**Branch**: `feat/xrd-transform` (ingestor), individual `main` branches (XRDs)

## Overview

Test the updated ingestor plugin with new annotation namespaces in local Rancher Desktop cluster.

**Changes to Test**:
1. ✅ New annotation namespace strategy (`backstage.io/*`, `openportal.dev/*`)
2. ✅ Updated XRD transform CLI tool
3. ✅ Updated entity provider with new kubernetes annotations
4. ✅ Cluster-scoped template support
5. ✅ API entity lifecycle fix

## Current Cluster State

```bash
$ kubectl config current-context
rancher-desktop

$ kubectl get xrds
NAME                                  ESTABLISHED   OFFERED   AGE
cloudflarednsrecords.openportal.dev   True                    33d
dnsrecords.openportal.dev             True                    32d
managednamespaces.openportal.dev      True                    33d
whoamiapps.openportal.dev             True                    33d
whoamiservices.openportal.dev         True                    33d
```

**Issue**: XRDs in cluster use OLD annotation namespaces (deployed 33 days ago)

## Testing Phases

### Phase 1: Update XRDs in Cluster ⚙️

Deploy updated XRDs with new annotation namespaces to the cluster.

#### 1.1 Backup Current XRDs (Optional)

```bash
cd /Users/felix/work/open-service-portal/portal-workspace

# Backup existing XRDs
mkdir -p /tmp/xrd-backup
kubectl get xrd whoamiapps.openportal.dev -o yaml > /tmp/xrd-backup/whoamiapps.yaml
kubectl get xrd managednamespaces.openportal.dev -o yaml > /tmp/xrd-backup/managednamespaces.yaml
kubectl get xrd cloudflarednsrecords.openportal.dev -o yaml > /tmp/xrd-backup/cloudflarednsrecords.yaml
kubectl get xrd dnsrecords.openportal.dev -o yaml > /tmp/xrd-backup/dnsrecords.yaml
kubectl get xrd whoamiservices.openportal.dev -o yaml > /tmp/xrd-backup/whoamiservices.yaml
```

#### 1.2 Apply Updated XRDs

```bash
# Apply updated XRDs with new annotations
kubectl apply -f template-namespace/configuration/xrd.yaml
kubectl apply -f template-whoami/configuration/xrd.yaml
kubectl apply -f template-cloudflare-dnsrecord/configuration/xrd.yaml
kubectl apply -f template-dns-record/configuration/xrd.yaml
kubectl apply -f template-whoami-service/configuration/xrd.yaml

# Verify XRDs are updated
kubectl get xrd whoamiapps.openportal.dev -o yaml | grep -A 10 "annotations:"
```

**Expected**: Should show new annotation namespaces:
- `backstage.io/title`
- `backstage.io/owner`
- `backstage.io/lifecycle`
- `openportal.dev/tags`
- `openportal.dev/version`

---

### Phase 2: Test XRD Transform CLI ⚡

Test the standalone CLI tool with updated XRDs.

#### 2.1 Test Namespace Template (Cluster-Scoped)

```bash
cd /Users/felix/work/open-service-portal/portal-workspace

# Generate templates from XRD
./scripts/xrd-transform.sh template-namespace -o /tmp/test-namespace

# Verify output
ls -la /tmp/test-namespace/
cat /tmp/test-namespace/managednamespaces-openportal-dev-default-template.yaml
cat /tmp/test-namespace/managednamespaces-openportal-dev-default-api.yaml
```

**Expected Results**:
- ✅ Template file created: `managednamespaces-openportal-dev-default-template.yaml`
- ✅ API file created: `managednamespaces-openportal-dev-default-api.yaml`
- ✅ NO `namespace` parameter in template (cluster-scoped)
- ✅ API entity has `lifecycle: experimental` (from `backstage.io/lifecycle`)
- ✅ API entity has `owner: platform-team` (from `backstage.io/owner`)

#### 2.2 Test WhoAmI Template (Namespaced)

```bash
./scripts/xrd-transform.sh template-whoami -o /tmp/test-whoami

# Check output
cat /tmp/test-whoami/whoamiapps-openportal-dev-default-template.yaml | head -40
cat /tmp/test-whoami/whoamiapps-openportal-dev-default-api.yaml | grep -A 5 "spec:"
```

**Expected Results**:
- ✅ Template has `namespace` parameter (namespaced resource)
- ✅ API entity has `lifecycle: production` (from `backstage.io/lifecycle`)
- ✅ Tags include "demo" and "application" (from `openportal.dev/tags`)

#### 2.3 Test All Templates

```bash
# Generate all templates
for template in template-namespace template-whoami template-cloudflare-dnsrecord template-dns-record template-whoami-service; do
  echo "Testing $template..."
  ./scripts/xrd-transform.sh $template -o /tmp/test-all/$template
done

# Verify all outputs
ls -R /tmp/test-all/
```

---

### Phase 3: Build & Start Backstage 🚀

Build the ingestor plugin and start Backstage with the updated configuration.

#### 3.1 Install Dependencies (if needed)

```bash
cd /Users/felix/work/open-service-portal/portal-workspace/app-portal

# Install dependencies
yarn install
```

#### 3.2 Build the Ingestor Plugin

```bash
cd plugins/ingestor

# Build the plugin
yarn build

# Verify build succeeded
ls -la dist/
```

#### 3.3 Configure Backstage for Rancher Desktop

Ensure you have the cluster-specific configuration:

```bash
cd /Users/felix/work/open-service-portal/portal-workspace

# Run cluster config script to set up Backstage config
./scripts/cluster-config.sh
```

This should create/update `app-portal/app-config.rancher-desktop.local.yaml`.

#### 3.4 Start Backstage

```bash
cd /Users/felix/work/open-service-portal/portal-workspace/app-portal

# Start Backstage (auto-detects rancher-desktop context)
yarn start
```

**Expected**:
- Backend starts on http://localhost:7007
- Frontend starts on http://localhost:3000
- Logs show ingestor connecting to cluster

---

### Phase 4: Test Entity Provider (Runtime Ingestion) 🔄

Verify the entity provider discovers XRDs from the cluster.

#### 4.1 Check Backend Logs

In the terminal running `yarn start`, look for:

```
[ingestor] Discovering resources from cluster: rancher-desktop
[ingestor] Found 5 XRDs
[ingestor] Processing XRD: whoamiapps.openportal.dev
[ingestor] Processing XRD: managednamespaces.openportal.dev
...
```

#### 4.2 Wait for Initial Sync

The entity provider runs on a schedule (default: every 30 minutes). For immediate testing:

**Option A**: Wait for first sync (check logs)

**Option B**: Restart Backstage to trigger immediate discovery:
```bash
# In the terminal running yarn start
Ctrl+C
yarn start
```

#### 4.3 Check Catalog API

```bash
# Get API token from config
TOKEN=$(grep -A2 "type: static" app-config.rancher-desktop.local.yaml | grep "token:" | awk '{print $2}')

# Query catalog entities
curl -H "Authorization: Bearer $TOKEN" http://localhost:7007/api/catalog/entities | jq '.[] | select(.kind == "API" or .kind == "Template") | {kind, name: .metadata.name, annotations: .metadata.annotations}'
```

**Expected**: Should show entities with new annotation namespaces:
- `backstage.io/managed-by: xrd-transform`
- `crossplane.io/xrd-name: whoamiapps.openportal.dev`
- `openportal.dev/kubernetes-kind: CompositeResourceDefinition`
- `openportal.dev/kubernetes-name: whoamiapps.openportal.dev`

---

### Phase 5: Verify Backstage UI 🖥️

Test the generated entities in the Backstage user interface.

#### 5.1 Check Catalog Home

1. Open http://localhost:3000/catalog
2. Look for new Templates and APIs

**Expected Entities**:
- Template: `whoamiapps-openportal-dev`
- Template: `managednamespaces-openportal-dev`
- Template: `cloudflarednsrecords-openportal-dev`
- Template: `dnsrecords-openportal-dev`
- Template: `whoamiservices-openportal-dev`
- API: `whoamiapps-openportal-dev-api`
- API: `managednamespaces-openportal-dev-api`
- (etc.)

#### 5.2 Inspect Template Entity

1. Click on `whoamiapps-openportal-dev` template
2. Check the **About** tab:
   - Title: "Who Am I App"
   - Description: "Simple demo application..."
   - Owner: platform-team
   - System: demo-applications
   - Lifecycle: production
   - Tags: demo, application

3. Check **Relations** tab (if available)

#### 5.3 Inspect API Entity

1. Click on `whoamiapps-openportal-dev-api`
2. Check the **About** tab:
   - Lifecycle: **production** (not v1alpha1!)
   - Owner: platform-team
   - Type: openapi

3. Check **Definition** tab:
   - Should show OpenAPI spec with proper schemas
   - Should include `minLength`, `maxLength` constraints

---

### Phase 6: Test Template Creation Workflow 🎨

Create a new resource using the generated template.

#### 6.1 Access Template

1. Go to http://localhost:3000/create
2. Find "Who Am I App" template
3. Click **Choose**

#### 6.2 Fill Template Form

Fill in the form with test data:

**Resource Configuration**:
- Name: `test-whoami`
- Namespace: `demo` (or create new)
- Replicas: `1`
- Image: (use default `traefik/whoami:v1.10.1`)

#### 6.3 Review and Create

1. Click **Review**
2. Check the generated YAML preview
3. Click **Create**

#### 6.4 Verify Resource Created

```bash
# Check if XR was created
kubectl get whoamiapp test-whoami -n demo

# Check if it's ready
kubectl get whoamiapp test-whoami -n demo -o yaml | grep -A 5 "status:"

# Check composed resources
kubectl get deployments -n demo | grep test-whoami
kubectl get services -n demo | grep test-whoami
```

---

### Phase 7: Test Cluster-Scoped Template 🌐

Test the namespace template with cluster-scoped configuration.

#### 7.1 Access ManagedNamespace Template

1. Go to http://localhost:3000/create
2. Find "ManagedNamespace Template"
3. Click **Choose**

#### 7.2 Verify NO Namespace Field

**Expected**: The form should have:
- ✅ Name field
- ❌ NO Namespace field (cluster-scoped!)

#### 7.3 Create Test Namespace

Fill in:
- Name: `test-managed-ns`

Click **Create**.

#### 7.4 Verify Namespace Created

```bash
# Check if namespace was created
kubectl get namespace test-managed-ns

# Check if ManagedNamespace XR exists
kubectl get managednamespace test-managed-ns

# Clean up
kubectl delete managednamespace test-managed-ns
kubectl delete namespace test-managed-ns
```

---

### Phase 8: Verify Annotation Namespaces 🏷️

Verify all entities use the correct annotation namespaces.

#### 8.1 Check Template Annotations

```bash
TOKEN=$(grep -A2 "type: static" app-config.rancher-desktop.local.yaml | grep "token:" | awk '{print $2}')

# Get template entity
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:7007/api/catalog/entities/by-name/template/default/whoamiapps-openportal-dev" | \
  jq '.metadata.annotations'
```

**Expected Annotations**:
```json
{
  "backstage.io/managed-by": "xrd-transform",
  "crossplane.io/xrd-name": "whoamiapps.openportal.dev",
  "crossplane.io/xrd-group": "openportal.dev"
}
```

**NOT Expected** (should be removed):
- ❌ `terasky.backstage.io/*` (any)
- ❌ `openportal.dev/title` (use `backstage.io/title`)

#### 8.2 Check API Annotations

```bash
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:7007/api/catalog/entities/by-name/api/default/whoamiapps-openportal-dev-api" | \
  jq '{lifecycle: .spec.lifecycle, owner: .spec.owner, annotations: .metadata.annotations}'
```

**Expected**:
- `lifecycle`: "production" (from XRD `backstage.io/lifecycle`)
- `owner`: "platform-team" (from XRD `backstage.io/owner`)
- Annotations include `backstage.io/managed-by`

---

## Success Criteria ✅

### CLI Transform Tool
- [ ] Generates templates from XRDs
- [ ] Cluster-scoped templates omit namespace parameter
- [ ] API entities use `backstage.io/lifecycle` correctly
- [ ] Filenames follow pattern: `{name}-{template}-{kind}.yaml`

### Entity Provider
- [ ] Discovers XRDs from cluster
- [ ] Creates Template entities
- [ ] Creates API entities
- [ ] Uses `openportal.dev/kubernetes-*` annotations

### Generated Entities
- [ ] Templates appear in Backstage catalog
- [ ] APIs appear in Backstage catalog
- [ ] Correct lifecycle stages displayed
- [ ] Correct owner/system metadata
- [ ] Tags parsed from `openportal.dev/tags`

### Template Workflow
- [ ] Can create resources from templates
- [ ] XRs successfully deployed to cluster
- [ ] Composed resources created
- [ ] Cluster-scoped templates work without namespace

### Annotation Namespaces
- [ ] No `terasky.backstage.io/*` annotations in generated entities
- [ ] `backstage.io/*` used for standard metadata
- [ ] `openportal.dev/*` used for custom features
- [ ] `crossplane.io/*` used for Crossplane references

---

## Troubleshooting 🔧

### XRDs Not Updating

If XRDs don't reflect new annotations:

```bash
# Force delete and reapply
kubectl delete xrd whoamiapps.openportal.dev
kubectl apply -f template-whoami/configuration/xrd.yaml

# Wait for re-establishment
kubectl get xrd whoamiapps.openportal.dev -w
```

### Entities Not Appearing in Catalog

Check backend logs for errors:

```bash
# In Backstage terminal, look for:
[ingestor] Error processing XRD: ...
```

Restart Backstage to trigger immediate sync:

```bash
Ctrl+C
yarn start
```

### API Lifecycle Shows Wrong Value

If API shows `lifecycle: v1alpha1` instead of `production`:

1. Check XRD has `backstage.io/lifecycle` annotation
2. Restart Backstage to re-ingest
3. Check backend logs for transformation errors

### Template Missing Namespace Field

For namespaced resources, verify:
- XRD does NOT have `openportal.dev/parameters-template: cluster-scoped`
- XRD `scope: Namespaced` in spec

For cluster-scoped resources, verify:
- XRD has `openportal.dev/parameters-template: cluster-scoped`
- XRD `scope: Cluster` in spec

---

## Cleanup 🧹

After testing, clean up test resources:

```bash
# Delete test XRs
kubectl delete whoamiapp test-whoami -n demo
kubectl delete managednamespace test-managed-ns

# Delete test namespaces (if created)
kubectl delete namespace test-managed-ns
```

---

## Next Steps 📋

After successful testing:

1. **Merge feature branch**: `feat/xrd-transform` → `main` in ingestor
2. **Update other templates**: Apply annotation changes to remaining templates
3. **Update documentation**: Add examples to docs/
4. **Deploy to production cluster**: Apply XRD changes to production
5. **Monitor**: Watch for any issues in production Backstage

---

**Last Updated**: 2025-10-07
**Tested By**: [Your Name]
**Status**: Ready for Testing
