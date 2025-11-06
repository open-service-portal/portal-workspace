# Alternative Authentication Methods for Better Group Management

## The Problem

ServiceAccounts cannot be added to custom groups. You want test users with flexible group management like OIDC users, but without setting up a full OIDC provider.

## Authentication Methods Comparison

| Method | Group Support | Complexity | Best For | Group Management |
|--------|--------------|------------|----------|------------------|
| **ServiceAccount** | ❌ Namespace-only | Low | CI/CD, testing | Automatic (namespace) |
| **Client Certificates** | ✅ Custom groups | Medium | Local testing | Certificate O fields |
| **OIDC (Local)** | ✅ Full custom | Medium | Team testing | OIDC provider |
| **OIDC (Production)** | ✅ Full custom | High | Real users | Auth0/Keycloak |
| **Static Token File** | ✅ Custom groups | Low | Quick testing | Manual file edit |
| **Webhook** | ✅ Custom groups | High | Custom logic | Your webhook |

## Recommended Solutions

### Option 1: Client Certificates ⭐ BEST FOR LOCAL TESTING

**Pros**:
- ✅ Custom groups embedded in certificate
- ✅ Multiple groups per user
- ✅ No external dependencies
- ✅ Standard Kubernetes feature
- ✅ Good for local development

**Cons**:
- ❌ Requires certificate management
- ❌ Groups fixed at certificate creation
- ❌ Certificate rotation needed for group changes

**How it works**:
```
Certificate Subject:
  CN=alice              ← Username
  O=developers          ← Group 1
  O=backend-team        ← Group 2

Kubernetes sees:
  Username: alice
  Groups: [developers, backend-team]
```

**Implementation**:

```bash
#!/bin/bash
# Create user certificate with groups

USERNAME="alice"
GROUPS=("developers" "backend-team")  # Multiple groups!

# Generate certificate with groups in O (Organization) fields
openssl genrsa -out ${USERNAME}.key 2048

# Build subject with multiple O fields for groups
SUBJECT="/CN=${USERNAME}"
for GROUP in "${GROUPS[@]}"; do
  SUBJECT="${SUBJECT}/O=${GROUP}"
done

# Create CSR
openssl req -new -key ${USERNAME}.key -out ${USERNAME}.csr -subj "${SUBJECT}"

# Sign with Kubernetes CA
# (Kubernetes CA cert/key needed)
sudo openssl x509 -req -in ${USERNAME}.csr \
  -CA /etc/kubernetes/pki/ca.crt \
  -CAkey /etc/kubernetes/pki/ca.key \
  -CAcreateserial \
  -out ${USERNAME}.crt \
  -days 365

# Create kubeconfig
kubectl config set-credentials ${USERNAME} \
  --client-certificate=${USERNAME}.crt \
  --client-key=${USERNAME}.key \
  --embed-certs=true

# Test
kubectl auth whoami --kubeconfig=...
# Shows: username: alice, groups: [developers, backend-team]
```

**Script Example**: See below for full `create-user-with-cert.sh`

---

### Option 2: Local OIDC Provider (Dex) ⭐ BEST FOR TEAM TESTING

**Pros**:
- ✅ Full OIDC functionality
- ✅ Flexible group management
- ✅ Multiple groups per user
- ✅ Web-based login
- ✅ Similar to production setup

**Cons**:
- ❌ Requires running Dex
- ❌ More complex setup
- ❌ Need to configure Kubernetes API server

**How it works**:
```
1. Run Dex locally (in Kubernetes or Docker)
2. Configure static users with groups in Dex config
3. Configure Kubernetes API server to use Dex
4. Users authenticate via browser
5. Get token with groups → use with kubectl
```

**Dex Configuration**:

