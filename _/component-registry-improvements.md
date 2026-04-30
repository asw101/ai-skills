# Improvements to upstream `yoshuawuyts/component-registry`

Discovered while end-to-end testing the `component` skill against a freshly cloned `component-registry` repo. The skill itself works; these are bugs and papercuts in yosh's upstream that block or degrade the documented `docker compose up --build` flow.

The repo is **out of MCP scope** in this session — needs to be picked up against `yoshuawuyts/component-registry` in a session with that repo authorized. Branch the work however the upstream prefers (likely a fork → PR).

## Reconciliation status (re-verified against upstream `95ac697`)

| # | Issue | Status |
|---|-------|--------|
| 1 | `Cargo.lock` gitignored, Dockerfiles `COPY` it | ❌ unchanged |
| 2 | `Dockerfile.backend` uses `wasm-meta-registry` (also `Dockerfile.frontend` uses `wasm-frontend`) | ❌ unchanged — both Dockerfiles broken |
| 3 | XDG paths still `/wasm/`, not `/component/` | ❌ unchanged |
| 4 | `run --listen` default `127.0.0.1:8080` collides with frontend | ❌ unchanged (but partially mitigated by `run` now auto-installing `scope:component` — see below) |
| 5 | `Dockerfile.frontend` curls wasmtime at build time | ❌ unchanged |
| 6 | No tagged releases | ⚠️ marginal — `releases/latest` now returns 302 → `/releases` (was 404), but still no actual tags |
| 7 | Install.sh URL points to `yoshuawuyts/component-cli` (redirected) | ❌ unchanged |

