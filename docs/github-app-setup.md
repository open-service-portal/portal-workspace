# GitHub App Setup for Backstage

This guide walks through setting up a GitHub App for Backstage authentication and organization integration.

## Why GitHub App?

GitHub Apps provide several advantages over Personal Access Tokens:
- Higher API rate limits
- Fine-grained permissions
- Act as an application, not a user
- Automatic user and team synchronization from GitHub organizations

## Prerequisites

- Admin access to your GitHub organization
- Backstage application running locally
- Node.js 20 installed

## Step 1: Create GitHub App

### Navigate to GitHub App Creation

Go to: **https://github.com/organizations/YOUR-ORG-NAME/settings/apps/new**

Replace `YOUR-ORG-NAME` with your organization name (e.g., `open-service-portal`)

### Configure Basic Information

- **GitHub App name:** `Your Org Backstage` (e.g., "Open Service Portal Backstage")
- **Description:** `Backstage integration for Your Organization`
- **Homepage URL:** `https://github.com/YOUR-ORG-NAME`

### Configure Authentication

#### Identifying and authorizing users
- **Callback URL:** `http://localhost:7007/api/auth/github/handler/frame?env=development`
- ✅ **Expire user authorization tokens**
- ✅ **Request user authorization (OAuth) during installation**
- ❌ **Enable Device Flow** (not needed)

### Configure Webhook (Optional)

For local development, disable webhooks:
- **Active:** ❌ Unchecked

For production with a public URL:
- **Active:** ✅ Checked
- **Webhook URL:** `https://your-backstage.example.com/api/github/webhook`
- **Webhook secret:** Generate a secure secret

### Configure Permissions

#### Repository permissions:
- **Actions:** Read and write
- **Contents:** Read and write
- **Issues:** Read and write
- **Metadata:** Read (automatically selected)
- **Pull requests:** Read and write

#### Organization permissions:
- **Administration:** Read
- **Members:** Read

#### Account permissions:
- **Email addresses:** Read

### Installation Settings

- 🔘 **Only on this account** (recommended for organization-specific apps)

### Create the App

Click the green **"Create GitHub App"** button.

## Step 2: Configure GitHub App

After creation, you'll be redirected to the app settings page.

### Generate Client Secret

1. In the **"Client secrets"** section
2. Click **"Generate a new client secret"**
3. **Copy the secret immediately** (it's only shown once!)

### Generate Private Key

1. Scroll to **"Private keys"** section
2. Click **"Generate a private key"**
3. A `.pem` file will be downloaded
4. Save it securely (e.g., `github-app-backstage-key.pem`)

### Note Important Values

From the app settings page, note:
- **App ID:** (e.g., `1743793`)
- **Client ID:** (e.g., `Iv23liSg43IqiG8dZQxO`)
- **Client Secret:** (from step above)

### Install the App

1. Click **"Install App"** or go to the **"Public page"**
2. Select your organization
3. Choose **"All repositories"** or select specific repositories
4. Click **"Install"**
5. Note the **Installation ID** from the URL: `.../installations/79711885`

## Step 3: Configure Backstage

### Add Environment Variables

Create or update `.envrc` in your Backstage app:

```bash
# GitHub App Configuration
export AUTH_GITHUB_CLIENT_ID=YOUR_CLIENT_ID
export AUTH_GITHUB_CLIENT_SECRET=YOUR_CLIENT_SECRET
export AUTH_GITHUB_APP_ID=YOUR_APP_ID
export AUTH_GITHUB_APP_PRIVATE_KEY_FILE=/path/to/github-app-key.pem
export AUTH_GITHUB_APP_INSTALLATION_ID=YOUR_INSTALLATION_ID
```

### Update app-config.yaml

Configure GitHub integration:

```yaml
integrations:
  github:
    - host: github.com
      apps:
        - appId: ${AUTH_GITHUB_APP_ID}
          clientId: ${AUTH_GITHUB_CLIENT_ID}
          clientSecret: ${AUTH_GITHUB_CLIENT_SECRET}
          privateKey:
            $file: ${AUTH_GITHUB_APP_PRIVATE_KEY_FILE}

auth:
  environment: development
  providers:
    github:
      development:
        clientId: ${AUTH_GITHUB_CLIENT_ID}
        clientSecret: ${AUTH_GITHUB_CLIENT_SECRET}
        signIn:
          resolvers:
            - resolver: usernameMatchingUserEntityName
```

## Step 4: Enable GitHub Organization Import

### Install the GitHub Org Module

```bash
yarn add @backstage/plugin-catalog-backend-module-github-org
```

### Configure Backend

Add to `packages/backend/src/index.ts`:

```typescript
// GitHub Org Entity Provider - imports users and teams from GitHub
backend.add(import('@backstage/plugin-catalog-backend-module-github-org'));
```

### Configure Catalog

Add to `app-config.yaml`:

```yaml
catalog:
  rules:
    - allow: [Component, System, API, Resource, Location, User, Group]
  providers:
    githubOrg:
      - id: production
        githubUrl: https://github.com
        orgs: ['YOUR-ORG-NAME']
        schedule:
          frequency: { minutes: 30 }
          timeout: { minutes: 3 }
```

## Step 5: Start Backstage

```bash
# Load environment variables (if using direnv)
direnv allow

# Or manually with nvm
nvm use
source .envrc

# Start Backstage
yarn start
```

## Verification

1. Open http://localhost:3000
2. Click "Sign In" and choose GitHub
3. Authorize the GitHub App
4. Check the Software Catalog for automatically imported:
   - User entities (organization members)
   - Group entities (teams)

## Troubleshooting

### Authentication Fails

- Verify all environment variables are set correctly
- Check that the callback URL includes `?env=development`
- Ensure the GitHub App is installed on your organization

### No Users/Groups Imported

- Check the catalog configuration includes `User` and `Group` in rules
- Verify the GitHub App has `Members: Read` permission
- Check logs for any errors from the GitHub Org provider

### NODE_MODULE_VERSION Errors

If you see native module errors after adding the GitHub org module:
```bash
rm -rf node_modules .yarn/unplugged .yarn/install-state.gz
nvm use
yarn install
```

## Security Notes

- Never commit the private key file or secrets to version control
- Use environment variables or secure secret management
- Rotate client secrets regularly
- For production, use proper secret management solutions

## Resources

- [Backstage GitHub Integration](https://backstage.io/docs/integrations/github/)
- [Backstage GitHub Authentication](https://backstage.io/docs/auth/github/provider)
- [GitHub Apps Documentation](https://docs.github.com/en/apps)