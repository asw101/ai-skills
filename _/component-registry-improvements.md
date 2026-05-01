# Improvements to upstream `yoshuawuyts/component-registry`

Discovered while end-to-end testing the `component` skill against a freshly cloned `component-registry` repo. The skill itself works; these are bugs and papercuts in yosh's upstream that block or degrade the documented `docker compose up --build` flow.

**2026-05-01 update**: Fixes A, C, and D below are now committed to
`asw101/component-registry@patch-1` (branch `claude/init-component-registry-OIo6r`).
The skill binary is now built from that fork/branch. See §Resolved below.
Fix B (TLS/rustls) is partially resolved for WASI 0.3 components; WASI 0.2
components using HTTPS (github-go, github-js) remain broken.

The repo is **out of MCP scope** in this session — needs to be picked up against `yoshuawuyts/component-registry` in a session with that repo authorized. Branch the work however the upstream prefers (likely a fork → PR).

## ⚠️ Latest findings — runtime gaps in `component v0.3.0` (BLOCKERS)

Discovered trying to run real components from `components/bin/*.wasm`. The new "library-style" auto-CLI feature from #357 is excellent — `component run <file>` introspects the WIT exports and turns each interface and function into a subcommand with typed flags. But every actual invocation hit one of three runtime failures.

### A. WASI 0.3 components fail to parse — wasmtime built without component-model async feature

**Symptom**:
```
$ component run components/bin/github-rs.wasm api get-user octocat
Error:   × failed to compile Wasm Component
  ╰─▶ failed to parse WebAssembly module: `stream` requires the component model async feature
```

**Root cause**: `crates/component-cli` doesn't enable wasmtime's component-model async feature. Likely a missing `wasmtime::Config::async_support(true)` or a Cargo feature like `component-model-async`.

**Fix**: enable the relevant wasmtime feature/config in `component-cli`.

---

### B. WASI 0.2 + HTTPS panics — rustls has no default CryptoProvider

**Symptom**:
```
thread 'tokio-rt-worker' panicked at rustls-0.23.40/src/crypto/mod.rs:249:14:
Could not automatically determine the process-level CryptoProvider from Rustls crate features.
```

**Root cause**: `rustls` 0.23 dropped the default-provider bundling; `component-cli`'s `Cargo.toml` doesn't enable `aws-lc-rs` or `ring`.

**Fix**: enable the `ring` feature on the `rustls` dep, *or* call `rustls::crypto::ring::default_provider().install_default().ok();` once in `main()` before constructing the wasmtime engine. One-line fix.

---

### C. Auto-CLI generator can't collect `list<>` arguments

**Symptom**:
```
Error:   × unsupported argument type for `group-columns`: cannot collect list
```

**Fix**: extend the type-to-flag mapping to handle `list<T>` as a repeatable flag (`--flag val1 --flag val2`) using clap's `Vec<T>` with `num_args = 1..`.

---

### D. (New) Auto-CLI generator aborts on interfaces with `stream<T>` or `option<record>` params

**Symptom** (discovered 2026-05-01):
```
$ component run components/bin/copilot-rs.wasm --help
Error:   × unsupported WIT type kind: stream
```
Even functions that don't use streams (e.g. `list-models`) were unreachable
because the `chat` function in the same interface uses `stream<string>`.
A second variant: `option<chat-options>` caused the same abort for `chat-buffered`.

**Root cause**: `extract_library_surface` (wit.rs) and `build_clap` (cli.rs)
propagated errors from a single unsupported function up to the caller, killing
the entire interface/world.

**Fix** (landed in `asw101/component-registry@patch-1`):
- `wit.rs`: skip functions where `func_to_decl` returns an unsupported-kind error.
- `cli.rs`: skip functions where `build_func_command` returns a CliError.
- `cli.rs`: `collect_typed_many` returns `Ok(vec![])` for absent `list<record>` flags
  instead of erroring unconditionally.

