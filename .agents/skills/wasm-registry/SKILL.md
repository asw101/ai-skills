---
name: wasm-registry
description: Use this skill when publishing, pulling, or managing WebAssembly components in OCI registries like GitHub Container Registry (GHCR). Helps with wkg commands, authentication, and registry operations.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# wasm-registry skill

You specialize in publishing and managing WebAssembly components in OCI registries using `wkg` (WebAssembly package manager).

## Key responsibilities
- Authenticate with OCI registries (GHCR, Docker Hub, etc.)
- Push components to registries with proper annotations
- Pull components from registries
- Manage component metadata and tags
- Troubleshoot registry authentication and access issues

## Tooling
- Use `.agents/skills/wasm-registry/scripts/run-wkg.sh` to invoke `wkg`. The wrapper prefers a pinned binary at `.agents/skills/wasm-registry/scripts/wkg` and falls back to the system installation.

## Publishing to GHCR with wkg

### 1. Obtain credentials
- Create a GitHub fine-grained personal access token with `read:packages` and `write:packages` scopes.
- Store credentials in Docker config (`docker login ghcr.io`) or export them per-session:
  ```bash
  export WKG_OCI_USERNAME="<github-username>"
  export WKG_OCI_PASSWORD="<github-token>"
  ```

### 2. Push a component
```bash
./scripts/run-wkg.sh oci push ghcr.io/<github-username>/<component-name>:<tag> components/component-name.wasm \
  --annotation org.opencontainers.image.source="https://github.com/<repo>" \
  --annotation org.opencontainers.image.description="Short summary"
```

Add `-u` and `-p` flags only when you prefer to pass credentials explicitly; otherwise rely on environment variables or Docker config.

### 3. Verify the push
```bash
# Pull the artifact back
./scripts/run-wkg.sh oci pull ghcr.io/<owner>/<name>:<tag> -o /tmp/component.wasm

# Optionally check GitHub Packages UI for visibility
```

## Pulling components from registries

### Pull a component
```bash
./.agents/skills/wasm-registry/scripts/run-wkg.sh oci pull ghcr.io/microsoft/time-server-js:latest -o components/time-server.wasm
```

**Note:** Do NOT include `oci://` prefix in the reference when using wkg.

### Inspect the pulled component
```bash
wasm-tools component wit components/time-server.wasm
```

## OCI annotations
Recommended annotations for published components:
- `org.opencontainers.image.source` - Link to source repository
- `org.opencontainers.image.description` - Short description of the component
- `org.opencontainers.image.licenses` - License identifier (e.g., MIT, Apache-2.0)
- `org.opencontainers.image.authors` - Author or maintainer

## Registry reference format
- **GHCR**: `ghcr.io/<owner>/<name>:<tag>`
- **Docker Hub**: `docker.io/<owner>/<name>:<tag>`
- **Generic OCI**: `<registry-host>/<namespace>/<name>:<tag>`

## Common troubleshooting

### Authentication failures
- Ensure the PAT has `write:packages` scope for pushes
- Check that `WKG_OCI_USERNAME` and `WKG_OCI_PASSWORD` are set correctly
- Try `docker login ghcr.io` as an alternative authentication method

### Push rejections
- Ensure the reference follows `<registry>/<owner>/<name>:<tag>` format
- Verify you have write access to the namespace
- Check if the package already exists and you have permission to update it

### Digest mismatches
- Update `wkg` to the latest version
- Check for network issues during upload

### Visibility issues
- GHCR packages default to private; change visibility in GitHub Package settings
- Ensure the package is linked to a repository for better discoverability

When invoked, help users authenticate with registries and push/pull WebAssembly components using wkg.
