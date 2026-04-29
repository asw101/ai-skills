# Rust component cookbook

Three supported flows. **For WASI 0.3 RC, use Flow C** — `cargo-component` 0.21.1 pins `wit-bindgen-rust = 0.41.0` internally and predates `stream<>`/`future<>`/`async fn` codegen (which landed in `wit-bindgen` 0.57). The standalone `wit-bindgen` macro flow is the production-viable Rust path to 0.3 today.

| Flow | Best for | WASI 0.3 RC? |
|---|---|---|
| **A — `cargo-component`** | Custom WIT against WASI 0.2 with the most ergonomic Cargo experience | ❌ Stuck on `wit-bindgen 0.41` until cargo-component cuts a new release |
| **B — Direct `wasm32-wasip2`** | Plain CLI / WASI-only programs (no custom exports) | ❌ Targets wasip2 only |
| **C — `wit-bindgen` macro + adapter** | Custom WIT against WASI 0.2 **or** 0.3 RC, full control over codegen | ✅ Use `wit-bindgen = "0.57.1"` |

`wasm32-wasip2` has been a Tier 2 target since Rust 1.82 (2024-10), so a recent stable toolchain is enough.

## Prerequisites

```bash
rustup target add wasm32-wasip1 wasm32-wasip2

# Flow A (custom WIT, WASI 0.2 only)
cargo install cargo-component@0.21.1

# Flow C (custom WIT, WASI 0.2 or 0.3 RC) — drop in your component's Cargo.toml:
#   wit-bindgen = "0.57.1"

# Always useful
cargo install wasm-tools@1.248.0
```

## Flow A — `cargo-component` (custom WIT)

### Scaffold

```bash
cd components
cargo component new my-component --lib
cd my-component
```

### Project layout

```
my-component/
├── Cargo.toml
├── wit/
│   └── world.wit
└── src/
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
wit-bindgen-rt = { version = "0.39", features = ["bitflags"] }

[package.metadata.component]
package = "local:my-component"

[profile.release]
opt-level = "s"
lto = true
strip = true
```

`cargo-component` generates the bindings module automatically (in `src/bindings.rs`) — you do **not** call `wit_bindgen::generate!` yourself in this flow.

### src/lib.rs

```rust
#[allow(warnings)]
mod bindings;

use bindings::exports::local::my_component::interface_name::Guest;

struct Component;

impl Guest for Component {
    fn process(input: String) -> Result<String, String> {
        Ok(format!("Processed: {input}"))
    }
}

bindings::export!(Component with_types_in bindings);
```

### Build

```bash
cargo component build --release --target wasm32-wasip2
cp target/wasm32-wasip2/release/my_component.wasm ../bin/my-component.wasm
wasm-tools validate ../bin/my-component.wasm
```

> **Naming:** Cargo replaces `-` with `_` in the produced artifact. Use `${NAME//-/_}.wasm` in build scripts. The repo's `components/csv-groupby/build.sh` shows this pattern.

## Flow B — Direct `wasm32-wasip2` (WASI-only programs)

Use this when the component is a plain CLI program that imports WASI but does not export custom interfaces.

### Cargo.toml

```toml
[package]
name = "my-cli"
version = "0.1.0"
edition = "2021"

[dependencies]
# Optional: idiomatic wasi bindings
wasi = "0.14"

[profile.release]
opt-level = "s"
lto = true
strip = true
```

### src/main.rs

```rust
use std::io::{self, Read, Write};

fn main() -> io::Result<()> {
    let mut input = String::new();
    io::stdin().read_to_string(&mut input)?;
    io::stdout().write_all(format!("Processed: {input}").as_bytes())?;
    Ok(())
}
```

### Build

```bash
cargo build --release --target wasm32-wasip2
cp target/wasm32-wasip2/release/my-cli.wasm ../bin/my-cli.wasm
wasm-tools validate ../bin/my-cli.wasm
```

## Flow C — `wit-bindgen` macro + `wasm-tools component new`

**This is the WASI 0.3 RC path.** Lower-level than `cargo-component`, but tracks the latest `wit-bindgen` (0.57.1) and supports `stream<>` / `future<>` / `async fn`.

```toml
[dependencies]
# WASI 0.2 OR 0.3 RC. 0.57.1 is the first release with full stream/future/async.
wit-bindgen = "0.57.1"
```

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

After building a core module, wrap it as a component using the appropriate adapter:

```bash
cargo build --release --target wasm32-wasip1
wasm-tools component new \
  target/wasm32-wasip1/release/my_component.wasm \
  --adapt wasi_snapshot_preview1.command.wasm \
  -o ../bin/my-component.wasm
```

The adapter (`wasi_snapshot_preview1.{command,reactor,proxy}.wasm`) is published with each `wasmtime` release. Pick `command` for CLIs, `reactor` for callable libraries, `proxy` for HTTP.

For WASI 0.3 RC, point your WIT at the snapshot:

```wit
package local:my-component;
use wasi:cli/command@0.3.0-rc-2026-03-15;
world my-component {
  include wasi:cli/command@0.3.0-rc-2026-03-15;
  export run: async func();
}
```

Then run with `wasmtime run -Sp3 -Wcomponent-model-async ../bin/my-component.wasm`. See [`wasi-0.3.md`](./wasi-0.3.md) for the full picture.

## Real example in this repo

[`components/csv-groupby/`](../../../../components/csv-groupby/) — Rust component using `cargo-component`. See its `Cargo.toml`, `wit/`, and `build.sh`. Pin in that example may lag the table above; the values in `scripts/README.md` are the source of truth.

## Tips

- **Smallest size:** `opt-level = "z"`, `codegen-units = 1`, `panic = "abort"`, `strip = true`. Then run `wasm-opt -Oz`.
- **Fastest:** `opt-level = 3`, `lto = "fat"`.
- **Diagnose bloat:** `cargo bloat --release --target wasm32-wasip2 --crates`.
- **Check exports:** `wasm-tools component wit ../bin/my-component.wasm`.
- **WASI 0.3 RC:** Use **Flow C** (`wit-bindgen = "0.57.1"` + `wasm-tools component new`). `cargo-component` 0.21.1 pins `wit-bindgen-rust = 0.41.0` and **cannot build 0.3 components today** — its main branch hasn't released since 2025-04-07. The standalone `wit-bindgen` macro generates `stream<>`, `future<>`, and `async fn` exports correctly. Run resulting components with `wasmtime run -Sp3 -Wcomponent-model-async`. See [`wasi-0.3.md`](./wasi-0.3.md).

## Troubleshooting

- **`error: target may not be installed`** → `rustup target add wasm32-wasip2`.
- **`cargo-component: command not found`** → `cargo install cargo-component@0.21.1`.
- **Module is not a component** → you targeted `wasm32-wasip1` without wrapping. Use `wasm-tools component new ... --adapt wasi_snapshot_preview1.*.wasm`.
- **`wit_bindgen` macro errors mentioning a missing world** → the world name must match a `world` declaration inside `wit/*.wit`.
