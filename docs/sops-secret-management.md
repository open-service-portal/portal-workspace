# SOPS Secret Management Guide

This guide explains how we manage secrets using SOPS with SSH keys for the Open Service Portal project.

## Why SOPS?

### Problems it Solves
- **No plaintext secrets in Git** - All sensitive data is encrypted before committing
- **Version control for secrets** - Track changes to secrets alongside code
- **Team collaboration** - Multiple team members can decrypt using their SSH keys
- **Local development** - Seamless secret management without external services
- **GitOps compatible** - Works with Flux, ArgoCD, and other GitOps tools

### Key Benefits
- **Uses existing SSH keys** - No need to generate new encryption keys
- **Automatic decryption** - direnv integration for seamless local development
- **Multiple formats** - Supports YAML, JSON, ENV, INI, BINARY files
- **Partial encryption** - Only encrypts values, keys remain readable
- **Works offline** - No external key management service required

## Quick Start

### For New Team Members

```bash
# 1. Share your SSH public key with the team
cat ~/.ssh/id_ed25519.pub  # or ~/.ssh/id_rsa.pub

# 2. Wait for team lead to add your key to .sops.yaml

# 3. Test decryption
cd app-portal
sops -d --input-type dotenv --output-type dotenv .env.enc

# 4. Enable direnv
direnv allow
```

### For Team Leads

```bash
# 1. Add new member's SSH public key to .sops.yaml
vim app-portal/.sops.yaml  # Add their ssh-ed25519 or ssh-rsa key

# 2. Update existing encrypted files with the new key
cd app-portal
sops updatekeys .env.enc
sops updatekeys github-app-key.pem.enc

# 3. Commit and push changes
git add .sops.yaml *.enc
git commit -m "chore: add [Name]'s SSH key to SOPS"
git push
```

---

## Understanding SOPS

### What is SOPS?
SOPS (Secrets OPerationS) is a tool that encrypts files so they can be safely stored in Git. It only encrypts the values, not the keys, making diffs readable.

### How SSH Keys Work with SOPS
1. SOPS uses the **age** encryption library which natively supports SSH keys
2. SSH keys are automatically found in `~/.ssh/`
3. Multiple SSH public keys can be specified (team members)
4. Any corresponding private key can decrypt
5. Encrypted files are safe to commit to Git

---

## Key Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Repository                           │
│                                                              │
│  .sops.yaml                     .env.enc                    │
│  ┌──────────────────┐          ┌──────────────────┐        │
│  │ age:             │          │ data:            │        │
│  │  - ssh-ed25519   │  ──────> │  ENC[AES256...] │        │
│  │    Alice...      │          │  ENC[AES256...] │        │
│  │  - ssh-ed25519   │          └──────────────────┘        │
│  │    Bob...        │                                       │
│  │  - ssh-rsa       │          github-app-key.pem.enc      │
│  │    CI...         │          ┌──────────────────┐        │
│  └──────────────────┘          │  ENC[BINARY...] │        │
│                                └──────────────────┘        │
└─────────────────────────────────────────────────────────────┘
                               │
                               │ Can decrypt with ANY of:
                               ▼
     ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
     │ Alice's      │  │ Bob's        │  │ CI/CD        │
     │ SSH Key      │  │ SSH Key      │  │ SSH Key      │
     │ (~/.ssh/)    │  │ (~/.ssh/)    │  │ (GitHub)     │
     └──────────────┘  └──────────────┘  └──────────────┘
