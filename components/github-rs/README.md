# github (multi-language)

A WebAssembly component that exposes minimal **GitHub API** access — fetches basic
details about a user or a repository — built four times in four languages, with
two of them on **WASI 0.3** and two still on WASI 0.2:

| Language | Source | Output | Size | WASI version |
| --- | --- | --- | --- | --- |
| Rust | [`github-rs/`](github-rs/) | `bin/github-rs.wasm` | 179K | **0.3.0-rc-2026-03-15** ✅ |
| Python | [`github-py/`](github-py/) | `bin/github-py.wasm` | 19M | **0.3.0-rc-2026-03-15** ✅ |
| JavaScript | [`github-js/`](github-js/) | `bin/github-js.wasm` | 14M | 0.2.0 (jco@1.19 lacks p3-shim — track [bytecodealliance/jco#main](https://github.com/bytecodealliance/jco/commits/main)) |
| Go (TinyGo) | [`github-go/`](github-go/) | `bin/github-go.wasm` | 1.2M | 0.2.0 (TinyGo has no `wasip3` target — track [tinygo-org/tinygo#wasip3](https://github.com/tinygo-org/tinygo/issues?q=is%3Aissue+wasip3)) |

All four implementations export the same `local:github/api` interface. The Rust
and Python ones use **`wasi:http/client@0.3.0-rc-2026-03-15`** (`async func send`)
and expose `get-user` / `get-repo` as `async func`. The JavaScript and Go
implementations stay on `wasi:http/outgoing-handler@0.2.0` for now. Built with
the [`wasm-build-multi`](../.agents/skills/wasm-build-multi/SKILL.md) skill; see
also [`wasi-0.3.md`](../.agents/skills/wasm-build/scripts/wasi-0.3.md).

## Shared API surface (WIT)

The 0.3 (`get-user`/`get-repo` are `async func`):

```wit
package local:github;

interface api {
    record user-info { ... }
    record repo-info { ... }
    get-user: async func(login: string, token: option<string>) -> result<user-info, string>;
    get-repo: async func(owner: string, repo: string, token: option<string>) -> result<repo-info, string>;
}

world github {
    import wasi:http/client@0.3.0-rc-2026-03-15;
    import wasi:http/types@0.3.0-rc-2026-03-15;
    export api;
}
```

The optional `token` parameter is what makes the component "with and without
authentication" — pass `none` for unauthenticated requests (~60 calls/hour) or
`some(<personal-access-token>)` for the authenticated 5,000 calls/hour rate
limit.

The 0.2 variant in `github-js/` and `github-go/` keeps the same record shapes
and function names but the world imports
`wasi:http/outgoing-handler@0.2.0` instead and the functions are sync (`func`,
not `async func`).

## Build

```bash
just build-github-rs        # cargo build --target wasm32-wasip2 (with -Wcomponent-model-async)
just build-github-py        # componentize-py componentize
just build-github-js        # jco componentize  (still p2)
just build-github-go        # tinygo build -target=wasip2  (still p2)
just build-all-github       # all four
just validate-github        # wasm-tools validate every bin/github-*.wasm
```

## Run (requires network)

The runtime flags differ between p2 and p3 components:

```bash
# p3 (Rust, Python) — needs -Sp3 and -Wcomponent-model-async
wasmtime run -Sp3 -Shttp -Wcomponent-model-async \
    --invoke 'get-user("octocat", none)' bin/github-rs.wasm
wasmtime run -Sp3 -Shttp -Wcomponent-model-async \
    --invoke 'get-repo("rust-lang", "rust", none)' bin/github-py.wasm

# p2 (JavaScript, Go)
wasmtime run -Shttp \
    --invoke 'get-user("octocat", none)' bin/github-js.wasm

# Justfile shorthand: dispatches the right flags per lang
just test-github rs        # rs/py -> p3 flags
just test-github js        # js/go -> p2 flags
just test-all-github       # all four
```

To exercise the authenticated path, pass `some("<token>")` instead of `none` —
the same surface works for both modes.

## Per-language quirks

- **Rust** — `wit_bindgen::generate!` 0.57.1 with `async: ["wasi:http/client@0.3.0-rc-2026-03-15#send"]`. The `request.new(...)` constructor needs a `future<result<option<trailers>, error-code>>`; for a no-trailers GET, `wit_future::new(|| Ok(None))` produces a trivially-Ok future. Body draining loops over `body_stream.read(buf).await` until `StreamResult::Dropped`.
- **Python (componentize-py 0.23)** — `from wit_world.imports import client` gives `await client.send(request)`. Trailers / unit futures use the auto-generated module-level helpers (`wit_world.result_option_..._future`, `wit_world.result_unit_..._future`). The exported `Api` class's methods are real `async def`.
- **JavaScript (jco@1.19)** — Stays on p2. **Status:** jco@1.19 ships only `preview2-shim`. p3-shim is on `bytecodealliance/jco@main` but unreleased to npm — re-evaluate when jco 1.20+ ships. Source is unchanged from the p2 commit (native `fetch()` lowered by jco).
- **Go (TinyGo 0.41)** — Stays on p2. **Status:** TinyGo's `wasip2` target works fine, but `wasip3` is not a TinyGo target yet. Even if you generate p3 bindings via `wit-bindgen-go` (which does support `stream<>`/`future<>`), there's no toolchain to compile them through. Tracked in `tinygo-org/tinygo` issues. The component drives raw wasi:http via `wit-bindgen-go`-generated bindings (TinyGo's `net/http` needs Go 1.24 stdlib bits not in 0.41).

## Limitations

- **No CI runtime tests.** Hitting the live GitHub API requires network access
  plus `-Shttp` (and `-Sp3 -Wcomponent-model-async` for the p3 builds) — easy
  locally, deferred in CI. `just test-all-github` will work outside the sandbox.
- **WASI 0.3 is a release candidate** (`0.3.0-rc-2026-03-15`). The 0.3.0 final
  spec is not yet shipped — see <https://wasi.dev/roadmap>.
- **Mixed versions** within a single composition would not auto-bridge — every
  component in a `wac` graph must use the same WASI snapshot. Here each language
  is built and validated independently, so that's not a concern in practice.

