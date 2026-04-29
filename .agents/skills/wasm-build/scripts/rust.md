# Rust component cookbook

Two flows, both built on the standalone `wit-bindgen` crate (0.57+):

| Flow | Target | When |
|---|---|---|
| **A — `cargo build --target wasm32-wasip2`** | `wasm32-wasip2` (Tier 2 since Rust 1.82) | Default for **WASI 0.2** and custom WIT — produces a Component directly, no adapter step. |
| **B — `cargo build --target wasm32-wasip1` + `wasm-tools component new --adapt …`** | `wasm32-wasip1` core module wrapped with the reactor/command adapter | **WASI 0.3 RC** (`async fn`, `stream<>`, `future<>`), or any case where you need explicit control over the adapter. |

`cargo-component` is no longer used in this repo. Its only added value over Flow A was auto-running `wasm-tools component new` for `wasm32-wasip1` builds — but `wasm32-wasip2` produces a component natively, and Flow B handles the p1+adapter case explicitly. Each component now pins its own `wit-bindgen` version in `Cargo.toml`, which means **0.57.1 across the board** (no more lockstep with cargo-component's pinned 0.41).

## Prerequisites

```bash
rustup target add wasm32-wasip1 wasm32-wasip2
cargo install wasm-tools@1.248.0
# wit-bindgen is a per-component crate dep, not a global install:
#   wit-bindgen = "0.57.1"   in your Cargo.toml
```

## Project layout (both flows)

```
my-component/
 Cargo.toml
 wit/
   └── world.wit
 src/
    └── lib.rs
```

### Cargo.toml

```toml
[package]
name = "my-component"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib"]

[dependencies]
wit-bindgen = "0.57.1"

[profile.release]
opt-level = "s"
lto = true
strip = true
```

### src/lib.rs

```rust
wit_bindgen::generate!({
    world: "my-world",
    path: "wit",
    // For 0.3 with async exports:
    // async: ["my-async-export"],
});

struct Component;

impl Guest for Component {
    fn process(input: String) -> Result<String, String> {
        Ok(format!("Processed: {input}"))
    }
}

export!(Component);
```

## Flow A — `wasm32-wasip2` (WASI 0.2, recommended default)

```bash
cargo build --release --target wasm32-wasip2
cp target/wasm32-wasip2/release/my_component.wasm ../bin/my-component.wasm
wasm-tools validate ../bin/my-component.wasm
```

The `wasm32-wasip2` target produces a Component directly — no `wasm-tools component new` step needed.

> **Naming:** Cargo replaces `-` with `_` in the produced artifact, e.g. `csv-groupby` → `target/wasm32-wasip2/release/csv_groupby.wasm`. Account for this when copying to a stable name.

## Flow B — `wasm32-wasip1` + `wasm-tools component new --adapt`

Use this for **WASI 0.3 RC** or when you need explicit adapter control.

For 0.3, point your WIT at the snapshot:

```wit
package local:my-component;
use wasi:cli/command@0.3.0-rc-2026-03-15;
world my-component {
  include wasi:cli/command@0.3.0-rc-2026-03-15;
  export run: async func();
}
```

```bash
cargo build --release --target wasm32-wasip1
wasm-tools component new \
  target/wasm32-wasip1/release/my_component.wasm \
  --adapt wasi_snapshot_preview1=path/to/wasi_snapshot_preview1.reactor.wasm \
  --skip-validation \
  -o ../bin/my-component.wasm
wasm-tools validate --features all ../bin/my-component.wasm
```

Notes:

- `--skip-validation` is required for components using async machinery (`context.get`), because the validator's default feature set excludes the async proposal. Re-validate afterwards with `--features all`.
- The adapter (`wasi_snapshot_preview1.{command,reactor,proxy}.wasm`) is published with each `wasmtime` release. Pick `command` for CLIs, `reactor` for callable libraries, `proxy` for HTTP.
- Run resulting components with `wasmtime run -Sp3 -Wcomponent-model-async`. See [`wasi-0.3.md`](./wasi-0.3.md) for the full picture.

## Real examples in this repo

- **[`components/csv-groupby/`](../../../../components/csv-groupby/)** — Flow A. WASI 0.2 + custom WIT. Build: `cargo build --release --target wasm32-wasip2`. Run via `just build-csv-groupby` from `components/`.
- **[`components/tech-ticker/`](../../../../components/tech-ticker/)** — Flow A, smaller. Two simple exports (`ping`, `random-string`).
- **[`components/wasip3-demo/`](../../../../components/wasip3-demo/)** — Flow B. WASI 0.3 with a sync export and an `async func` export. The `Justfile` recipe downloads the reactor adapter on first build.

## Tips

- **Smallest size:** `opt-level = "z"`, `codegen-units = 1`, `panic = "abort"`, `strip = true`. Then run `wasm-opt -Oz`.
- **Fastest:** `opt-level = 3`, `lto = "fat"`.
- **Diagnose bloat:** `cargo bloat --release --target wasm32-wasip2 --crates`.
- **Check exports:** `wasm-tools component wit ../bin/my-component.wasm`.

## Troubleshooting

- **`error: target may not be installed`** → `rustup target add wasm32-wasip2` (or `wasm32-wasip1` for Flow B).
- **`Module is not a component`** → you targeted `wasm32-wasip1` without wrapping. Use `wasm-tools component new ... --adapt wasi_snapshot_preview1=…`.
- **`context.get requires the component model async feature`** at `wasm-tools component new` time → pass `--skip-validation` and re-validate with `wasm-tools validate --features all`.
- **`wit_bindgen` macro errors mentioning a missing world** → the `world:` argument must match a `world` declaration inside `wit/*.wit`.
- **At runtime, missing async support** → run with `wasmtime run -Sp3 -Wcomponent-model-async`. Even sync exports of a component compiled with `async: [...]` need this flag.