```

---

## SSH Key Usage

### Personal SSH Keys
- **Location**: `~/.ssh/id_ed25519` or `~/.ssh/id_rsa`
- **Purpose**: Individual developer access
- **Usage**: Encrypt/decrypt during local development
- **Security**: Private key never shared, public key in .sops.yaml

### CI/CD SSH Keys
- **Location**: GitHub Secrets, GitLab Variables
- **Purpose**: Automated decryption in pipelines
- **Usage**: Deploy secrets, validate encryption
- **Security**: Restricted access, rotated regularly

### Why SSH Keys?
- **Already exist** - Developers already have SSH keys for Git
- **Automatically found** - SOPS finds them in `~/.ssh/`
- **No extra setup** - No need to generate age keys
- **Secure** - Same security as Git authentication

---

## File Structure

### app-portal Repository
```
app-portal/
├── .sops.yaml                    # SSH public keys configuration
├── .env.enc                      # Encrypted environment variables
├── github-app-key.pem.enc        # Encrypted GitHub App private key
├── .envrc                        # direnv auto-decryption
└── .gitignore                    # Excludes plaintext secrets
```


---

## Common Operations

### Creating a New Secret

#### Environment Variables (.env)
```bash
# Create plaintext .env
cat > .env << 'EOF'
AUTH_GITHUB_CLIENT_ID=Iv1.xxxxx
AUTH_GITHUB_CLIENT_SECRET=xxxxx
DATABASE_URL=postgresql://user:pass@localhost/db
EOF

# Encrypt it (SSH keys automatically found)
sops -e --input-type dotenv --output-type dotenv .env > .env.enc

# Remove plaintext
rm .env
```

#### Binary Files (certificates, keys)
```bash
# Encrypt a private key or certificate
sops -e --input-type binary --output-type binary github-app-key.pem > github-app-key.pem.enc

# Remove plaintext
rm github-app-key.pem
```

#### Kubernetes Secrets
```bash
cat > secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
  namespace: backstage
stringData:
  key: value
EOF

# Encrypt it
sops -e secret.yaml > secret.enc.yaml

# Clean up
rm secret.yaml
```

### Editing Existing Secrets

```bash
# Method 1: Direct edit (opens in $EDITOR)
sops .env.enc
EDITOR=vim sops github-app-key.pem.enc

# Method 2: Decrypt, edit, re-encrypt
sops -d --input-type dotenv --output-type dotenv .env.enc > .env
vim .env
sops -e --input-type dotenv --output-type dotenv .env > .env.enc
rm .env
```

### Viewing Secrets

```bash
# View decrypted .env file
sops -d --input-type dotenv --output-type dotenv .env.enc

# View decrypted binary file
sops -d --input-type binary --output-type binary github-app-key.pem.enc

# View specific value from YAML
sops -d --extract '["data"]["AUTH_GITHUB_CLIENT_ID"]' secret.enc.yaml
```

### Rotating Secrets

```bash
# 1. Decrypt and update values
sops -d --input-type dotenv --output-type dotenv .env.enc > .env
vim .env  # Update passwords, tokens, etc.

# 2. Re-encrypt with same recipients
sops -e --input-type dotenv --output-type dotenv .env > .env.enc
rm .env

# 3. Commit and push
git add .env.enc
git commit -m "Rotate GitHub App credentials"
git push

# 4. Restart application or re-run direnv
direnv reload
```

---

## Team Workflows

### Adding a Team Member

```mermaid
graph LR
    A[New Member] -->|1. Share SSH key| B[Public SSH Key]
    B -->|2. Send to team lead| C[Team Lead]
    C -->|3. Add to .sops.yaml| D[Repository]
    C -->|4. Run updatekeys| E[Re-encrypt secrets]
    E -->|5. Push changes| F[Team can decrypt]
