# wasm-registry skill scripts

Place auxiliary binaries in this directory when you need pinned versions for the wasm-registry skill.

## Included wrappers

- `run-wkg.sh` — resolves to a local `wkg` binary if present at `.agents/skills/wasm-registry/scripts/wkg`; otherwise falls back to whatever `wkg` is on `PATH`.

## Adding a local wkg binary

Copy or download a `wkg` binary and make it executable:

```bash
cp $(which wkg) .agents/skills/wasm-registry/scripts/wkg
chmod +x .agents/skills/wasm-registry/scripts/wkg
```

You can also download a release from the wasm-pkg-tools project if you need a specific version.

## Credential helpers

`run-wkg.sh` respects the standard `wkg` credential resolution order. To authenticate to GitHub Container Registry (GHCR), either:

1. Store credentials in `~/.docker/config.json` via `docker login ghcr.io`, or
2. Export `WKG_OCI_USERNAME` and `WKG_OCI_PASSWORD` before invoking the wrapper.

The wasm-oci skill will surface these options whenever it needs to push components.
