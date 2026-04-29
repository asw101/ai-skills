# Rust component cookbook

Two flows, both built on the standalone `wit-bindgen` crate (0.57+):

| Flow | Target | When |
|---|---|---|
| **A — `cargo build --target wasm32-wasip2`** | `wasm32-wasip2` (Tier 2 since Rust 1.82) | Default for **WASI 0.2 and 0.3** with custom or upstream WIT — produces a Component directly, no adapter step. |
| **B — `cargo build --target wasm32-wasip1` + `wasm-tools component new --adapt …`** | `wasm32-wasip1` core module wrapped with the reactor/command adapter | When you need explicit control over the adapter (e.g. publishing a component that targets specific reactor/command/proxy semantics). |

> **Important:** there is no `wasm32-wasip3` rustc target. Flow A (`--target wasm32-wasip2`) is the right answer for **both** WASI 0.2 and WASI 0.3 components. The component's import map comes from your `wit/world.wit` (and what `wkg wit fetch` populates under `wit/deps/`), **not** from the rustc target. `wasm32-wasip2` simply produces a Component instead of a core module.

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
    generate_all,
    // The async: [...] array lists qualified WIT symbols whose Rust
    // signature should be async, **but only ones where the WIT itself
    // does NOT already say `async func`**. If the WIT already declares
    // an export or import as `async func`, wit-bindgen will detect
    // it automatically and listing it here triggers
    // `error: unused async option`.
    //
    // Common usage:
    //   - List p3 *imports* you want to await (e.g. wasi:http/client#send),
    //     because their upstream WIT does declare them as `async func` —
    //     but wit-bindgen still wants you to opt into the async lowering
    //     of the import wrapper explicitly.
    //   - Do NOT list your own exports if their WIT is `async func`.
    // async: [
    //     "wasi:http/client@0.3.0-rc-2026-03-15#send",
    // ],
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
wasm-tools validate --features all ../bin/my-component.wasm
```

The `wasm32-wasip2` target produces a Component directly — no `wasm-tools component new` step needed.

> `--features all` is a no-op superset for plain WASI 0.2 components and required for any p3 component (anything using `stream<>` / `future<>` / `async func`). Make it your default; you'll never have to remember to flip it on.

> **Naming:** Cargo replaces `-` with `_` in the produced artifact, e.g. `csv-groupby` → `target/wasm32-wasip2/release/csv_groupby.wasm`. Account for this when copying to a stable name.

## WASI 0.3 with Flow A (the recommended path)

Most p3 components (HTTP clients, custom interfaces, async exports) build cleanly through Flow A. Point your WIT at the snapshot, run `wkg wit fetch`, and `cargo build --target wasm32-wasip2` produces a p3 component directly.

```wit
package local:my-component;

interface api {
  process: async func(input: string) -> result<string, string>;
}

world my-component {
  import wasi:http/client@0.3.0-rc-2026-03-15;
  import wasi:http/types@0.3.0-rc-2026-03-15;
  export api;
}
```

```bash
wkg wit fetch
cargo build --release --target wasm32-wasip2
cp target/wasm32-wasip2/release/my_component.wasm ../bin/my-component.wasm
wasm-tools validate --features all ../bin/my-component.wasm  # --features all is required for stream/future
wasmtime run -Sp3 -Shttp -Wcomponent-model-async \
    --invoke 'process("hi")' ../bin/my-component.wasm
```

### Canonical p3 HTTP client pattern

The 0.3 `wasi:http/client.send` returns a future; the response body is a `stream<u8>` that you drain manually. Skeleton:

```rust
wit_bindgen::generate!({
    world: "my-component",
    path: "wit",
    generate_all,
    async: ["wasi:http/client@0.3.0-rc-2026-03-15#send"],
});

use wit_bindgen::rt::async_support::{wit_future, StreamResult};
use wasi::http::{client, types::*};

async fn http_get_json(url: &str) -> Result<Vec<u8>, String> {
    // Build a trivial-Ok future for trailers (we don't send any).
    let (_, trailers_future) =
        wit_future::new::<Result<Option<Fields>, ErrorCode>>(|| Ok(None));

    let headers = Fields::new();
    headers.append(&"User-Agent".into(), &b"my-component".to_vec()).unwrap();

    // Request::new returns (request, send-progress-future).
    // For GET: contents=None, options=None.
    let (request, _send_progress) =
        Request::new(headers, None, trailers_future, None);
    request.set_method(&Method::Get).unwrap();
    request.set_scheme(Some(&Scheme::Https)).unwrap();
    request.set_authority(Some("api.example.com")).unwrap();
    request.set_path_with_query(Some(url)).unwrap();

    let response = client::send(request).await
        .map_err(|e| format!("send failed: {e:?}"))?;

    // Consume body. The handler-side completion future signals when the
    // host is done with the body; pass a trivially-Ok future for read-only
    // consumers.
    let (_, done_future) =
        wit_future::new::<Result<(), ErrorCode>>(|| Ok(()));
    let (body_stream, _trailers_rx) = Response::consume_body(response, done_future);

    // Drain. body_stream.read(buf) returns (StreamResult, Vec<u8>); the
    // returned vec contains the bytes that were appended into buf.
    let mut body = Vec::with_capacity(8 * 1024);
    loop {
        let (status, chunk) = body_stream.read(Vec::with_capacity(8 * 1024)).await;
        body.extend_from_slice(&chunk);
        match status {
            StreamResult::Complete(_) => continue,         // more bytes may follow
            StreamResult::Dropped | StreamResult::Cancelled => break, // EOF
        }
    }
    Ok(body)
}
```

Subtle bits:

- `wit_future::new(|| default).1` returns the **reader** half (`.0` is the writer). For senders that own no real future payload, the unused writer drops at end of scope and the future resolves with `default`.
- `body_stream.read(buf)` accepts and returns a `Vec<u8>`. The returned vec is the buffer with read bytes appended; it is **not** the same allocation you passed in.
- `StreamResult::Dropped` and `StreamResult::Cancelled` both mean EOF for a read loop. Don't surface them as errors.
- `StreamResult` lives at `wit_bindgen::rt::async_support::StreamResult` — not in the prelude.

## Flow B — `wasm32-wasip1` + `wasm-tools component new --adapt`

Use Flow B only when you need explicit adapter control — e.g. embedding a specific reactor/command/proxy adapter version, or shipping to a host that doesn't support the wasm32-wasip2 component output directly.

For 0.3 with `wasi:cli/command`:

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
- Run resulting components with `wasmtime run -Sp3 -Wcomponent-model-async` (add `-Shttp` for HTTP-importing components). See [`wasi-0.3.md`](./wasi-0.3.md) for the full picture.

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
- **`wit_bindgen` macro: "unused async option"** → you listed something in `async: [...]` whose WIT already declares it as `async func`. Remove that entry. Keep only entries whose WIT keeps the sync `func` form (or qualified imports the macro doesn't auto-detect).
- **At runtime, missing async support** → run with `wasmtime run -Sp3 -Wcomponent-model-async`. Even sync exports of a component compiled with `async: [...]` need this flag.
- **At runtime, `instance export 'fields' has the wrong type / resource implementation is missing`** → you forgot `-Shttp` alongside `-Sp3`. See [`wasi-0.3.md`](./wasi-0.3.md).
- **`wasm-tools validate`: `stream requires the component model async feature`** → re-run with `--features all` (or `--features cm-async`).