```yaml
# dex-config.yaml
issuer: https://dex.example.com:5556/dex

staticClients:
- id: kubernetes
  name: 'Kubernetes'
  secret: kubernetes-secret
  redirectURIs:
  - 'http://localhost:8000'
  - 'http://localhost:18000'

staticPasswords:
- email: "alice@example.com"
  hash: "$2a$10$..." # bcrypt hash
  username: "alice"
  userID: "alice"
  groups:
  - developers
  - backend-team

- email: "bob@example.com"
  hash: "$2a$10$..."
  username: "bob"
  userID: "bob"
  groups:
  - developers
  - frontend-team

- email: "admin@example.com"
  hash: "$2a$10$..."
  username: "admin"
  userID: "admin"
  groups:
  - platform-admins
```

**Kubernetes API Server Configuration**:

```yaml
# Add to kube-apiserver flags
--oidc-issuer-url=https://dex.example.com:5556/dex
--oidc-client-id=kubernetes
--oidc-username-claim=email
--oidc-username-prefix=oidc:
--oidc-groups-claim=groups
--oidc-groups-prefix=oidc:
--oidc-ca-file=/etc/kubernetes/pki/dex-ca.crt
```

**Usage**:
```bash
# Login via browser (gets token)
kubectl oidc-login

# Or use token directly
kubectl --token=$TOKEN auth whoami
# Shows: oidc:alice@example.com, groups: [oidc:developers, oidc:backend-team]
```

**Script Example**: See below for full `setup-local-dex.sh`

---

### Option 3: Static Token File (Simplest)

**Pros**:
- ✅ Very simple setup
- ✅ Custom groups
- ✅ Multiple groups per user
- ✅ Easy to change groups (just edit file)

**Cons**:
- ❌ Not secure (plaintext tokens)
- ❌ Manual token management
- ❌ Only for local testing
- ❌ Requires API server restart to reload

**How it works**:

```csv
# /etc/kubernetes/pki/static-tokens.csv
# token,username,uid,groups
abc123,alice,alice,"developers,backend-team"
def456,bob,bob,"developers,frontend-team"
ghi789,admin,admin,"platform-admins"
```

**Kubernetes API Server Configuration**:

```yaml
# Add to kube-apiserver flags
--token-auth-file=/etc/kubernetes/pki/static-tokens.csv
```

**Usage**:
```bash
# Use token directly
kubectl --token=abc123 auth whoami
# Shows: username: alice, groups: [developers, backend-team]

# Create kubeconfig
kubectl config set-credentials alice --token=abc123
```

**Script Example**: See below for `create-user-with-token.sh`

---

## Detailed Implementation Scripts

### Script 1: create-user-with-cert.sh (Client Certificates)

