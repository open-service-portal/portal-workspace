# OIDC Cluster Authentication with Backstage

## Overview

The OIDC Authenticator enables Backstage users to authenticate with Kubernetes clusters using their Auth0/Rackspace OIDC credentials. This provides seamless single sign-on for cluster access directly from Backstage.

## Architecture

```
┌─────────────────┐         ┌──────────────────┐         ┌─────────────────┐
│   Backstage UI  │────────>│ OIDC Authenticator│────────>│  Auth0/OIDC    │
│  (localhost:3000)│         │   (localhost:8000)│         │    Provider    │
└─────────────────┘         └──────────────────┘         └─────────────────┘
        │                            │                              │
        │ 1. Click "Authenticate"    │ 2. Open popup                │
        │                            │                              │
        │                            │ 3. Redirect to OIDC         │
        │                            │────────────────────────────> │
        │                            │                              │
        │                            │ 4. User authenticates        │
        │                            │ <──────────────────────────  │
        │                            │                              │
        │                            │ 5. Exchange code for tokens  │
        │                            │ <──────────────────────────> │
        │                            │                              │
        │ 6. Send tokens to backend  │                              │
        │ <──────────────────────────│                              │
        │                                                            │
        │ 7. Tokens stored and available for K8s API calls          │
        └────────────────────────────────────────────────────────────┘
```

## Components

### 1. OIDC Authenticator Daemon

**Location:** `oidc-authenticator/`

A standalone Node.js daemon that runs on the user's laptop and handles the OAuth/OIDC flow using PKCE (Proof Key for Code Exchange).

**Features:**
- Daemon mode with `start`, `stop`, and `status` commands
- One-off authentication mode (runs once and exits)
- Built-in JWT token decoding with claims display
- Verbose mode for debugging
- Configuration via `config.json` or environment variables

**Similar to:** `kubectl oidc-login` - familiar pattern for Kubernetes users

### 2. Backstage Backend

**Location:** `app-portal/packages/backend/src/plugins/cluster-auth.ts`

Receives and manages cluster authentication tokens.

**Endpoints:**
- `POST /api/cluster-auth/tokens` - Receive tokens from daemon
- `GET /api/cluster-auth/status` - Check authentication status
- `GET /api/cluster-auth/token` - Retrieve tokens for K8s API calls

### 3. Backstage Frontend

**Location:** `app-portal/packages/app/src/components/ClusterAuthButton.tsx`

User interface component in Backstage Settings that triggers authentication.

**Features:**
- Health check for daemon availability
- Opens authentication popup
- Status indicators (loading, success, error)
- Clear instructions if daemon not running

## Setup

### Prerequisites

- Node.js 18+ installed
- Auth0/Rackspace OIDC provider configured
- OAuth application registered with Auth0

### 1. Configure OIDC Authenticator

Create `oidc-authenticator/config.json`:

```json
{
  "issuer": "https://login.spot.rackspace.com/",
  "clientId": "YOUR_CLIENT_ID",
  "organizationId": "org_xxxxx",
  "backendUrl": "http://localhost:7007",
  "callbackPort": 8000
}
```

### 2. Start the Daemon

```bash
cd oidc-authenticator

# Start daemon in background
node bin/cli.js start

# Or with verbose output
node bin/cli.js start --verbose

# Check status
node bin/cli.js status

# Stop daemon
node bin/cli.js stop
```

### 3. Start Backstage

```bash
cd app-portal
yarn install
yarn start
```

## Usage

### Authenticate with Cluster

1. Open Backstage: http://localhost:3000
2. Click profile icon → **Settings**
3. Look for **Cluster Authentication** section
4. Click **"Authenticate with Cluster"** button
5. Complete authentication in popup window
6. Tokens automatically sent to Backstage backend

### One-Off Authentication (CLI)

For testing or CLI tools:

```bash
# Run once and save tokens
node bin/cli.js --verbose --output /tmp/tokens.json

# Tokens will be saved to file and sent to backend
```

### Verbose Mode

See detailed authentication flow including JWT token claims:

```bash
node bin/cli.js --verbose
```

**Output includes:**
- Configuration details (issuer, client ID, scopes)
- PKCE challenge generation
- Authorization URL
- Token exchange details
- **Decoded JWT claims** (email, name, expiration, etc.)
- Access token type (JWT or JWE encrypted)

## Configuration Options

### Environment Variables

```bash
export OIDC_ISSUER_URL="https://login.spot.rackspace.com/"
export OIDC_CLIENT_ID="your_client_id"
export OIDC_ORGANIZATION_ID="org_xxxxx"
```

### Command Line Options

```
Options:
  --issuer <url>          OIDC issuer URL
  --client-id <id>        OAuth client ID
  --organization <id>     Organization ID (Auth0)
  --backend-url <url>     Backstage backend URL
  --scopes <scopes>       OAuth scopes (default: "openid profile email")
  --port <port>           Callback port (default: 8000)
  -v, --verbose           Show detailed output
```

## Authentication Flow

### PKCE Flow Details

1. **Code Challenge Generation**
   - Generate random `code_verifier` (high-entropy random string)
   - Create `code_challenge` = SHA256(code_verifier)

2. **Authorization Request**
   - Redirect user to OIDC provider with `code_challenge`
   - User authenticates with Auth0/Rackspace
   - OIDC provider redirects back with authorization `code`

