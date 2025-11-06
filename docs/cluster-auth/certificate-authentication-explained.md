# Kubernetes Certificate Authentication - Complete Explanation

## How Certificate Authentication Works

### Overview

Certificate authentication uses **X.509 client certificates** to prove identity to Kubernetes. It's like showing an ID card - the certificate contains your identity (username and groups) and is signed by a trusted authority.

```
┌─────────────────────────────────────────────────────────────┐
│                    Certificate Structure                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Certificate Subject (your identity):                       │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  CN (Common Name) = alice      ← Username            │ │
│  │  O (Organization) = developers  ← Group 1            │ │
│  │  O (Organization) = backend-team ← Group 2           │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  Signed by: Kubernetes CA                                  │
│  Valid from: 2025-10-31                                    │
│  Valid to: 2026-10-31                                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### The Complete Flow

```
Step 1: Generate Private Key (User Side)
──────────────────────────────────────────
┌──────────────────────┐
│  alice.key           │  ← Private key (secret, never shared)
│  (2048-bit RSA)      │
└──────────────────────┘
         ↓
  openssl genrsa -out alice.key 2048


Step 2: Create Certificate Signing Request (CSR)
──────────────────────────────────────────────────
┌──────────────────────┐
│  alice.csr           │  ← Request to be signed
│                      │
│  Contains:           │
│  - Public key        │
│  - CN=alice          │
│  - O=developers      │
└──────────────────────┘
         ↓
  openssl req -new -key alice.key -out alice.csr \
    -subj "/CN=alice/O=developers"


Step 3: Sign CSR with Kubernetes CA
────────────────────────────────────
┌──────────────────────┐      ┌──────────────────────┐
│  alice.csr           │  →   │  Kubernetes CA       │
│  (unsigned)          │      │  /etc/kubernetes/    │
└──────────────────────┘      │  pki/ca.{crt,key}    │
                              └──────────────────────┘
                                        ↓
                              ┌──────────────────────┐
                              │  alice.crt           │
                              │  (signed certificate)│
                              └──────────────────────┘


Step 4: Use Certificate + Key to Authenticate
──────────────────────────────────────────────
┌──────────────────────┐   ┌──────────────────────┐
│  alice.crt           │ + │  alice.key           │
│  (public cert)       │   │  (private key)       │
└──────────────────────┘   └──────────────────────┘
            ↓
    kubectl --client-certificate=alice.crt \
            --client-key=alice.key \
            get pods


Step 5: Kubernetes Validates
─────────────────────────────
┌─────────────────────────────────────────────┐
│  Kubernetes API Server                      │
│                                             │
│  1. Check certificate signature             │
│     ✓ Signed by trusted CA?                │
│                                             │
│  2. Extract identity from certificate       │
│     Username: CN = alice                    │
│     Groups: O = [developers]                │
│                                             │
│  3. Check RBAC rules                        │
│     Does alice or group "developers"        │
│     have permissions?                       │
│                                             │
│  4. Allow/Deny request                      │
└─────────────────────────────────────────────┘
```

## Keys Explained

### 1. User's Private Key (`alice.key`)

**What it is**:
- A randomly generated secret key
- 2048-bit RSA (or 4096-bit for more security)
- Used to prove you own the certificate

**Who has it**: Only the user (alice)

**Where it's stored**:
```bash
~/.kube/test-users/certs/alice.key

# Or embedded in kubeconfig:
~/.kube/test-users/alice-cert-kubeconfig.yaml
```

**Must keep secret**: ✅ YES! Anyone with this key can impersonate alice

**Example**:
```
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA2Xg5k3pN5m8Q7...
... (long base64 encoded data) ...
-----END RSA PRIVATE KEY-----
```

---

### 2. User's Certificate (`alice.crt`)

**What it is**:
- Public certificate containing alice's identity
- Signed by Kubernetes CA
- Contains username (CN) and groups (O)

**Who has it**: User (alice) and presented to Kubernetes

**Where it's stored**:
```bash
~/.kube/test-users/certs/alice.crt