```bash
#!/usr/bin/env bash
#
# Create User with Client Certificate and Groups
# Purpose: Create test user with custom group membership via certificate
#
# Usage:
#   ./scripts/create-user-with-cert.sh <username> <group1> [group2] [group3] ...
#
# Examples:
#   ./scripts/create-user-with-cert.sh alice developers
#   ./scripts/create-user-with-cert.sh bob developers backend-team
#   ./scripts/create-user-with-cert.sh charlie platform-admins

set -euo pipefail

USERNAME="${1:-}"
shift || true
GROUPS=("$@")

if [[ -z "$USERNAME" ]] || [[ ${#GROUPS[@]} -eq 0 ]]; then
  echo "Usage: $0 <username> <group1> [group2] [group3] ..."
  echo ""
  echo "Examples:"
  echo "  $0 alice developers"
  echo "  $0 bob developers backend-team"
  exit 1
fi

CERT_DIR="${HOME}/.kube/test-users/certs"
KUBECONFIG_DIR="${HOME}/.kube/test-users"
CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
CLUSTER_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ${NC} $*"; }
log_success() { echo -e "${GREEN}✓${NC} $*"; }
log_step() { echo -e "${YELLOW}▸${NC} $*"; }

mkdir -p "${CERT_DIR}"
mkdir -p "${KUBECONFIG_DIR}"

echo ""
echo "Creating user with certificate authentication"
echo "  Username: ${USERNAME}"
echo "  Groups: ${GROUPS[*]}"
echo ""

# Build subject with multiple O fields (one per group)
SUBJECT="/CN=${USERNAME}"
for GROUP in "${GROUPS[@]}"; do
  SUBJECT="${SUBJECT}/O=${GROUP}"
done

log_step "Generating private key..."
openssl genrsa -out "${CERT_DIR}/${USERNAME}.key" 2048 2>/dev/null
log_success "Private key created"

log_step "Creating certificate signing request..."
openssl req -new -key "${CERT_DIR}/${USERNAME}.key" \
  -out "${CERT_DIR}/${USERNAME}.csr" \
  -subj "${SUBJECT}" 2>/dev/null
log_success "CSR created"

log_step "Creating Kubernetes CertificateSigningRequest..."
cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${USERNAME}-csr
spec:
  request: $(cat "${CERT_DIR}/${USERNAME}.csr" | base64 | tr -d '\n')
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
EOF
log_success "CertificateSigningRequest created"

log_step "Approving certificate..."
kubectl certificate approve ${USERNAME}-csr >/dev/null
log_success "Certificate approved"

log_step "Retrieving signed certificate..."
sleep 2
kubectl get csr ${USERNAME}-csr -o jsonpath='{.status.certificate}' | \
  base64 -d > "${CERT_DIR}/${USERNAME}.crt"
log_success "Certificate retrieved"

log_step "Getting cluster CA..."
kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | \
  base64 -d > "${CERT_DIR}/ca.crt"
log_success "CA certificate saved"

log_step "Creating kubeconfig..."
KUBECONFIG_FILE="${KUBECONFIG_DIR}/${USERNAME}-cert-kubeconfig.yaml"

cat > "${KUBECONFIG_FILE}" <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: ${CERT_DIR}/ca.crt
    server: ${CLUSTER_SERVER}
  name: ${CLUSTER_NAME}
contexts:
- context:
    cluster: ${CLUSTER_NAME}
    user: ${USERNAME}
  name: ${USERNAME}@${CLUSTER_NAME}
current-context: ${USERNAME}@${CLUSTER_NAME}
users:
- name: ${USERNAME}
  user:
    client-certificate: ${CERT_DIR}/${USERNAME}.crt
    client-key: ${CERT_DIR}/${USERNAME}.key
EOF

log_success "Kubeconfig created"

echo ""
log_success "User created successfully!"
echo ""
log_info "User details:"
echo "  Username: ${USERNAME}"
echo "  Authentication: Client certificate"
echo "  Groups: ${GROUPS[*]}"
echo "  Certificate: ${CERT_DIR}/${USERNAME}.crt"
echo "  Key: ${CERT_DIR}/${USERNAME}.key"
echo "  Kubeconfig: ${KUBECONFIG_FILE}"
echo ""

log_info "Test identity and groups:"
echo "  export KUBECONFIG=${KUBECONFIG_FILE}"
echo "  kubectl auth whoami"
echo "  # Should show: username: ${USERNAME}"
echo "  # Groups: $(printf "%s, " "${GROUPS[@]}" | sed 's/, $//')"
echo ""

log_info "Grant permissions to groups:"
for GROUP in "${GROUPS[@]}"; do
  echo "  # Allow group '${GROUP}' to edit resources"
  echo "  kubectl create clusterrolebinding ${GROUP}-edit \\"
  echo "    --clusterrole=edit \\"
  echo "    --group=${GROUP}"
  echo ""
done

log_info "To add user to more groups:"
echo "  # Create new certificate with additional groups"
echo "  $0 ${USERNAME} ${GROUPS[*]} new-group"
echo ""

log_info "To clean up:"
echo "  kubectl delete csr ${USERNAME}-csr"
echo "  rm ${CERT_DIR}/${USERNAME}.*"
echo "  rm ${KUBECONFIG_FILE}"
echo ""
```

