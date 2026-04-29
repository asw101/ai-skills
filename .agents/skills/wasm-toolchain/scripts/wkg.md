# `wkg` cookbook

[`wkg`](https://github.com/bytecodealliance/wasm-pkg-tools) is the Bytecode
Alliance package manager for WebAssembly: OCI artifact push/pull, WIT package
authoring, dependency resolution, and lockfile management. Language-agnostic.

This cookbook is the **canonical home for wkg** in the `wasm-toolchain` skill.
The `wasm-build` skill cross-links here from its language-specific cookbooks
when WIT dependencies need fetching.

When to reach for `wkg` instead of `component`:

| Task | Tool |
|---|---|
| Push a component with custom `org.opencontainers.image.*` annotations | `wkg` (component-cli does not yet expose this) |
| Author and publish a raw WIT package (not a built component) | `wkg wit build` + `wkg publish` |
| Resolve WIT dependencies during a language build | `wkg wit fetch` (writes `wkg.lock`) |
| Pull a known OCI ref (no meta-registry) | `wkg oci pull` (or `component registry pull` if a meta-registry is configured) |
| Push to GHCR with a fine-grained PAT | `wkg oci push` |

For component-lifecycle ops (search, install, run, compose) prefer the
`component-cli` skill.

---

## Binary resolution

The `wasm-toolchain` skill prefers a pinned `wkg` binary at
`.agents/skills/wasm-toolchain/scripts/wkg` (installed via
`just install-wkg .agents/skills/wasm-toolchain/scripts`). If absent,
falls back to system `wkg`.

```bash
SKILL_DIR=".agents/skills/wasm-toolchain"
WKG="$SKILL_DIR/scripts/wkg"
[ -x "$WKG" ] || WKG="wkg"
```

---

## Authentication for OCI registries

`wkg` reuses Docker credential helpers, **and** honours
`WKG_OCI_USERNAME` / `WKG_OCI_PASSWORD` env vars per session.

### GHCR (GitHub Container Registry)

1. Create a fine-grained PAT with `read:packages` and `write:packages` scopes
   (or a classic PAT with the same).
2. Authenticate via either method:

   **Docker login** (persisted in `~/.docker/config.json`):
   ```bash
   echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin
   ```

   **Environment variables** (per-session):
   ```bash
   export WKG_OCI_USERNAME="<github-username>"
   export WKG_OCI_PASSWORD="<github-token>"
   ```

3. Or pass `-u`/`-p` directly on the command line (least preferred — leaks
   into shell history).

### Other registries

`wkg` supports any OCI v1.1 registry: AWS ECR, Azure ACR, Docker Hub, Google
Artifact Registry. Authentication mechanism follows the registry — usually
`docker login <registry-host>` is sufficient.

---

## Configuration

`wkg` reads `~/.config/wasm-pkg/config.toml`:

```toml
default_registry = "ghcr.io"

[namespace_registries]
wasi = "ghcr.io"
local = "ghcr.io"

[registry."ghcr.io"]
type = "oci"
```

For private registries, set credentials via `docker login` — `wkg` will reuse
them via Docker credential helpers.

---

## Push a component to OCI

```bash
$WKG oci push ghcr.io/<owner>/<name>:<tag> path/to/component.wasm \
    --annotation org.opencontainers.image.source="https://github.com/<owner>/<repo>" \
    --annotation org.opencontainers.image.description="Short summary" \
    --annotation org.opencontainers.image.licenses="Apache-2.0" \
    --annotation org.opencontainers.image.authors="Your Name <you@example.com>"
```

Recommended annotations:

| Annotation | Purpose |
|---|---|
| `org.opencontainers.image.source` | Link to source repository — drives the GHCR "linked repository" UI |
| `org.opencontainers.image.description` | Short summary shown on the package page |
| `org.opencontainers.image.licenses` | SPDX license identifier (e.g., `Apache-2.0`, `MIT`) |
| `org.opencontainers.image.authors` | Maintainer(s) |
| `org.opencontainers.image.version` | Component version (often the same as the OCI tag) |

GHCR packages default to **private**. Visibility is changed via the GitHub
package settings UI, not via OCI metadata.

---

## Pull a component from OCI

```bash
$WKG oci pull ghcr.io/<owner>/<name>:<tag> -o components/<name>.wasm
```

Notes:
- Do **not** include `oci://` prefix — `wkg` parses bare references.
- The output file is a single `.wasm` artifact.
- For curated, well-known references see
  [`components.md`](./components.md) (offline catalog).

After pulling, inspect with `wasm-tools` (see
[`wasm-tools.md`](./wasm-tools.md)):
```bash
wasm-tools validate components/<name>.wasm
wasm-tools component wit components/<name>.wasm
```

---

## WIT-package authoring (`wkg wit build` / `wkg publish`)

Unlike OCI artifact push/pull, this flow publishes raw **WIT packages** —
interface definitions, not built components.

```bash
# Resolve and download WIT dependencies (creates wkg.lock)
$WKG wit fetch

# Build a WIT package archive from your wit/ directory
$WKG wit build -o my-package.wasm

# Inspect dependency graph
$WKG wit deps graph wit/world.wit

# Publish a built package (raw WIT, not a component)
$WKG publish ghcr.io/<owner>/<package>:<tag>

# Pull a published package back
$WKG pull ghcr.io/<owner>/<package>:<tag>
```

### Using registry deps in your WIT

```wit
package local:my-component;

use wasi:http/types@0.2.0.{request, response};

world my-component {
  import wasi:http/outgoing-handler@0.2.0;
  export process: func(req: request) -> response;
}
```

`wkg wit fetch` resolves these. Fetched packages land in `wit/deps/`; version
pins are written to `wkg.lock`.

### `wkg.lock`

```toml
version = 1

[[package]]
name = "wasi:http"
version = "0.2.0"
digest = "sha256:..."
```

Commit `wkg.lock` for reproducible builds. It is cross-language: Rust,
Python, JS, and Go components in the same project share one lockfile.

---

## Common reference formats

```
ghcr.io/<owner>/<name>:<tag>             # GHCR (most common for awesome-wasm-components / wassette)
docker.io/<owner>/<name>:<tag>           # Docker Hub
<registry-host>/<namespace>/<name>:<tag> # generic OCI v1.1
```

---

## Troubleshooting

- **`registry auth failed`** → run `docker login <registry>`; or configure
  credentials in `~/.config/wasm-pkg/config.toml`. For GHCR, verify the PAT
  has `write:packages` scope for pushes.
- **`could not resolve package …`** → check `default_registry` and any
  `namespace_registries` entries; verify the package exists on that registry.
- **`push rejected — unauthorized`** → reference must follow
  `<registry>/<owner>/<name>:<tag>` format; verify write access to the
  namespace; if updating an existing package, confirm permission to update.
- **Stale fetches** → delete `wit/deps/` and `wkg.lock`, then `wkg wit fetch`.
- **Digest mismatches on push** → update `wkg` (`cargo install --locked
  wkg`); check for upload-layer network errors and retry.
- **GHCR package shows as private** → expected default. Change visibility in
  the GitHub Packages UI; OCI metadata cannot set this.
