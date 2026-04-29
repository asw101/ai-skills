# Skill routing — overlap matrix

A task × tool view of where the three overlapping WebAssembly skills
(`component`, `wasm-toolchain`, `wasmtime`) cover the same ground, and
which one to reach for.

The high-level policy is in [`AGENTS.md`](../AGENTS.md). This document
exists for reference when the policy alone is ambiguous.

## Lifecycle tasks

| Task | Default skill | When to override |
| --- | --- | --- |
| `init` a new component project | `component` | — |
| Install a dep / pull a component | `component` (`component install` / `component registry pull`) | `wasm-toolchain` (`wkg oci pull`) when you need to pin a specific digest or bypass the meta-registry |
| Build (single language) | `wasm-build` (or language-specific tool: `cargo build --target wasm32-wasip2`, `npm run build:component`, …) | — |
| Build (multi-component composition) | `component compose` | `wasm-tools compose` / `wac` only when `component compose` lacks a feature |
| Run a component | `component run` | `wasmtime` for `--invoke` (WAVE), AOT `compile`, `wizer`, `objdump` |
| Serve an HTTP component | `component run` (proxies to wasmtime serve) | `wasmtime serve` directly when you need wasmtime-specific flags |
| Push to OCI registry | `component registry push` | `wasm-toolchain` (`wkg oci push --annotation org.opencontainers.image.…`) when you need custom OCI annotations |
| Pull from OCI registry | `component registry pull` | `wasm-toolchain` (`wkg oci pull`) for digest pinning, raw OCI semantics |
| Search a meta-registry | `component registry search` | `wasm-toolchain` curated catalog (`scripts/components.md`) when no meta-registry is reachable |
| Inspect a component (high-level) | `component local inspect` | `wasm-tools component wit` / `wasm-tools print` / `wasm-tools dump` for low-level structure |
| Validate a `.wasm` | `component local validate` | `wasm-tools validate` for verbose / strict mode |

## Authoring tasks

| Task | Default skill | When to override |
| --- | --- | --- |
| Author a Rust component | `wasm-build` | — |
| Author a Python component | `wasm-build` | — |
| Author a JS/TS component | `wasm-build` | — |
| Author a Go (TinyGo) component | `wasm-build` | — |
| Edit a WIT world | `wasm-build` | — |
| Author a WIT *package* (publishable) | `wasm-toolchain` (`wkg wit fetch/build/publish`, `wkg.lock`) | — (no overlap; this is wkg-only) |
| Embed a custom-section component type | `wasm-toolchain` (`wasm-tools component embed`) | — |
| Extract or alter component metadata | `wasm-toolchain` (`wasm-tools metadata add/show`) | — |

## Runtime tasks

| Task | Default skill | When to override |
| --- | --- | --- |
| Run a component CLI | `component run` | `wasmtime` for `--invoke` and inspection |
| Serve HTTP | `component run` | `wasmtime serve` for direct flag access |
| Invoke a single export | `wasmtime` (`wasmtime run --invoke 'fn(args)' …`) | — (no `component` analogue today) |
| AOT compile | `wasmtime compile` → `.cwasm` | — |
| Pre-initialise (snapshot) | `wasmtime wizer` | — |
| Profile / trace | `wasmtime` (`--profile`, `--trace`) | — |

## Tooling tasks

| Task | Default skill | Notes |
| --- | --- | --- |
| Install a toolchain (Rust, Go, Node, uv) | `just` (`bootstrap-*` recipes) | — |
| Install a per-skill binary | `just` (`populate-skills`) | Idempotent |
| Run an isolated guest in a hardware sandbox | `hyperlight-sandbox` | Orthogonal to component work |

## Quick decision tree

```
WebAssembly task?
├─ build source → .wasm                                       → wasm-build
├─ wkg / wasm-tools / OCI annotations / WIT-package authoring → wasm-toolchain
├─ wasmtime --invoke / compile / wizer / objdump / explore    → wasmtime
└─ everything else (init / install / run / push / pull /
   compose / search / inspect)                                → component
```