---

### Script 2: setup-local-dex.sh (Local OIDC with Dex)

```bash
#!/usr/bin/env bash
#
# Setup Local Dex OIDC Provider
# Purpose: Deploy Dex in Kubernetes for local OIDC testing
#
# Usage:
#   ./scripts/setup-local-dex.sh

set -euo pipefail

NAMESPACE="dex"
DEX_VERSION="v2.37.0"

echo "Setting up local Dex OIDC provider..."
echo ""

# Create namespace
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Generate bcrypt hashes for passwords
# Password: "password" for all users (change in production!)
PASSWORD_HASH='$2a$10$2b2cU8CPhOTaGrs1HRQuAueS7JTT5ZHsHSzYiFPm1leZck7Mc8T4W'

# Create Dex ConfigMap
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: dex-config
  namespace: ${NAMESPACE}
data:
  config.yaml: |
    issuer: http://dex.${NAMESPACE}.svc.cluster.local:5556/dex

    storage:
      type: kubernetes
      config:
        inCluster: true

    web:
      http: 0.0.0.0:5556

    oauth2:
      skipApprovalScreen: true

    staticClients:
    - id: kubernetes
      name: 'Kubernetes'
      secret: kubernetes-client-secret
      redirectURIs:
      - 'http://localhost:8000'
      - 'http://localhost:18000'
      - 'urn:ietf:wg:oauth:2.0:oob'

    enablePasswordDB: true
    staticPasswords:
    - email: "alice@example.com"
      hash: "${PASSWORD_HASH}"
      username: "alice"
      userID: "alice"
      groups:
      - developers
      - backend-team

    - email: "bob@example.com"
      hash: "${PASSWORD_HASH}"
      username: "bob"
      userID: "bob"
      groups:
      - developers
      - frontend-team

    - email: "charlie@example.com"
      hash: "${PASSWORD_HASH}"
      username: "charlie"
      userID: "charlie"
      groups:
      - platform-admins

    - email: "admin@example.com"
      hash: "${PASSWORD_HASH}"
      username: "admin"
      userID: "admin"
      groups:
      - platform-admins
      - developers
EOF

# Deploy Dex
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dex
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dex
  template:
    metadata:
      labels:
        app: dex
    spec:
      serviceAccountName: dex
      containers:
      - name: dex
        image: ghcr.io/dexidp/dex:${DEX_VERSION}
        args:
        - dex
        - serve
        - /etc/dex/config.yaml
        ports:
        - name: http
          containerPort: 5556
        volumeMounts:
        - name: config
          mountPath: /etc/dex
      volumes:
      - name: config
        configMap:
          name: dex-config
---
apiVersion: v1
kind: Service
metadata:
  name: dex
  namespace: ${NAMESPACE}
spec:
  type: ClusterIP
  ports:
  - port: 5556
    targetPort: 5556
  selector:
    app: dex
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: dex
  namespace: ${NAMESPACE}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: dex
rules:
- apiGroups: ["dex.coreos.com"]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: ["apiextensions.k8s.io"]
  resources: ["customresourcedefinitions"]
  verbs: ["create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: dex
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: dex
subjects:
- kind: ServiceAccount
  name: dex
  namespace: ${NAMESPACE}
EOF

echo "✓ Dex deployed"
echo ""
echo "Next steps:"
echo "1. Port-forward Dex:"
echo "   kubectl port-forward -n ${NAMESPACE} svc/dex 5556:5556"
echo ""
echo "2. Configure Kubernetes API server with these flags:"
echo "   --oidc-issuer-url=http://127.0.0.1:5556/dex"
echo "   --oidc-client-id=kubernetes"
echo "   --oidc-username-claim=email"
echo "   --oidc-username-prefix=oidc:"
echo "   --oidc-groups-claim=groups"
echo "   --oidc-groups-prefix=oidc:"
echo ""
echo "3. Install kubelogin:"
echo "   https://github.com/int128/kubelogin"
echo ""
echo "4. Login:"
echo "   kubectl oidc-login setup \\"
echo "     --oidc-issuer-url=http://127.0.0.1:5556/dex \\"
echo "     --oidc-client-id=kubernetes \\"
echo "     --oidc-client-secret=kubernetes-client-secret"
echo ""
echo "Test users (password: 'password'):"
echo "  alice@example.com   → groups: [developers, backend-team]"
echo "  bob@example.com     → groups: [developers, frontend-team]"
echo "  charlie@example.com → groups: [platform-admins]"
echo "  admin@example.com   → groups: [platform-admins, developers]"
echo ""
```