# Or embedded in kubeconfig
```

**Must keep secret**: ❌ NO, it's public (but only alice can use it with the private key)

**Example**:
```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 123456
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN=kubernetes-ca
        Validity
            Not Before: Oct 31 12:00:00 2025 GMT
            Not After : Oct 31 12:00:00 2026 GMT
        Subject: CN=alice, O=developers, O=backend-team
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                RSA Public-Key: (2048 bit)
                ...
```

**Key fields**:
- **Issuer**: `CN=kubernetes-ca` (who signed it)
- **Subject**: `CN=alice, O=developers` (identity and groups)
- **Not After**: Certificate expiration date

---

### 3. Kubernetes CA Certificate (`ca.crt`)

**What it is**:
- The Certificate Authority's public certificate
- Used to verify that user certificates are authentic
- Every certificate signed by this CA is trusted

**Who has it**: Everyone (it's public)

**Where it's stored**:
```bash
# On Kubernetes master node
/etc/kubernetes/pki/ca.crt

# Users also need a copy
~/.kube/test-users/certs/ca.crt

# Or embedded in kubeconfig
```

**Must keep secret**: ❌ NO, it's public

**Purpose**: Kubernetes API server uses this to verify client certificates were signed by a trusted CA

---

### 4. Kubernetes CA Private Key (`ca.key`) ⚠️ CRITICAL

**What it is**:
- The CA's private key used to SIGN certificates
- Only exists on Kubernetes master nodes
- Most sensitive key in the entire cluster!

**Who has it**: Only Kubernetes control plane

**Where it's stored**:
```bash
# On Kubernetes master node (protected)
/etc/kubernetes/pki/ca.key
```

**Must keep secret**: ✅ YES! ABSOLUTELY!
- If compromised, attacker can create certificates for ANY user
- Can impersonate anyone in the cluster
- Full cluster compromise

**Users never touch this**: Our script uses Kubernetes CSR API instead of direct access

---

## What Gets Stored and Where

### On Your Local Machine (User: alice)

```
~/.kube/test-users/
├── certs/
│   ├── alice.key        ← Private key (SECRET!)
│   ├── alice.crt        ← Public certificate
│   └── ca.crt           ← Kubernetes CA cert (public)
│
└── alice-cert-kubeconfig.yaml
    (Contains embedded copies of all above)
```

### On Kubernetes Master Node

```
/etc/kubernetes/pki/
├── ca.crt               ← CA public cert
├── ca.key               ← CA private key (CRITICAL SECRET!)
├── apiserver.crt        ← API server cert
├── apiserver.key        ← API server private key
└── ... (other Kubernetes certs)
```

### In Kubernetes (after using CSR API)

```bash
# CertificateSigningRequest resource
kubectl get csr alice-csr

# Contains:
# - The CSR (certificate request)
# - Approval status
# - Signed certificate (once approved)

# After you download the cert, this can be deleted
kubectl delete csr alice-csr
```

## Security Deep Dive

### What Needs to Be Secret?

| Item | Secret? | Why |
|------|---------|-----|
| **User's private key** | ✅ YES | Proves you are alice |
| **User's certificate** | ❌ No | Public identity, but useless without private key |
| **CA certificate** | ❌ No | Public, everyone needs it to verify certs |
| **CA private key** | ✅ YES! | Can create fake certificates for anyone |

### Private Key Security

```bash
# Private keys should have restricted permissions
chmod 600 ~/.kube/test-users/certs/alice.key

# Owner: alice (read/write)
# Others: no access
-rw------- 1 alice staff 1675 Oct 31 12:00 alice.key
```

### What If Private Key Is Compromised?

```
Attacker has alice.key:
├─ Can impersonate alice ✓
├─ Gets alice's group memberships ✓
├─ Can access everything alice can access ✓
└─ Solution: Revoke/delete alice's certificate

Revoke certificate:
  kubectl delete csr alice-csr

Delete RoleBindings for alice's groups:
  kubectl delete clusterrolebinding developers-edit

Create new certificate for alice:
  ./scripts/create-user-with-cert.sh alice developers
```

### What If CA Private Key Is Compromised? ⚠️

```
Attacker has ca.key:
├─ Can create certificates for ANY username ✓
├─ Can create certificates for ANY groups ✓
├─ Full cluster compromise ✓
└─ Solution: Rotate entire CA (cluster disaster recovery)