```

1. **New member shares SSH public key**:
   ```bash
   # Get SSH public key
   cat ~/.ssh/id_ed25519.pub  # or id_rsa.pub
   # Send output to team lead
   ```

2. **Team lead updates .sops.yaml**:
   ```yaml
   creation_rules:
     - path_regex: \.env$
       age: >-
         ssh-ed25519 EXISTING_KEY,
         ssh-ed25519 NEW_MEMBER_KEY  # New member
   ```

3. **Team lead updates all encrypted files**:
   ```bash
   cd app-portal
   sops updatekeys .env.enc
   sops updatekeys github-app-key.pem.enc
   ```

4. **Commit and push**:
   ```bash
   git add .sops.yaml .env.enc github-app-key.pem.enc
   git commit -m "Add [Name]'s SSH key to SOPS"
   git push
   ```

### Removing a Team Member

1. **Remove their SSH public key from .sops.yaml**
2. **IMPORTANT: Rotate all secret values** (not just re-encrypt!)
   ```bash
   # Decrypt
   sops -d --input-type dotenv --output-type dotenv .env.enc > .env
   
   # Update actual values (passwords, tokens, etc.)
   vim .env
   
   # Re-encrypt with remaining team members only
   sops -e --input-type dotenv --output-type dotenv .env > .env.enc
   rm .env
   ```
3. **Update all encrypted files**:
   ```bash
   sops updatekeys .env.enc
   sops updatekeys github-app-key.pem.enc
   ```
4. **Commit and deploy**:
   ```bash
   git add .sops.yaml .env.enc github-app-key.pem.enc
   git commit -m "Remove [Name] and rotate secrets"
   git push
   ```

---

## Environment-Specific Secrets

### Different Keys per Environment

You can configure different SSH keys for different environments or file patterns:

```yaml
# .sops.yaml
creation_rules:
  # Development secrets - all developers
  - path_regex: .*\.dev\.enc$
    age: ssh-ed25519 AAAA...,ssh-ed25519 BBBB...
  
  # Production secrets - ops team only  
  - path_regex: .*\.prod\.enc$
    age: ssh-ed25519 CCCC...,ssh-ed25519 DDDD...
  
  # Default - everyone
  - age: ssh-ed25519 AAAA...,ssh-ed25519 BBBB...,ssh-ed25519 CCCC...
```

---

## CI/CD Integration

### GitHub Actions

#### Using SSH Key
```yaml
- name: Setup SOPS with SSH
  env:
    SSH_PRIVATE_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
  run: |
    # Setup SSH key
    mkdir -p ~/.ssh
    echo "$SSH_PRIVATE_KEY" > ~/.ssh/id_ed25519
    chmod 600 ~/.ssh/id_ed25519
    
    # Decrypt secrets (SSH key automatically found)
    sops -d --input-type dotenv --output-type dotenv .env.enc > .env
    sops -d --input-type binary --output-type binary github-app-key.pem.enc > github-app-key.pem
    
    # Clean up
    rm -rf ~/.ssh
```

#### Using Age Key (Alternative)
```yaml
- name: Setup SOPS with Age
  env:
    SOPS_AGE_KEY: ${{ secrets.SOPS_AGE_KEY }}
  run: |
    # Decrypt secrets
    sops -d --input-type dotenv --output-type dotenv .env.enc > .env
    sops -d --input-type binary --output-type binary github-app-key.pem.enc > github-app-key.pem
```

### GitLab CI
```yaml
decrypt-secrets:
  before_script:
    # Setup SSH key
    - mkdir -p ~/.ssh
    - echo "$CI_SSH_PRIVATE_KEY" > ~/.ssh/id_ed25519
    - chmod 600 ~/.ssh/id_ed25519
  script:
    # Decrypt and use secrets
    - sops -d --input-type dotenv --output-type dotenv .env.enc > .env
    - source .env
    - deploy.sh
  after_script:
    - rm -rf ~/.ssh
```

---

## Security Best Practices

### DO's ✅
- Generate unique keys per person
- Store project keys in secure vaults
- Rotate secrets when team members leave
- Use different keys for different environments
- Audit .sops.yaml changes in PR reviews
- Keep private keys secure and never commit them

### DON'Ts ❌
- Never commit unencrypted secrets
- Never share private keys via insecure channels
- Don't use the same key for local and production
- Don't forget to remove departed members' keys
- Never store keys in the repository

---

## Troubleshooting

### "Cannot decrypt" Error

#### Check SSH Key
```bash
# Verify SSH key exists
ls -la ~/.ssh/id_ed25519  # or id_rsa

# Check if your SSH key is in .sops.yaml
cat .sops.yaml | grep "$(cat ~/.ssh/id_ed25519.pub | cut -d' ' -f1-2)"

# Test decryption
sops -d --input-type dotenv --output-type dotenv .env.enc

# If using non-standard SSH key location
SSH_AUTH_SOCK= SSH_AGENT_PID= sops -d .env.enc
```

#### SSH Agent Issues
```bash
# Check if SSH agent is interfering
ssh-add -l