3. **Token Exchange**
   - Exchange `code` + `code_verifier` for tokens
   - OIDC provider verifies: SHA256(code_verifier) == code_challenge
   - Returns access_token, id_token, refresh_token

4. **Token Transmission**
   - Daemon sends tokens to Backstage backend
   - Backend stores tokens (TODO: implement persistence)
   - Tokens available for Kubernetes API calls

### Security Features

- **PKCE**: No client secret needed, secure for public clients
- **Localhost only**: Daemon binds to 127.0.0.1
- **State validation**: Prevents CSRF attacks
- **No public URL required**: Works on private networks
- **Token validation**: JWT signature verification (TODO)

## Troubleshooting

### Daemon Not Running

**Symptom:** Backstage shows "Daemon is not running" message

**Solution:**
```bash
cd oidc-authenticator
node bin/cli.js start --verbose
```

### Port Already in Use

**Symptom:** Error: Port 8000 is already in use

**Solution:**
```bash
# Find and kill process
lsof -ti :8000 | xargs kill -9

# Or use different port
node bin/cli.js start --port 8080
```

### Authentication Timeout

**Symptom:** Popup closes before completing authentication

**Solution:**
- Check OIDC provider is accessible
- Verify client ID and issuer URL are correct
- Check browser console for errors

### Token Not Sent to Backend

**Symptom:** Authentication completes but tokens not received

**Solution:**
```bash
# Check backend URL in config.json
# Verify Backstage backend is running on specified port
curl http://localhost:7007/api/cluster-auth/status
```

## Comparison with Backstage User Auth

| Feature | Backstage User Auth | Cluster Auth (OIDC Authenticator) |
|---------|---------------------|-----------------------------------|
| **Purpose** | Login to Backstage UI | Access Kubernetes clusters |
| **Token Scope** | Backstage session | Kubernetes API |
| **Callback URL** | Backstage public URL | Localhost daemon |
| **Public URL Required** | Yes | No |
| **Similar To** | Standard OAuth | `kubectl oidc-login` |
| **Configuration** | `app-config/auth.yaml` | `oidc-authenticator/config.json` |

**Note:** Both can coexist! Users authenticate twice:
1. **Backstage login** - GitHub/OIDC for Backstage access
2. **Cluster auth** - OIDC Authenticator for K8s access

## Current Status

### ✅ Working

- Daemon lifecycle management (start/stop/status)
- One-off authentication mode
- PKCE OAuth flow
- JWT token decoding and claims display
- Token transmission to backend
- Backstage UI integration (Settings page button)
- Health check endpoint
- Verbose debugging mode

### 🚧 TODO

- **Token persistence** in Backstage backend (currently in-memory only)
- **Token refresh** logic for expired tokens
- **JWT signature validation** using JWKS
- **User identity mapping** (OIDC identity → Backstage user)
- **Kubernetes plugin integration** to use stored tokens
- **Token revocation** endpoint
- **Audit logging** for authentication events

## API Reference

### Daemon Endpoints

```
GET  /health           - Health check
GET  /                 - Initiate authentication (browser access)
```

### Backend Endpoints

```
POST /api/cluster-auth/tokens    - Receive tokens from daemon
GET  /api/cluster-auth/status    - Check authentication status
GET  /api/cluster-auth/token     - Retrieve token for K8s API
```

## Example: Using Tokens with Kubernetes

Once token storage is implemented:

```typescript
// In Backstage plugin
const response = await fetch('/api/cluster-auth/token');
const { access_token } = await response.json();

// Use with @kubernetes/client-node
const k8sConfig = new KubeConfig();
k8sConfig.loadFromOptions({
  clusters: [{
    name: 'my-cluster',
    server: 'https://kubernetes.example.com',
  }],
  users: [{
    name: 'oidc-user',
    token: access_token,
  }],
  contexts: [{
    name: 'default',
    cluster: 'my-cluster',
    user: 'oidc-user',
  }],
  currentContext: 'default',
});

const k8sApi = k8sConfig.makeApiClient(CoreV1Api);
const pods = await k8sApi.listNamespacedPod('default');
```

## Scripts

Convenient wrapper scripts available:

```bash
# From workspace root
./scripts/oidc-authenticator.sh start
./scripts/oidc-authenticator.sh status
./scripts/oidc-authenticator.sh stop

# One-off authentication
./scripts/oidc-authenticator.sh --verbose
```

## Related Documentation

- [OIDC Authenticator README](../oidc-authenticator/README.md) - Daemon documentation
- [Backstage Cluster Auth Plugin](../app-portal/packages/backend/src/plugins/cluster-auth.ts) - Backend implementation
- [Cluster Auth Button Component](../app-portal/packages/app/src/components/ClusterAuthButton.tsx) - Frontend component

## Support

For issues or questions:

1. Check daemon logs: `node bin/cli.js start --verbose`
2. Check Backstage backend logs
3. Verify OIDC provider configuration
4. Review JWT token claims for issues
5. Open issue in repository

## Summary

The OIDC Authenticator provides a secure, user-friendly way to authenticate with Kubernetes clusters using Auth0/Rackspace OIDC credentials. It follows the familiar `kubectl oidc-login` pattern while integrating seamlessly with Backstage's Settings UI. The daemon handles all OAuth/PKCE complexity, allowing the backend to simply receive and manage tokens.
