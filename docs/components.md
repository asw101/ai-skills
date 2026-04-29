# Components in this repo

Index for the example components in [`../components/`](../components/) and
a quick troubleshooting table. Anything not in those two places lives in
the canonical source — either a skill cookbook or upstream docs.

## Components catalog

The list of built components, sizes, and per-component docs lives in
[`../components/README.md`](../components/README.md). Each component
also has its own `README.md`.

## Build / test / publish

Don't duplicate cookbooks here — go straight to the canonical source:

| Task | Skill | Cookbook |
| --- | --- | --- |
| Build a Rust / Go / Python / JS component | `wasm-build` | [`scripts/{rust,go,python,javascript}.md`](../.agents/skills/wasm-build/scripts/) |
| WASI 0.3 / async features | `wasm-build` | [`scripts/wasi-0.3.md`](../.agents/skills/wasm-build/scripts/wasi-0.3.md) |
| Size optimization | `wasm-build` | [`scripts/optimization.md`](../.agents/skills/wasm-build/scripts/optimization.md) |
| Compose multi-component apps | `wasm-build` | [`scripts/composition.md`](../.agents/skills/wasm-build/scripts/composition.md) |
| Validate / inspect a `.wasm` | `wasm-toolchain` | [`scripts/wasm-tools.md`](../.agents/skills/wasm-toolchain/scripts/wasm-tools.md) |
| Run / `--invoke` a component | `wasmtime` | [`SKILL.md`](../.agents/skills/wasmtime/SKILL.md) |
| Publish to GHCR / OCI registry | `wasm-toolchain` | [`scripts/wkg.md`](../.agents/skills/wasm-toolchain/scripts/wkg.md), or `component registry push` |

## WASI

Components target either **WASI Preview 2** (`0.2.x` worlds, stable) or
**WASI Preview 3** (`0.3.x` worlds, adds `stream<>`, `future<>`, native
async). For canonical interface definitions and proposal status, go
upstream — don't read about WASI here:

- [wasi.dev](https://wasi.dev/) — overview and links to all proposals.
- [WebAssembly/WASI](https://github.com/WebAssembly/WASI) — umbrella repo.
- Per-interface repos under `github.com/WebAssembly/`:
  [`wasi-cli`](https://github.com/WebAssembly/wasi-cli),
  [`wasi-http`](https://github.com/WebAssembly/wasi-http),
  [`wasi-clocks`](https://github.com/WebAssembly/wasi-clocks),
  [`wasi-filesystem`](https://github.com/WebAssembly/wasi-filesystem),
  [`wasi-io`](https://github.com/WebAssembly/wasi-io),
  [`wasi-random`](https://github.com/WebAssembly/wasi-random),
  [`wasi-sockets`](https://github.com/WebAssembly/wasi-sockets),
  [`wasi-keyvalue`](https://github.com/WebAssembly/wasi-keyvalue), …
- WASI 0.3 specifics in this repo (toolchain pins, runtime flags,
  current RC pin): [`wasm-build/scripts/wasi-0.3.md`](../.agents/skills/wasm-build/scripts/wasi-0.3.md).

## Troubleshooting

| Issue | Solution |
| --- | --- |
| Missing Rust target | `just install-rust-tools` (or `rustup target add wasm32-wasip2`) |
| `cargo-component` not found | `just install-rust-tools` |
| Python import errors | Run `componentize-py bindings .` after WIT changes |
| `jco` not found | `just install-js-tools` |
| `jco` fails with `ERR_MODULE_NOT_FOUND` | Node version too old — `just bootstrap-node` (Node 20+) |
| TinyGo not found | `just install-tinygo` |
| `wasm-tools component embed` failed (running TinyGo) | `just install-wasm-tools` (TinyGo's `-target=wasip2` calls `wasm-tools` internally) |
| "unknown import wasi:http" | Update `wasmtime` to v14.0.0+ |
| WASI 0.3 imports unresolved | Use `wasmtime` 43+ with both `-Sp3` and `-Wcomponent-model-async`; pin WIT to `0.3.0-rc-2026-03-15`. See [`wasm-build/scripts/wasi-0.3.md`](../.agents/skills/wasm-build/scripts/wasi-0.3.md). |
