# wasip3-demo

A minimal **WASI 0.3 (Preview 3)** demonstration component, written in
Rust. Two exports:

| Export | Kind | Purpose |
| --- | --- | --- |
| `greet(name) -> string` | sync | Works as a regular component-model export. |
| `greet-async(name) -> string` | **async** | Uses the new `async func` form. |

## Why this exists

A minimal end-to-end demonstration of the **Flow B** Rust pattern from
[`.agents/skills/wasm-build/scripts/rust.md`](../../.agents/skills/wasm-build/scripts/rust.md):
build a `wasm32-wasip1` core module with the standalone
`wit_bindgen::generate!` macro, then wrap it as a Component using
`wasm-tools component new --adapt`. This is the production-viable Rust
path to WASI 0.3 today — `wasm32-wasip2` produces components natively
but is still tied to the 0.2 ABI; the wasi-preview1 reactor adapter is
what bridges p1 core wasm to the 0.3 component world.

See `.agents/skills/wasm-build/scripts/wasi-0.3.md` for the full p3
toolchain story.

## Build

```bash
cd components
just build-wasip3-demo
```

The recipe:

1. Downloads `wasi_snapshot_preview1.reactor.wasm` from the wasmtime 44
   release into `components/.adapters/` (gitignored).
2. Runs `cargo build --release --target wasm32-wasip1` to produce a
   core wasm module.
3. Runs `wasm-tools component new ... --adapt wasi_snapshot_preview1=… --skip-validation`
   to wrap it as a component. `--skip-validation` is required because
   the produced component uses `context.get` from the async proposal,
   which is not in the default validator feature set.
4. Validates the result with `wasm-tools validate --features all`.

## Run

WASI 0.3 needs **two** flags: `-Sp3` (WASI side) and
`-Wcomponent-model-async` (engine side).

```bash
wasmtime run -Sp3 -Wcomponent-model-async \
    --invoke 'greet("hi")' bin/wasip3-demo.wasm
# "Hello sync, hi!"

wasmtime run -Sp3 -Wcomponent-model-async \
    --invoke 'greet-async("hi")' bin/wasip3-demo.wasm
# "Hello async, hi!"
```

Or via the recipe:

```bash
just test-wasip3-demo
```

## Notes

- Even the sync `greet` export fails to instantiate without
  `-Wcomponent-model-async`, because the binary contains async
  machinery (`context.get`) regardless of which export is invoked.
  This is a property of the codegen, not of the WIT.
- Built size on aarch64 Linux: ~62 KB.
- The `wit_bindgen::generate!` macro's `async: ["greet-async"]` argument
  is what tells the codegen to emit a real `async fn` with future-based
  ABI for that export. Without it, the generator would refuse — async
  WIT only makes sense in a component model that supports it.
