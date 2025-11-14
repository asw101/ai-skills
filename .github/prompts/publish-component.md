# Publish Component to Registry

This prompt template guides you through publishing a WebAssembly component to GitHub Container Registry (GHCR).

## Prerequisites Checklist

- [ ] Component built and validated
- [ ] GitHub account with repository
- [ ] Personal Access Token (PAT) with `write:packages` and `read:packages` scopes
- [ ] wkg installed
- [ ] Component tested with wasmtime

---

## Step 1: Prepare Component

### Validate Component

```bash
# Ensure component is valid
wasm-tools validate components/[component-name].wasm

# Verify interface
wasm-tools component wit components/[component-name].wasm

# Test execution
wasmtime run components/[component-name].wasm
```

**Validation status**: [PASS/FAIL]

### Check Component Size

```bash
ls -lh components/[component-name].wasm
```

**Size**: [SIZE]
**Acceptable**: [YES/NO]

### Optimize (Optional)

```bash
# Optimize with wasm-opt
wasm-opt -Os components/[component-name].wasm -o components/[component-name].opt.wasm
mv components/[component-name].opt.wasm components/[component-name].wasm

# Verify still works
wasmtime run components/[component-name].wasm
```

**Optimized**: [YES/NO]
**New size**: [SIZE]

---

## Step 2: Create GitHub Personal Access Token

If you don't have a token:

1. Go to https://github.com/settings/tokens
2. Click "Generate new token" → "Generate new token (classic)"
3. Set note: "WASM Component Publishing"
4. Select scopes:
   - ✅ `write:packages` (Upload packages to GitHub Package Registry)
   - ✅ `read:packages` (Download packages from GitHub Package Registry)
   - ✅ `delete:packages` (Delete packages from GitHub Package Registry)