---

### Script 3: create-user-with-token.sh (Static Tokens)

```bash
#!/usr/bin/env bash
#
# Create User with Static Token
# Purpose: Generate static token and add to token file
#
# IMPORTANT: This requires editing Kubernetes API server configuration
# and is only suitable for local testing!
#
# Usage:
#   ./scripts/create-user-with-token.sh <username> <group1> [group2] ...

set -euo pipefail

USERNAME="${1:-}"
shift || true
GROUPS=("$@")

if [[ -z "$USERNAME" ]] || [[ ${#GROUPS[@]} -eq 0 ]]; then
  echo "Usage: $0 <username> <group1> [group2] ..."
  exit 1
fi

# Generate random token
TOKEN=$(openssl rand -hex 16)

# Join groups with comma
GROUPS_STR=$(IFS=,; echo "${GROUPS[*]}")

echo "Generated token for user: ${USERNAME}"
echo ""
echo "Token: ${TOKEN}"
echo "Groups: ${GROUPS_STR}"
echo ""
echo "Add this line to /etc/kubernetes/pki/static-tokens.csv:"
echo "${TOKEN},${USERNAME},${USERNAME},\"${GROUPS_STR}\""
echo ""
echo "Then restart kube-apiserver with:"
echo "  --token-auth-file=/etc/kubernetes/pki/static-tokens.csv"
echo ""
echo "Create kubeconfig:"
echo "  kubectl config set-credentials ${USERNAME} --token=${TOKEN}"
echo "  kubectl config set-context ${USERNAME} --cluster=... --user=${USERNAME}"
echo ""
```

---

## Comparison and Recommendations

### For Local Development

**Best: Client Certificates** ✅
- Easy to set up
- No external dependencies
- Full group support
- Good for 5-10 test users

**Script**: `create-user-with-cert.sh`

### For Team Testing

**Best: Local Dex** ✅
- Realistic OIDC flow
- Web-based login
- Easy to add/modify users
- Similar to production

**Script**: `setup-local-dex.sh`

### For Quick Testing

**Best: Static Tokens** ✅
- Simplest setup
- Easy to change groups (edit file)
- No certificate management

**Script**: `create-user-with-token.sh`

### For Production

**Best: Cloud OIDC Provider** ✅
- Auth0, Keycloak, Google, Azure AD
- Proper user management
- MFA support
- Audit logs

**Scripts**: Existing `rbac-add-admin.sh`, `rbac-create-group.sh`

---

## Migration Path

### Current State (ServiceAccounts)
```bash
./scripts/create-user.sh alice edit myapp
# Limited to namespace-based groups
```

### Recommended Path

1. **Start**: Client Certificates for local testing
   ```bash
   ./scripts/create-user-with-cert.sh alice developers backend-team
   ```

2. **Team Testing**: Deploy local Dex
   ```bash
   ./scripts/setup-local-dex.sh
   # Add users to dex-config ConfigMap
   ```

3. **Production**: Use cloud OIDC provider
   ```bash
   # Configure Auth0/Keycloak
   ./scripts/rbac-create-group.sh developers edit
   ```

---

**Generated**: 2025-10-31