This is catastrophic! Requires:
  1. Generate new CA
  2. Re-issue ALL certificates in cluster
  3. Restart all cluster components
  4. Rotate all kubeconfig files
```

## How create-user-with-cert.sh Works

### Step-by-Step Breakdown

```bash
# 1. Generate user's private key locally
openssl genrsa -out alice.key 2048
# ✓ Stays on your machine (secret)

# 2. Create CSR with identity and groups
openssl req -new -key alice.key -out alice.csr \
  -subj "/CN=alice/O=developers/O=backend-team"
# ✓ Contains public key + identity request

# 3. Submit CSR to Kubernetes
kubectl create -f - <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: alice-csr
spec:
  request: $(cat alice.csr | base64 | tr -d '\n')
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
EOF
# ✓ Kubernetes receives CSR
# ✓ We DON'T touch ca.key directly!

# 4. Approve CSR (requires admin permissions)
kubectl certificate approve alice-csr
# ✓ Kubernetes signs CSR with its ca.key
# ✓ Creates signed certificate

# 5. Download signed certificate
kubectl get csr alice-csr -o jsonpath='{.status.certificate}' | \
  base64 -d > alice.crt
# ✓ Now we have signed certificate

# 6. Create kubeconfig
kubectl config set-credentials alice \
  --client-certificate=alice.crt \
  --client-key=alice.key \
  --embed-certs=true
# ✓ Embed cert and key in kubeconfig
# ✓ Ready to use!
```

### Why This Is Secure

1. **CA private key never leaves master node**
   - Script uses Kubernetes CSR API
   - Kubernetes signs certificates internally
   - No direct access to `ca.key`

2. **User's private key generated locally**
   - Created on user's machine
   - Never transmitted to Kubernetes
   - Only user has it

3. **Certificate signing is audited**
   - CSR approval is a Kubernetes API call
   - Shows up in audit logs
   - Can be restricted with RBAC

## Certificate Lifecycle

```
Day 1: Create Certificate
──────────────────────────
./scripts/create-user-with-cert.sh alice developers
  ↓
alice.crt valid for 1 year


Day 180: Certificate Still Valid
─────────────────────────────────
kubectl --kubeconfig=alice-cert-kubeconfig.yaml get pods
  ✓ Works fine


Day 365: Certificate About to Expire
─────────────────────────────────────
kubectl --kubeconfig=alice-cert-kubeconfig.yaml get pods
  ✓ Still works (not expired yet)


Day 366: Certificate Expired
─────────────────────────────
kubectl --kubeconfig=alice-cert-kubeconfig.yaml get pods
  ✗ Error: certificate has expired

Solution: Create new certificate
  ./scripts/create-user-with-cert.sh alice developers
  # Same username, new certificate, new key


Certificate Renewal:
────────────────────
1. Create new certificate (same username/groups)
2. Replace old kubeconfig with new one
3. Delete old certificate files
4. No changes needed to RBAC (same username/groups)
```

## Comparison: Certificate vs OIDC

### Certificate Authentication

```
User authenticates:
  ┌─────────────────┐
  │ Client Cert     │  ← Created once
  │ + Private Key   │  ← Local storage
  └─────────────────┘
         ↓
  Kubernetes API Server
  • Verifies signature (CA cert)
  • Extracts CN → username
  • Extracts O → groups
  • Checks RBAC
```

**Pros**:
- ✅ No external dependencies
- ✅ Offline authentication
- ✅ Fast (no network calls)
- ✅ Simple setup

**Cons**:
- ❌ Groups fixed at cert creation
- ❌ Certificate rotation needed
- ❌ Manual key management

### OIDC Authentication

```
User authenticates:
  ┌─────────────────┐
  │ Browser Login   │  ← Every session
  │ (username/pwd)  │  ← OIDC Provider
  └─────────────────┘
         ↓
  Get ID Token with groups
         ↓
  Kubernetes API Server
  • Verifies token (OIDC provider)
  • Extracts email → username
  • Extracts groups claim → groups
  • Checks RBAC
