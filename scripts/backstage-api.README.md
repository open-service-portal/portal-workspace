# backstage-api.sh

Generic wrapper script for querying the local Backstage API with automatic authentication.

## Features

- Auto-detects kubectl context
- Extracts API token from context-specific config file
- Supports optional jq filtering
- Works from anywhere in the workspace

## Usage

```bash
./scripts/backstage-api.sh '<endpoint>' [jq-filter]
```

**⚠️ IMPORTANT:** Always quote the endpoint when using query parameters (`?filter=...`)

```bash
# ✅ Correct (with quotes)
./scripts/backstage-api.sh '/api/catalog/entities?filter=kind=Template'

# ❌ Wrong (without quotes - shell will expand the ?)
./scripts/backstage-api.sh /api/catalog/entities?filter=kind=Template
```

## Examples

### Basic Usage

```bash
# Get all entities
./scripts/backstage-api.sh /api/catalog/entities

# Get all templates (note the quotes!)
./scripts/backstage-api.sh '/api/catalog/entities?filter=kind=Template'

# Get specific entity
./scripts/backstage-api.sh /api/catalog/entities/by-name/template/default/cs-api-realm-template
```

### With jq Filters

```bash
# Get template names only
./scripts/backstage-api.sh '/api/catalog/entities?filter=kind=Template' '.[] | .metadata.name'

# Get templates with tags
./scripts/backstage-api.sh '/api/catalog/entities?filter=kind=Template' '.[] | {name: .metadata.name, tags: .metadata.tags}'

# Check source tags
./scripts/backstage-api.sh '/api/catalog/entities?filter=kind=Template' '.[] | {name: .metadata.name, source_tags: (.metadata.tags | map(select(startswith("source:"))))}'

# Group by source tags
./scripts/backstage-api.sh '/api/catalog/entities?filter=kind=Template' '.[] | {name: .metadata.name, source_tags: (.metadata.tags | map(select(startswith("source:"))))}' | jq -s 'group_by(.source_tags | sort | join(",")) | map({source_tags: .[0].source_tags, count: length, examples: (map(.name) | .[0:5])})'
```

### Filter Specific Templates

```bash
# Get local file template
./scripts/backstage-api.sh '/api/catalog/entities?filter=kind=Template' '.[] | select(.metadata.name == "cs-api-realm-template")'

# Get GitHub templates
./scripts/backstage-api.sh '/api/catalog/entities?filter=kind=Template' '.[] | select(.metadata.tags | contains(["source:github-discovered"]))'

# Get Crossplane templates
./scripts/backstage-api.sh '/api/catalog/entities?filter=kind=Template' '.[] | select(.metadata.tags | contains(["crossplane"]))'
```

### Other Endpoints

```bash
# Get components
./scripts/backstage-api.sh '/api/catalog/entities?filter=kind=Component'

# Get APIs
./scripts/backstage-api.sh '/api/catalog/entities?filter=kind=API'

# Search
./scripts/backstage-api.sh '/api/search/query?term=crossplane'
```

## How it Works

1. Detects current kubectl context (e.g., `osp-openportal`)
2. Looks for `app-config.osp-openportal.local.yaml` in app-portal/
3. Extracts the static API token from the config
4. Makes authenticated request to `http://localhost:7007`
5. Optionally pipes through jq for filtering

## Requirements

- Backstage running on `http://localhost:7007`
- Context-specific config file with static API token
- `kubectl` configured with current context
- `jq` installed for JSON processing

## Claude Code Integration

To allow Claude Code to use this script without manual confirmation, add it to your allowed commands in `.claude/settings.local.json`:

```json
{
  "allowedCommands": [
    "Bash(./scripts/backstage-api.sh:*)"
  ]
}
```

**Benefit:** More secure than allowing `curl` globally - restricts Claude to only this specific script.

## Troubleshooting

**Config file not found:**
```bash
# Check current context
kubectl config current-context

# Verify config file exists
ls app-portal/app-config.*.local.yaml
```

**No token found:**
```bash
# Check token in config
grep -A2 "type: static" app-portal/app-config.*.local.yaml
```

**Connection refused:**
```bash
# Verify Backstage is running
curl http://localhost:7007/api/catalog/entities | head
```
