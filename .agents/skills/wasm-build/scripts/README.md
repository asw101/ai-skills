# wasm-build cookbooks

Per-topic guides referenced from `../SKILL.md`. Each file is self-contained and linked from the main skill.

| File | Topic |
|---|---|
| [`rust.md`](./rust.md) | Building components in Rust (`cargo-component`, direct `wasm32-wasip2`) |
| [`python.md`](./python.md) | Building components in Python (`componentize-py`) |
| [`javascript.md`](./javascript.md) | Building components in JavaScript / TypeScript (`jco componentize`) |
| [`go.md`](./go.md) | Building components in Go (`tinygo` + `wit-bindgen-go`) |
| [`wkg.md`](./wkg.md) | WIT package management with `wkg` (fetch, build, publish, lockfile) |
| [`composition.md`](./composition.md) | Composing multiple components with `wac` and `wasm-tools compose` |
| [`optimization.md`](./optimization.md) | Size/speed optimization, validation, and inspection |
| [`wasi-0.3.md`](./wasi-0.3.md) | Targeting the WASI 0.3 RC (`-Sp3 -Wcomponent-model-async`, `stream<>`/`future<>`, per-language status) |

## Toolchain version pins

The pins below are referenced by individual cookbooks. Update them in lockstep with the table in `../SKILL.md`.

| Tool | Version | Source |
|---|---|---|
| Rust toolchain | stable (≥ 1.82) | `rustup` |
| `wit-bindgen` (Rust crate) | 0.57.1 | crates.io |
| `cargo-component` | 0.21.1 | crates.io |
| `componentize-py` | 0.23.0 | PyPI |
| `@bytecodealliance/jco` | 1.19.0 | npm |
| `@bytecodealliance/componentize-js` | 0.20.0 | npm |
| TinyGo | 0.41.1 | github.com/tinygo-org/tinygo |
| `go.bytecodealliance.org` (formerly `wasm-tools-go`) | v0.7.0 | github.com/bytecodealliance/go-modules |
| `wasm-tools` | 1.248.0 | github.com/bytecodealliance/wasm-tools |
| `wkg` | 0.15.0 | github.com/bytecodealliance/wasm-pkg-tools |
| `wasmtime` | 44.0.0 | github.com/bytecodealliance/wasmtime |
| `wac` | 0.10.0 | github.com/bytecodealliance/wac |

When updating, prefer the repo-level `Justfile` recipes (`just check-versions`, `just install-*`) over manual installs so the project stays internally consistent.