**Upstream changes since the original notes** (commits `627cfa4..95ac697`, 9 commits) that affect this skill:
- New top-level `component publish` (#355) — replaces the old `registry push` stub
- New `component registry notify <PACKAGE>` (#340) — push notification of new versions to a meta-registry (default `:8081`)
- `component run` now **auto-installs `scope:component` inputs** if not already installed (#341) — the explicit `install` step in the verification recipe below is now optional
- `component-tui` crate removed (#349) — internal cleanup, no CLI impact
- `component registry push` was removed from the registry subcommand (replaced by top-level `publish`)
- Frontend HTML responses now have ETag-based cache validation (#353)
- Misc: arbitrary library execution (#357), docs/ rendered on website (#334), rust-deps bump (#343), tracey specs deleted (#351)

The skill's `SKILL.md` has been updated for the new commands and removed `registry push`; binary at `.agents/skills/component/scripts/component` rebuilt from upstream `95ac697`.

## 1. `Cargo.lock` is gitignored but the Dockerfiles require it (BLOCKER)

**Symptom**: Fresh `git clone` + `docker compose up --build` fails on the first builder step:
```
target frontend: failed to solve: failed to compute cache key:
  failed to calculate checksum of ref ...: "/Cargo.lock": not found
```

**Root cause**: `.gitignore` lists `Cargo.lock`, yet both `Dockerfile.backend` and `Dockerfile.frontend` have `COPY Cargo.toml Cargo.lock ./`.

**Fix (recommended)**: Remove `Cargo.lock` from `.gitignore` and commit it. This is a workspace with binary crates (`component`, `component-meta-registry`, `component-frontend`) — Rust convention is to commit the lockfile for binaries.

**Alternative**: Have the Dockerfile generate the lockfile inline before `cargo build`:
```dockerfile
RUN cargo generate-lockfile && cargo build --package component-meta-registry --release
```
…but committing is simpler and gives reproducible builds.

## 2. Both Dockerfiles reference old package names (BLOCKER)

**Symptom** (after fix #1): backend or frontend build fails:
```
error: package ID specification `wasm-meta-registry` did not match any packages
```

**Root cause**: Both Dockerfiles still use the pre-rename crate names. The workspace renamed `wasm-meta-registry` → `component-meta-registry` and `wasm-frontend` → `component-frontend`, but the Dockerfiles weren't updated.

**Fix — `Dockerfile.backend`**: replace every occurrence of `wasm-meta-registry` with `component-meta-registry`:
```diff
- RUN cargo build --package wasm-meta-registry --release
+ RUN cargo build --package component-meta-registry --release
- COPY --from=builder /build/target/release/wasm-meta-registry /usr/local/bin/wasm-meta-registry
+ COPY --from=builder /build/target/release/component-meta-registry /usr/local/bin/component-meta-registry
- CMD ["wasm-meta-registry", "/registry", "--bind", "0.0.0.0:8081", "--data-dir", "/data"]
+ CMD ["component-meta-registry", "/registry", "--bind", "0.0.0.0:8081", "--data-dir", "/data"]
```

**Fix — `Dockerfile.frontend`**: replace `wasm-frontend` with `component-frontend`:
```diff
- RUN cargo build --package wasm-frontend --target wasm32-wasip2 --release
+ RUN cargo build --package component-frontend --target wasm32-wasip2 --release
- COPY --from=builder /build/target/wasm32-wasip2/release/wasm_frontend.wasm /app/wasm_frontend.wasm
+ COPY --from=builder /build/target/wasm32-wasip2/release/component_frontend.wasm /app/component_frontend.wasm
- CMD ["wasmtime", "serve", ..., "/app/wasm_frontend.wasm"]
+ CMD ["wasmtime", "serve", ..., "/app/component_frontend.wasm"]
```

Grep the rest of the repo for `wasm-meta-registry` and `wasm-frontend` — likely also stale in scripts and docs.

## 3. `wasm` and `component` paths in default config (papercut)

**Observation**: `component self config` still reports the global config path as `/root/.config/wasm/config.toml` and `component self state` reports the data dir as `/root/.local/share/wasm` and log dir `/root/.local/state/wasm/logs`.

**Root cause**: The CLI's XDG dir name was never updated when the binary was renamed `wasm` → `component`.

**Fix**: in `crates/component-cli` (or wherever `dirs::config_dir()` / `ProjectDirs` is called), change the app name argument from `"wasm"` to `"component"`. Add a one-time migration in `component self state` (or on startup) that moves `~/.config/wasm` → `~/.config/component`, `~/.local/share/wasm` → `~/.local/share/component`, etc., if only the old path exists. Without migration, all existing users lose their state silently.

The `wasm-meta-registry` server's data dir default is also `<OS data dir>/wasm-registry` per the binary's `--help` — same renaming pattern needed there too.

## 4. Default `--listen` for `run` collides with the meta-registry frontend (papercut)

**Symptom**: With `docker compose up` running (frontend on `127.0.0.1:8080`), invoking `component run wasi:http-rust` (the documented quick-start) fails to bind because `--listen` defaults to `127.0.0.1:8080`. The meta-registry that the user *just installed components from* now blocks running them.

**Fix options** (not mutually exclusive):
- Change `run`'s default `--listen` to a non-conflicting port (e.g. `127.0.0.1:8888`)
- Pre-flight check in `run`: if the bind port is already listening, suggest `--listen <other>` rather than failing with a generic "address already in use"
- Change the frontend container's host port from `8080` to something less commonly hijacked (also makes `localhost:3000`-style dev servers cohabit better)

## 5. `Dockerfile.frontend` downloads wasmtime at build time over plain TLS (fragility)

**Symptom in this sandbox** (may not affect non-sandboxed envs): runtime stage `curl -fsSL https://github.com/bytecodealliance/wasmtime/releases/download/...` fails with `exit code: 60` (TLS cert validation). The host network works fine, but docker's bridge network is being intercepted by a TLS proxy.

**Root cause**: pulling a runtime dependency at image build time makes the build network-dependent and breaks in any environment with a TLS-intercepting proxy (corporate network, sandbox, etc.).

**Fix options**:
- Vendor wasmtime via a multi-stage `FROM ghcr.io/bytecodealliance/wasmtime:v44.0.0 AS wasmtime` and `COPY --from=wasmtime /usr/local/bin/wasmtime /usr/local/bin/wasmtime`
- Or expose a build arg to point at an internal mirror

Lower priority than 1–4; mostly bites in restricted envs.

## 6. Upstream repo has no tagged releases (nice-to-have)

`https://github.com/yoshuawuyts/component-registry/releases/latest` returns a 302 redirect to the empty `/releases` page (was a 404 in the original review — minor improvement). `git tag` returns no results. Tools that try to track "current vs latest" via the GitHub releases API still can't. Cut at least one release (`v0.3.0` matches the workspace `Cargo.toml` version) so downstream tooling and version-pinning work.

## 7. Install.sh URL points to redirected repo name (cosmetic)

The README's install snippets use `https://github.com/yoshuawuyts/component-cli/releases/latest/download/install.sh`. The canonical repo is `component-registry` (the `component-cli` URL redirects). Update the README to use the canonical URL so future renames don't break the script.

---

## Quick verification recipe (after fixes 1+2)

In a non-sandbox environment:
```bash
git clone https://github.com/yoshuawuyts/component-registry
cd component-registry
docker compose up --build -d           # frontend :8080, backend :8081, postgres :5432
# wait ~5 min for first build, then:
docker compose ps                       # all three should be healthy
curl -s http://127.0.0.1:8081/v1/health # expect 200
curl -s http://127.0.0.1:8080/v1/health # expect 200 (proxied)

# from a separate dir, with a `component` binary on PATH:
mkdir /tmp/test && cd /tmp/test
component init
component registry sync                                              # "Synced N packages"
component run --listen 127.0.0.1:9090 ba:sample-wasi-http-rust &     # auto-installs since #341
curl http://127.0.0.1:9090/                                          # expect "Hello, wasi:http/proxy world!"
```

If all of the above work, fixes 1+2 are sufficient for documented happy-path. Fixes 3–7 improve robustness and UX.

## Confirmed working

**Original review** (commit `627cfa4`) — meta-registry run directly on the host (bypassing docker due to the sandbox TLS proxy):
- 94 packages indexed across 13 namespaces (`a-skua`, `ba`, `componentized`, `cosmonic-labs`, `fastertools`, `fermyon`, `mattilsynet`, `microsoft`, `twitchax`, `wasi`, `wasmcloud`, `wasmcp`, `yoshuawuyts`)
- `component registry sync` → 42 packages
- `component registry search http --limit 5` → 5 HTTP-related components
- `component install ba:sample-wasi-http-rust` resolved namespace key → `ghcr.io/bytecodealliance/sample-wasi-http-rust/sample-wasi-http-rust`
- `component run --listen 127.0.0.1:9090 ba:sample-wasi-http-rust` → HTTP 200, `Hello, wasi:http/proxy world!`

**Reconciliation rebuild** (commit `95ac697`) — `cargo install --path crates/component-cli --force` succeeded in 7m 04s. New CLI surface verified via `--help`:
- `component publish [--dry-run] [--file <path>] [--manifest-path <dir>]` — present
- `component registry notify <wit-name> [--registry-url <url>]` — present
- `component registry push` — gone (returns "unrecognized subcommand")
- All previously-documented commands still respond correctly

So the CLI itself and the meta-registry server remain functionally sound; the build/packaging/UX issues above remain unaddressed in the upstream repo.