5. Click "Generate token"
6. **Save token securely** (you won't see it again)

**Token created**: [YES/NO]

---

## Step 3: Authenticate

### Method 1: Docker Config (Persistent)

```bash
# Replace USERNAME and TOKEN
echo YOUR_GITHUB_TOKEN | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
```

**Authenticated**: [YES/NO]

### Method 2: Environment Variables (Session)

```bash
# Add to ~/.bashrc or ~/.zshrc for persistence
export WKG_OCI_USERNAME="your-github-username"
export WKG_OCI_PASSWORD="ghp_your_token_here"

# Or for current session only
export WKG_OCI_USERNAME="[username]"
export WKG_OCI_PASSWORD="[token]"
```

**Authenticated**: [YES/NO]

---

## Step 4: Choose Version Tag

Follow semantic versioning: `MAJOR.MINOR.PATCH`

**Examples**:
- Initial release: `v1.0.0`
- New features: `v1.1.0`
- Bug fixes: `v1.0.1`
- Breaking changes: `v2.0.0`

**Additional tags**:
- `latest` - Stable release
- `main` - Development branch
- `sha-abc123` - Specific commit

**Your version**: [VERSION]

---

## Step 5: Prepare Annotations

Annotations provide metadata for discoverability:

```bash
# Required/recommended annotations
--annotation org.opencontainers.image.source="[REPO_URL]"
--annotation org.opencontainers.image.description="[SHORT_DESCRIPTION]"
--annotation org.opencontainers.image.licenses="[LICENSE]"
--annotation org.opencontainers.image.version="[VERSION]"

# Optional but useful
--annotation org.opencontainers.image.authors="[YOUR_NAME]"
--annotation org.opencontainers.image.documentation="[DOCS_URL]"
--annotation org.opencontainers.image.created="[ISO_DATE]"
```

**Your annotations**:
- Source: [REPO_URL]
- Description: [DESCRIPTION]
- License: [LICENSE]
- Version: [VERSION]

---

## Step 6: Publish Component

### Basic Publish

```bash
wkg oci push ghcr.io/[username]/[component-name]:[tag] components/[component-name].wasm
```

### With Full Annotations

```bash
wkg oci push ghcr.io/[username]/[component-name]:[version] components/[component-name].wasm \
  --annotation org.opencontainers.image.source="https://github.com/[username]/[repo]" \
  --annotation org.opencontainers.image.description="[Brief description]" \
  --annotation org.opencontainers.image.licenses="[LICENSE]" \
  --annotation org.opencontainers.image.version="[version]" \
  --annotation org.opencontainers.image.authors="[Your Name]"
```

**Publish command**:
```bash
[YOUR_COMMAND]
```

**Result**: [SUCCESS/FAIL]
**Error (if any)**: [ERROR_MESSAGE]

---

## Step 7: Tag as Latest

If this is a stable release:

```bash
# Tag the same component as 'latest'
wkg oci push ghcr.io/[username]/[component-name]:latest components/[component-name].wasm \
  --annotation org.opencontainers.image.source="https://github.com/[username]/[repo]" \
  --annotation org.opencontainers.image.description="[description]" \
  --annotation org.opencontainers.image.licenses="[LICENSE]" \
  --annotation org.opencontainers.image.version="[version]"
```

**Tagged as latest**: [YES/NO]

---

## Step 8: Verify Publication

### List Available Versions

```bash
wkg oci list ghcr.io/[username]/[component-name]
```

**Available tags**:
```
[TAG_LIST]
```

### Pull and Test

```bash
# Pull the published component
wkg oci pull ghcr.io/[username]/[component-name]:[tag] -o test-[component-name].wasm

# Verify it works
wasm-tools validate test-[component-name].wasm
wasmtime run test-[component-name].wasm

# Compare with original
diff components/[component-name].wasm test-[component-name].wasm
```

**Pull successful**: [YES/NO]
**Validation passed**: [YES/NO]
**Matches original**: [YES/NO]

---

## Step 9: Set Package Visibility

### Make Public (Recommended for Open Source)

1. Go to: `https://github.com/users/[username]/packages/container/[component-name]/settings`
2. Scroll to "Danger Zone"
3. Click "Change visibility"
4. Select "Public"
5. Type package name to confirm
6. Click "I understand, change package visibility"

**Visibility**: [PUBLIC/PRIVATE]

### Make Private

Keep package private if:
- Proprietary code
- Not ready for public use
- Internal tooling only

**Note**: Private packages require authentication to pull.

---

## Step 10: Document Usage

Add to your README.md:

```markdown
## Installation

Pull the component from GitHub Container Registry:

\`\`\`bash
wkg oci pull ghcr.io/[username]/[component-name]:latest -o [component-name].wasm
\`\`\`

## Usage

\`\`\`bash
wasmtime run [component-name].wasm
\`\`\`

## Available Versions

See all versions at: https://github.com/users/[username]/packages/container/[component-name]
```

**README updated**: [YES/NO]

---

## Step 11: Create Policy (Optional)

For Wassette compatibility, create `policy.yaml`:

```yaml
apiVersion: v1
kind: Policy
metadata:
  name: [component-name]
spec:
  # Network access (if needed)
  network:
    allowed:
      - host: api.example.com
        port: 443
  
  # Filesystem access (if needed)
  filesystem:
    allowed:
      - path: /tmp
        access: read-write
      - path: /data
        access: read-only
  
  # Environment variables (if needed)
  environment:
    allowed:
      - API_KEY
      - DATABASE_URL
```

**Policy created**: [YES/NO]
**Policy published**: [YES/NO]

---

## Step 12: Announce Release

### Create GitHub Release

1. Go to: `https://github.com/[username]/[repo]/releases/new`
2. Choose tag: `[version]`
3. Release title: `[component-name] [version]`
4. Description:
   ```markdown
   ## What's New
   - [Feature/fix 1]
   - [Feature/fix 2]
   
   ## Installation
   \`\`\`bash
   wkg oci pull ghcr.io/[username]/[component-name]:[version] -o [component-name].wasm
   \`\`\`
   
   ## Usage
   \`\`\`bash
   wasmtime run [component-name].wasm
   \`\`\`
   ```
5. Attach `components/[component-name].wasm`
6. Click "Publish release"

**GitHub release created**: [YES/NO]

### Update awesome-wasm-components (Optional)

If publicly useful, submit to: https://github.com/yoshuawuyts/awesome-wasm-components

**Submitted**: [YES/NO]

---

## Troubleshooting

### "authentication required"

**Cause**: Token not configured or insufficient scopes

**Solution**:
```bash
# Check token scopes at https://github.com/settings/tokens
# Ensure write:packages and read:packages are checked
# Re-authenticate with correct token
```

### "unauthorized: access denied"

**Cause**: Wrong username or package name doesn't match repository

**Solution**:
```bash
# Verify username
echo $WKG_OCI_USERNAME

# Check package URL format
# Correct: ghcr.io/username/package:tag
# Incorrect: ghcr.io/username/repo/package:tag
```

### "manifest invalid"

**Cause**: Not pushing a valid WASM component

**Solution**:
```bash
# Validate component first
wasm-tools validate components/[component-name].wasm

# Ensure file is a component, not a module
wasm-tools component wit components/[component-name].wasm
```

### "reference not found" when pulling

**Cause**: Typo in URL, tag doesn't exist, or private package without auth

**Solution**:
```bash
# List available tags
wkg oci list ghcr.io/[username]/[component-name]

# Verify URL format (no oci:// prefix for wkg)
# Check package visibility settings
```

---

## Automation

### GitHub Actions Workflow

Create `.github/workflows/publish.yml`:

```yaml
name: Publish Components

on:
  release:
    types: [published]

jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      packages: write
      contents: read
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Install wkg
        run: |
          curl -L https://github.com/bytecodealliance/wasm-pkg-tools/releases/latest/download/wkg-x86_64-unknown-linux-gnu -o wkg
          chmod +x wkg
          sudo mv wkg /usr/local/bin/
      
      - name: Build components
        run: |
          # Your build commands
          
      - name: Login to GHCR
        run: |
          echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io -u ${{ github.actor }} --password-stdin
      
      - name: Publish components
        env:
          GITHUB_USER: ${{ github.repository_owner }}
          GITHUB_REPO: ${{ github.repository }}
          VERSION: ${{ github.ref_name }}
        run: |
          for wasm in components/*.wasm; do
            name=$(basename "$wasm" .wasm)
            wkg oci push ghcr.io/${GITHUB_USER}/${name}:${VERSION} "$wasm" \
              --annotation org.opencontainers.image.source="https://github.com/${GITHUB_REPO}" \
              --annotation org.opencontainers.image.version="${VERSION}"
          done
```

**Automation setup**: [YES/NO]

---

## Publication Summary

**Component**: [COMPONENT_NAME]
**Version**: [VERSION]
**Registry URL**: `ghcr.io/[username]/[component-name]:[tag]`
**Visibility**: [PUBLIC/PRIVATE]
**Size**: [SIZE]
**Published date**: [DATE]

**Installation command**:
```bash
wkg oci pull ghcr.io/[username]/[component-name]:[tag] -o [component-name].wasm
```

**GitHub release**: [URL]

---

## Next Steps

- [ ] Test pull from registry on different machine
- [ ] Update documentation with registry URL
- [ ] Monitor download statistics
- [ ] Plan next version features
- [ ] Consider submitting to awesome-wasm-components
- [ ] Set up automated publishing workflow

**Completion status**: ✅ Component successfully published