```

**Pros**:
- ✅ Dynamic group membership
- ✅ Centralized user management
- ✅ MFA support
- ✅ Token expiration

**Cons**:
- ❌ Requires OIDC provider
- ❌ Network dependency
- ❌ More complex setup

## Storage Best Practices

### Recommended Structure

```bash
# Certificates and keys
~/.kube/test-users/
├── certs/                    # Certificate storage
│   ├── alice.key            # Private keys (600 permissions)
│   ├── alice.crt            # Certificates (644 ok)
│   ├── bob.key
│   ├── bob.crt
│   └── ca.crt               # Kubernetes CA (shared)
│
└── kubeconfigs/              # Or store separately
    ├── alice-cert-kubeconfig.yaml
    └── bob-cert-kubeconfig.yaml
```

### Embedded vs Separate Files

**Embedded (Recommended)**:
```yaml
# In kubeconfig - everything in one file
users:
- name: alice
  user:
    client-certificate-data: LS0tLS1CRUd... (base64)
    client-key-data: LS0tLS1CRUdJTi... (base64)
```

**Pros**:
- ✅ Single file to manage
- ✅ Easy to share (carefully!)
- ✅ No path dependencies

**Separate Files**:
```yaml
# In kubeconfig - references external files
users:
- name: alice
  user:
    client-certificate: /path/to/alice.crt
    client-key: /path/to/alice.key
```

**Pros**:
- ✅ Can share kubeconfig without sharing key
- ✅ Easier to rotate keys

### Backup Strategy

```bash
# Backup certificates and keys
tar czf kubectl-certs-backup-$(date +%Y%m%d).tar.gz \
  ~/.kube/test-users/certs/

# Encrypt backup
gpg --encrypt kubectl-certs-backup-*.tar.gz

# Store encrypted backup safely
# - Password manager
# - Encrypted USB drive
# - Encrypted cloud storage

# DO NOT store in:
# ✗ Git repositories
# ✗ Unencrypted cloud storage
# ✗ Email
# ✗ Slack/chat
```

## Troubleshooting

### "certificate has expired"

```bash
# Check certificate expiration
openssl x509 -in alice.crt -noout -dates

# Output:
# notBefore=Oct 31 12:00:00 2025 GMT
# notAfter=Oct 31 12:00:00 2026 GMT

# Solution: Create new certificate
./scripts/create-user-with-cert.sh alice developers backend-team
```

### "certificate signed by unknown authority"

```bash
# Kubernetes doesn't trust the CA that signed your cert
# Usually means wrong CA certificate

# Check CA cert in kubeconfig matches cluster
kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | \
  base64 -d > cluster-ca.crt

# Compare with your CA cert
diff cluster-ca.crt ~/.kube/test-users/certs/ca.crt

# If different, update CA cert
kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | \
  base64 -d > ~/.kube/test-users/certs/ca.crt
```

### "unable to read client-key"

```bash
# Private key file missing or wrong path

# Check file exists
ls -la ~/.kube/test-users/certs/alice.key

# Check permissions
chmod 600 ~/.kube/test-users/certs/alice.key

# Check kubeconfig points to right path
kubectl config view --raw
```

## Summary

### What Gets Stored

1. **alice.key** (secret) - User's private key, proves identity
2. **alice.crt** (public) - User's certificate, contains username/groups
3. **ca.crt** (public) - Kubernetes CA cert, verifies certificates
4. **ca.key** (NEVER STORED BY USERS) - Only on Kubernetes masters

### Keys You Need to Protect

- ✅ User's private key (`alice.key`) - Keep secret
- ✅ CA private key (`ca.key`) - Never touch (only Kubernetes has it)
- ❌ User's certificate (`alice.crt`) - Public
- ❌ CA certificate (`ca.crt`) - Public

### How It Works

1. Generate private key locally
2. Create CSR with username + groups
3. Submit CSR to Kubernetes (uses API, not direct ca.key access)
4. Kubernetes signs CSR with its CA key
5. Download signed certificate
6. Use certificate + private key to authenticate

### Security Model

- Private key = Password (keep secret!)
- Certificate = ID card (shows who you are, has expiration)
- CA = Government issuing ID cards (Kubernetes trusts it)

---

**Generated**: 2025-10-31
