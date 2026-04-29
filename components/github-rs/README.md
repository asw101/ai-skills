# github (multi-language)

A WebAssembly component that exposes minimal **GitHub API** access — fetches basic
details about a user or a repository — built four times in four languages:

| Language | Source | Output | Size |
| --- | --- | --- | --- |
| Rust | [`github-rs/`](github-rs/) | `bin/github-rs.wasm` | 144K |
| Go (TinyGo) | [`github-go/`](github-go/) | `bin/github-go.wasm` | 1.2M |
| JavaScript | [`github-js/`](github-js/) | `bin/github-js.wasm` | 14M |
| Python | [`github-py/`](github-py/) | `bin/github-py.wasm` | 21M |

All four implementations export the same `local:github/api` interface and import
`wasi:http/outgoing-handler@0.2.0` for the actual API calls. Built with the
[`wasm-build-multi`](../.agents/skills/wasm-build-multi/SKILL.md) skill.

## Shared world

Each language directory has its own `wit/world.wit` (master copy lives in
`github-rs/wit/world.wit`). Python additionally trims the world to avoid a
componentize-py interface-name clash; see "Per-language quirks" below.

```wit
package local:github;

interface api {
    record user-info { login, id, name?, bio?, public-repos, followers, following, html-url }
    record repo-info { full-name, description?, stargazers-count, forks-count, language?, default-branch, html-url }
    get-user: func(login: string, token: option<string>) -> result<user-info, string>;
    get-repo: func(owner: string, repo: string, token: option<string>) -> result<repo-info, string>;
}

world github {
    include wasi:cli/imports@0.2.0;   // omitted in the Python WIT
    import wasi:http/types@0.2.0;
    import wasi:http/outgoing-handler@0.2.0;
    export api;
}
```

The optional `token` parameter on each call is what makes the component "with
and without authentication" — pass `none` for unauthenticated requests
(GitHub allows ~60 calls/hour) or `some(<personal-access-token>)` for the
authenticated 5,000 calls/hour rate limit.

## Build

```bash
just build-github-rs        # cargo build --target wasm32-wasip2
just build-github-js        # jco componentize
just build-github-go        # tinygo build -target=wasip2 (raw wasi:http bindings)
just build-github-py        # componentize-py componentize
just build-all-github       # all four
just validate-github        # wasm-tools validate every bin/github-*.wasm
```

## Run (requires network)

```bash
wasmtime run -S http --invoke 'get-user("octocat", none)' bin/github-rs.wasm
wasmtime run -S http --invoke 'get-repo("rust-lang", "rust", none)' bin/github-js.wasm
just test-github rs         # shorthand for the rs variant; LANG can be js/go/py
```

`-S http` is required to grant the component outgoing HTTP capability. To
exercise the authenticated path, pass `some("<token>")` instead of `none` —
the same surface works for both modes.

## Per-language quirks

- **Rust** — uses `wit_bindgen::generate!` 0.57.1 with `generate_all`. Drives
  `wasi:http/outgoing-handler` directly; ~110 lines including header building
  and stream draining.
- **JavaScript** — `jco componentize` is happy enough that the source is just
  `await fetch('https://api.github.com/...')`. componentize-js falls back to
  v0.19.3 because we pin wasi 0.2.0; this is a warning, not an error.
- **Go (TinyGo 0.41)** — TinyGo's `net/http` requires Go 1.24 stdlib features
  not in 0.41, so we drive raw wasi:http via `wit-bindgen-go`-generated
  bindings instead. The world `include`s `wasi:cli/imports` because TinyGo's
  runtime imports them unconditionally; without the include, component
  encoding fails.
- **Python (componentize-py 0.23)** — uses the auto-generated `poll_loop.py`
  helper to drive wasi:io polling via asyncio. Python's WIT *omits* the
  `include wasi:cli/imports` line because it would force the
  `wasi:filesystem/types` and `wasi:http/types` modules to disambiguate as
  `wasi_filesystem_types`/`wasi_http_types`, which `poll_loop.py` doesn't
  expect.

## Limitations

- **No runtime tests in CI.** Hitting the live GitHub API requires network
  access plus `-S http=allow-private-network` — easy to do locally but skipped
  here. `just test-github <lang>` will work outside the sandbox.
- **wasi 0.2.0**, not 0.2.6 — pinned for componentize-py compatibility.
- **No streaming / no pagination** — get-user and get-repo are single-shot
  GETs returning a flat record.
