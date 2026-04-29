# Targeting WASI 0.3 (Release Candidate)

WASI 0.3 is **not yet final** but its release-candidate snapshots are usable today. This repo is fine with using the RC.

## Status (2026-04-29)

| Item | Pin / status |
|---|---|
| Snapshot | `wasi:* @ 0.3.0-rc-2026-03-15` |
| `wasmtime` minimum | **43.0.0** (added WASIp3 support, 2026-03-20) |
| `wasmtime` recommended | **44.0.0** (current; adds `wasi:tls 0.3.0-draft` and experimental component-model `map<K,V>`) |
| Final 0.3.0 release | Pending — see <https://wasi.dev/roadmap> |

The repo's `Justfile` pins `wasmtime_version := "44.0.0"`, so `just install-wasmtime` provisions a WASIp3-capable runtime.

## Enabling WASIp3 in `wasmtime`

WASIp3 needs **two** flags: a WASI-side switch and a Wasm-engine-side switch for the new async types.

```bash
# Run a 0.3 component (-Sp3 enables WASIp3 imports; -Wcomponent-model-async
# enables the engine support for stream<>/future<>/async).
wasmtime run -Sp3 -Wcomponent-model-async components/bin/my-component.wasm

# Serve an HTTP component using wasi:http@0.3.0 (the http-p3 form uses -Sp3,common
# to also turn on the wasi:cli "common" set).
wasmtime serve -Sp3,common -Wcomponent-model-async components/bin/my-component.wasm

# Inspect the flags
wasmtime run -S help | grep -i p3
wasmtime run -W help | grep async
```

Notes:

- `-S p3=y` and `-Sp3` are equivalent; clap accepts both forms for `Option<bool>` (definition: `pub p3: Option<bool>` in `wasmtime/crates/cli-flags/src/lib.rs:521`).
- `-W component-model-async` is a feature group; it enables `wasm_component_model_async`, `_async_builtins`, `_async_stackful`, and `_threading` engine settings (`cli-flags/src/lib.rs:1152-1155`).
- Without `-W component-model-async`, components that import or export `stream<>` / `future<>` / `async func` will fail to instantiate.

## What's new in WIT for 0.3

WASI 0.3 introduces native async types in WIT:

```wit
package local:async-demo;

interface async-io {
  // Stream of bytes, incremental.
  read-stream: func() -> stream<u8>;

  // Future of an async response.
  fetch: func(url: string) -> future<response>;

  // Async functions can simply have async result types.
  load: async func(path: string) -> result<list<u8>, string>;
}
```

The 0.2 → 0.3 redesign touches several interfaces:

- `wasi:http@0.3.0` shrinks to ~5 resource types (vs 11 in 0.2). Outgoing-handler + types are folded together; bodies are `stream<u8>`.
- `wasi:io@0.3.0` no longer needs the `poll`/`pollable` shim; `stream<>` and `future<>` replace it.
- `wasi:sockets`, `wasi:filesystem`, `wasi:keyvalue` get incremental updates.
- `wasi:tls@0.3.0-draft` is **not** part of the RC snapshot but is implemented in wasmtime 44.

## Per-language guest support

