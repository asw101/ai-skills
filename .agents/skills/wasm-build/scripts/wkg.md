# WIT package management with `wkg`

`wkg` (wasm-pkg-tools) resolves WIT dependencies from OCI registries and builds/publishes WIT packages. It is language-agnostic.

## Install

```bash
cargo install wkg@0.15.0
# or download a release binary from
# https://github.com/bytecodealliance/wasm-pkg-tools/releases
```

## Configure

`~/.config/wasm-pkg/config.toml`:

```toml
default_registry = "ghcr.io"

[namespace_registries]
wasi = "ghcr.io"
local = "ghcr.io"

[registry."ghcr.io"]
type = "oci"
```

For private registries, set credentials via Docker login (`docker login ghcr.io`) — `wkg` reuses Docker credential helpers.

## Common commands

```bash
# Resolve and download WIT dependencies (creates wkg.lock)
wkg wit fetch

# Build a WIT package archive from your wit/ directory
wkg wit build -o my-package.wasm

# Inspect dependency graph
wkg wit deps graph wit/world.wit

# Publish a built component
wkg publish ghcr.io/my-org/my-component:0.1.0

# Pull a published component
wkg pull ghcr.io/my-org/my-component:0.1.0
```

## Using registry deps in your WIT

```wit
package local:my-component;

use wasi:http/types@0.2.0.{request, response};

world my-component {
  import wasi:http/outgoing-handler@0.2.0;
  export process: func(req: request) -> response;
}
```

Then run `wkg wit fetch`. The fetched packages land in `wit/deps/` and version pins are written to `wkg.lock`.

## `wkg.lock`

```toml
version = 1

[[package]]
name = "wasi:http"
version = "0.2.0"
digest = "sha256:..."
```

Commit `wkg.lock` for reproducible builds. It is cross-language — Rust, Python, JS, and Go components in the same project share one lockfile.

## Troubleshooting

- **`registry auth failed`** → run `docker login <registry>` and re-try; or configure credentials in `~/.config/wasm-pkg/config.toml`.
- **`could not resolve package …`** → check `default_registry` and any `namespace_registries` entries; verify the package exists on that registry.
- **Stale fetches** → delete `wit/deps/` and `wkg.lock`, then `wkg wit fetch`.