# Try without SSH agent
SSH_AUTH_SOCK= sops -d .env.enc

# Or add your key to agent
ssh-add ~/.ssh/id_ed25519
```

### "No matching keys" Error
```bash
# Your SSH key isn't in .sops.yaml
# Ask team lead to:
1. Add your SSH public key to .sops.yaml
2. Run: sops updatekeys .env.enc
```

### Format Detection Issues
```bash
# Always specify format for .env files
sops -e --input-type dotenv --output-type dotenv .env > .env.enc

# For binary files
sops -e --input-type binary --output-type binary key.pem > key.pem.enc

# Wrong (SOPS might misinterpret format):
sops -e .env > .env.enc
```

### direnv Not Loading Secrets
```bash
# Check if direnv is allowed
direnv status

# Re-allow if needed
direnv allow

# Check .envrc for errors
cat .envrc

# Test manually
source .envrc
```

### Corrupted Encrypted File
```bash
# Restore from Git
git checkout -- .env.enc
git checkout -- github-app-key.pem.enc

# If you need the latest changes
# Ask team member to decrypt and share securely
# Then re-encrypt with team keys
```

---

## Advanced Topics

### Multiple Key Files
```bash
# Personal key (default)
~/.config/sops/age/keys.txt

# Project keys
~/.config/sops/age/project-prod.txt
~/.config/sops/age/project-dev.txt

# Switch between keys
export SOPS_AGE_KEY_FILE=~/.config/sops/age/project-prod.txt
sops -d secret.enc.yaml
```

### Key Rotation
```bash
# 1. Generate new key
age-keygen -o new-key.txt

# 2. Add new key to .sops.yaml
# 3. Remove old key from .sops.yaml
# 4. Update all secrets
find . -name "*.enc.yaml" -exec sops updatekeys {} \;

# 5. Update cluster secret
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=new-key.txt \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Audit Trail
```bash
# See who can decrypt (public keys in .sops.yaml)
cat deploy-backstage/.sops.yaml

# See when secrets were last modified
git log --oneline -- "*.enc.yaml"

# See who modified secrets
git blame app-portal/.env.enc
```

---

## Quick Reference

### Essential Commands

| Command | Purpose |
|---------|---------|
| `cat ~/.ssh/id_ed25519.pub` | Get your SSH public key |
| `sops -e --input-type dotenv --output-type dotenv .env > .env.enc` | Encrypt .env file |
| `sops -d --input-type dotenv --output-type dotenv .env.enc` | Decrypt .env file |
| `sops -e --input-type binary --output-type binary key.pem > key.pem.enc` | Encrypt binary |
| `sops -d --input-type binary --output-type binary key.pem.enc > key.pem` | Decrypt binary |
| `sops .env.enc` | Edit encrypted file |
| `sops updatekeys .env.enc` | Update after .sops.yaml change |
| `direnv allow` | Enable auto-decryption |

### File Types

| File | Purpose | Commit to Git? |
|------|---------|----------------|
| `.sops.yaml` | SSH public keys config | ✅ Yes |
| `.env.enc` | Encrypted secrets | ✅ Yes |
| `*.pem.enc` | Encrypted keys/certs | ✅ Yes |
| `.envrc` | direnv config | ✅ Yes |
| `.env` | Plaintext secrets | ❌ No |
| `*.pem` | Plaintext keys | ❌ No |

---

## Installation

```bash
# macOS
brew install sops age direnv

# Linux
curl -LO https://github.com/getsops/sops/releases/latest/download/sops-linux-amd64
sudo mv sops-linux-amd64 /usr/local/bin/sops
sudo chmod +x /usr/local/bin/sops

# Verify
sops --version
age --version
```

## Links and Resources

- [SOPS Documentation](https://github.com/getsops/sops)
- [Age Encryption](https://github.com/FiloSottile/age)
- [Age SSH Support](https://github.com/FiloSottile/age#ssh-keys)
- [direnv Documentation](https://direnv.net/)
- [Flux SOPS Integration](https://fluxcd.io/flux/guides/mozilla-sops/)