| Language | 0.3 readiness | Notes |
|---|---|---|
| **Rust** | ✅ Best path, but **only via Flow C** in [`rust.md`](./rust.md). `wit-bindgen` 0.57.1 generates `stream<>` / `future<>` / `async fn` exports. **`cargo-component` 0.21.1 cannot build 0.3 components** — it pins `wit-bindgen-rust = 0.41.0` internally and its main branch hasn't released since 2025-04-07. | Use `wit_bindgen::generate!` macro + `wasm-tools component new --adapt wasi_snapshot_preview1.*.wasm`. |
| **JavaScript** | 🟡 Active dev on `main` but **not yet released**. `jco@1.19.0` (npm, 2026-04-22) ships only `preview2-shim` — no `p3-shim` or `0.3.0-rc` references in the published tarball. Upstream commits since 2026-04-13 (`add p3 wasi test components`, future/stream lift/lower, `p3-shim`) are landing daily; expect a 1.20-series npm release. | Track [bytecodealliance/jco@main](https://github.com/bytecodealliance/jco/commits/main) until released. Async maps to JS `Promise`; streams map to async iterators. |
| **Python** | ✅ Working today via [componentize-py 0.23.0](https://pypi.org/project/componentize-py/0.23.0/) (released 2026-04-15). Upstream ships [`cli-p3`](https://github.com/bytecodealliance/componentize-py/tree/main/examples/cli-p3), [`http-p3`](https://github.com/bytecodealliance/componentize-py/tree/main/examples/http-p3), and [`tcp-p3`](https://github.com/bytecodealliance/componentize-py/tree/main/examples/tcp-p3) examples on `0.3.0-rc-2026-03-15`. `async def` exports map naturally to `async func`; `componentize_py_async_support.streams` / `.futures` mediate `stream<>` / `future<>`. | After Rust, the most production-viable path. See [`python.md`](./python.md). |
| **Go (TinyGo)** | ⚠️ Bindings only. `wit-bindgen-go` (`go.bytecodealliance.org` v0.7.0) emits `stream<>` / `future<>` / `error-context` types since v0.6.0, but **TinyGo has no `wasip3` target** — only `wasip1` and `wasip2`. Components targeting WASI 0.3 cannot be produced today. | Track [tinygo-org/tinygo](https://github.com/tinygo-org/tinygo/issues?q=is%3Aissue+wasip3) for a future target. |
| **Go (standard)** | ❌ Not viable. Standard Go targets `GOOS=wasip1` only; the `wasi_snapshot_preview1.{command,reactor,proxy}.wasm` adapters published with each wasmtime release map p1 → **0.2**, not 0.3. | Stay on WASI 0.2 with the adapter flow; Rust is the path for 0.3 today. |

## Pulling 0.3 WIT packages

```bash
# In wit/world.wit
package local:my-component;

use wasi:http/types@0.3.0-rc-2026-03-15.{request, response};

world my-component {
  import wasi:http/handler@0.3.0-rc-2026-03-15;
  export handle: async func(req: request) -> response;
}
```

Then:

```bash
wkg wit fetch
```

If the registry doesn't yet host the snapshot, you may need to vendor the WIT directly under `wit/deps/` (download from the [WASI repo](https://github.com/WebAssembly/wasi-http) at the snapshot tag).

## Migration tips (0.2 → 0.3)

- Most 0.2 components keep working with `-Sp3 -Wcomponent-model-async` because wasmtime virtualizes 0.2 atop 0.3 where it can.
- Replace any custom `poll`/`pollable` plumbing with `stream<>` / `future<>` — that's the entire point of 0.3.
- Pin to a specific RC snapshot (`0.3.0-rc-2026-03-15`) in WIT and `wkg.lock`. Do not chase `main`; RC snapshots are the contract.
- `wasi:tls@0.3.0-draft` is an outlier — it's draft, not part of the RC snapshot. Use only if you accept further churn.

## Troubleshooting

- **"unknown WASI interface"** → wasmtime version is < 43.0.0 (or you forgot `-Sp3 -Wcomponent-model-async`). `just install-wasmtime` will pull the pinned 44.0.0.
- **Mixed-version components fail to compose** → ensure every component in the composition uses the same RC snapshot. `wac` will not auto-bridge 0.2 ↔ 0.3.
- **Stream / future codegen errors in Rust** → bump `wit-bindgen` to 0.57.1+; older versions don't know about `stream<>`/`future<>`.
- **`unknown wasm feature: component-model-async`** → wasmtime version is older than 43; upgrade and re-run with `-Wcomponent-model-async`.
- **Component instantiates but stream/future calls trap** → you passed `-Sp3` but forgot `-Wcomponent-model-async`. Both are needed.
- **TLS imports unsatisfied** → `wasi:tls` is draft; pass `-Sp3 -Wcomponent-model-async` AND the host must have wasmtime 44 (which ships the draft impl).

## References

- WASI roadmap: <https://wasi.dev/roadmap>
- Wasmtime 43 release (added WASIp3): <https://github.com/bytecodealliance/wasmtime/blob/release-43.0.0/RELEASES.md>
- Wasmtime 44 release: <https://github.com/bytecodealliance/wasmtime/blob/release-44.0.0/RELEASES.md>
- Component-model async design: <https://github.com/WebAssembly/component-model/blob/main/design/mvp/Async.md>