Three separate commits on `patch-1` (one per layer).

---

### Summary (as of 2026-05-01)

| Component | WASI | Before patch-1 | After patch-1 |
|---|---|---|---|
| `github-rs.wasm` | 0.3 | ❌ A — parse fails on `stream` | ✅ get-user works (with GH_TOKEN) |
| `github-py.wasm` | 0.3 | ❌ A — parse fails on `stream` | ✅ get-user works (with GH_TOKEN) |
| `wasip3-demo.wasm` | 0.3 | ❌ A — parse fails on `context.get` | ✅ greet / greet-async work |
| `copilot-rs.wasm` | 0.3 | ❌ A+D — stream kills interface | ✅ list-models works (with GH_TOKEN) |
| `copilot-py.wasm` | 0.3 | ❌ A+D — stream kills interface | ✅ list-models works (with GH_TOKEN) |
| `csv-groupby.wasm` | 0.2 | ❌ C — `list<>` unsupported | ✅ execute-group-by works |
| `stock-ticker.wasm` | 0.2 | ❌ C — `list<>` unsupported | ✅ get-price / get-all-prices / tick work |
| `tech-ticker.wasm` | 0.2 | ❌ C — `list<>` unsupported | ✅ ping / random-string work |
| `github-js.wasm` | 0.2 | ❌ B — rustls panic | ❌ string encoding error at runtime |
| `github-go.wasm` | 0.2 | ❌ B — rustls panic | ❌ TLS error (`http: TLS-protocol-error`) |
| `time-server.wasm` | — | — | ❌ `missing world "time-server"` in WIT |

**`component run` can now successfully invoke 8 of 11 components** in the repo.
`github-js` and `github-go` remain blocked by WASI 0.2 + HTTPS issues;
`time-server` is blocked by a missing WIT world name.

---

## Reconciliation status (re-verified against upstream `95ac697`)

| # | Issue | Status |
|---|-------|--------|
| 1 | `Cargo.lock` gitignored, Dockerfiles `COPY` it | ❌ unchanged |
| 2 | Both Dockerfiles use old package names (`wasm-meta-registry`, `wasm-frontend`) | ❌ unchanged |
| 3 | XDG paths still `/wasm/`, not `/component/` | ❌ unchanged |
| 4 | `run --listen` default `:8080` collides with frontend | ❌ unchanged |
| 5 | `Dockerfile.frontend` curls wasmtime at build time | ❌ unchanged |
| 6 | No tagged releases | ⚠️ marginal improvement |
| 7 | Install.sh URL points to redirected repo name | ❌ unchanged |

---

## Fix details

**1. `Cargo.lock` gitignored** — Remove from `.gitignore` and commit it. Binary crates should commit the lockfile.

**2. Old package names in Dockerfiles** — Update `Dockerfile.backend` (`wasm-meta-registry` → `component-meta-registry`) and `Dockerfile.frontend` (`wasm-frontend` → `component-frontend`) throughout.

**3. XDG paths** — Change the `ProjectDirs` app name from `"wasm"` to `"component"` and add a one-time migration path.

**4. Port collision** — Change `run`'s default `--listen` from `:8080` to `:8888`, or add a pre-flight port-conflict check.

**5. Wasmtime curl at build time** — Use a multi-stage `FROM ghcr.io/bytecodealliance/wasmtime:v44.0.0 AS wasmtime` instead of curling at runtime.

**6. No releases** — Cut a `v0.3.0` tag to match `Cargo.toml` version.

**7. Install URL** — Update README from `yoshuawuyts/component-cli` to the canonical `yoshuawuyts/component-registry`.

The git mirror is still returning HTTP 503 — this is a platform-side issue that can't be resolved by retrying. The 2 commits on `main` are safely preserved in R2 (`2601-ai-skills-complete.bundle`). Nothing more I can do until the mirror is repaired.