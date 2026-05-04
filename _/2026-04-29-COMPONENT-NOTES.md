# `component` skill notes

Local notes about the `component` skill in this repo: naming, install
choices, version pinning, and follow-up TODOs.

For *upstream* bugs and improvement requests, see
[`component-registry-improvements.md`](./component-registry-improvements.md).
For the consolidation plan that brings other skills under `component`, see
[`CONSOLIDATION-PLAN.md`](./CONSOLIDATION-PLAN.md).

---

## 1. The naming maze

`component` carries a lot of names, and they don't all point at the same
thing. As of 2026-04-29:

| Where | Name | Notes |
| --- | --- | --- |
| Skill folder | `.agents/skills/component/` | Friendly project name. Stable. |
| GitHub repo | `yoshuawuyts/component-registry` | Renamed from `component-cli` (which was renamed from `wasm-cli`). Old URLs redirect. |
| Cargo workspace dir | `crates/component-cli/` | Matches the project's friendly name. |
| Cargo package name | `component` | What you pass to `cargo install`. |
| Binary name | `component` | What's on `$PATH` after install. |
| README heading | "component-cli" | Project's user-facing identity. |
| Workspace `Cargo.toml` `repository`/`documentation` | `yoshuawuyts/wasm` | Yet another redirect target — points back at `component-registry`. |
| asw101 release fork (legacy) | `asw101/component-cli` v0.0.1 | Tarball is `wasm-<triple>.tar.gz` containing a `wasm` binary (predates the binary rename). Don't use. |

**Convention adopted in this repo**:
- Skill name = **`component`** (matches the project's user-facing name).
- Binary on disk = **`component`** (matches what upstream installs).
- All canonical URLs use **`yoshuawuyts/component-registry`** (the canonical
  repo name; redirects from old names work but are stale).

If upstream renames the project again (it has happened twice), the **skill
name** stays `component` until upstream renames the README / Cargo crate
dir; the **URL** updates immediately to the new canonical repo name.

## 2. Install method

**2026-05-01**: The skill binary is now built from **`asw101/component-registry@patch-1`**
(branch `claude/init-component-registry-OIo6r`), not from upstream main.
This fork carries three layers of fixes that make `component run` work against
real WASI 0.2 and 0.3 components (see §11). Build command:

```bash
git clone https://github.com/asw101/component-registry -b patch-1
cargo build --release --package component
cp target/release/component .agents/skills/component/scripts/component
```

Previous method was **`cargo install --git https://github.com/yoshuawuyts/component-registry component`**.

Rationale for switching to the fork:
- Upstream has **no tagged releases** as of 2026-05-01.
- The fork's `patch-1` branch carries WASI 0.3 async support, `list<T>` CLI
  fixes, and stream/option-record graceful-skip fixes that upstream doesn't
  have yet.
- Once these fixes land upstream or a release is cut, revert to upstream main.

Trade-off: requires a Rust toolchain and ~7 min build. `install-component`
pre-flights `cargo` and exits with a clear error if missing.

## 3. Version pin

`Justfile` pins `component_version := "main"`. This is **informational
only** — the install builds from upstream main, so the pin doesn't actually
gate the version. The `check-versions` recipe annotates this with
`(no upstream releases — tracks yoshuawuyts/component-registry main)`.

When upstream cuts a release:
1. Change pin to the tag (e.g. `0.3.0`).
2. Update `install-component` to download the release tarball.
3. Update `check-versions` to compare against `gh asw101/component-registry` or
   `gh yoshuawuyts/component-registry`.

## 4. Skill scope and overlap

`component` (the skill) is a strict superset of the now-deleted `wasm-cli`
skill and overlaps with:

- **`wasm-registry`**: registry pull/push/inspect/tags/search/sync/list/delete
  → `component` covers all of these via its `registry` subcommand.
  → P2 of `CONSOLIDATION-PLAN.md`: fold `wasm-registry` into `component`.
- **`wasm-search`**: namespace/component discovery via meta-registry
  → `component registry search` + the `components.json` inventory.
  → P3 of `CONSOLIDATION-PLAN.md`: fold `wasm-search` into `component`.
- **`wasm-build`**: the `compose` subcommand overlaps with the
  `wasm-build/scripts/composition.md` cookbook.
  → P4 of `CONSOLIDATION-PLAN.md`: trim `composition.md` to defer to
    `component`.
- **`wasm-run`**: the `run` subcommand wraps wasmtime.
  → `wasm-run` keeps wasmtime-specific debugging/inspection; `component run` is
    the default path for "execute a component". Cross-link both ways in P4.

## 5. Upstream stability caveat

The README has:

> [!CAUTION] This repository is under active development and therefore unstable.
> Breaking changes are expected.

Because we track `main`, breaking upstream changes can surface in any rebuild.
Mitigations:

- The skill is pinned to `main` *intentionally* — the cost of staleness is
  worse than the cost of breakage right now.
- If upstream breaks our documented examples, the fix is to update the skill,
  not to pin to a SHA. (Pinning to a SHA would mask the breakage.)
- Keep an eye on `component --help` output — when subcommands appear/disappear,
  update `SKILL.md` accordingly. The current SKILL.md was verified against
  `component --help` on 2026-04-29.

## 6. Local binary detection (`scripts/component`)

The skill prefers a binary at `.agents/skills/component/scripts/component`
over the system `$PATH`. The Justfile populates this via
`just install-component .agents/skills/component/scripts` (called from
`just populate-skills`).

Rationale: lets a user run the skill against a known-good binary without
polluting `/usr/local/bin`, and lets us version-pin per-skill if upstream gets
unstable.

The local binary is **gitignored** (`.gitignore` line:
`.agents/skills/component/scripts/component`).

## 7. Build cost and dependencies

`cargo install --git https://github.com/yoshuawuyts/component-registry component`
takes **~5 minutes** on aarch64 with a primed cargo registry cache (cold cache
adds ~30s for the registry index). Memory pressure peaks around 850 MB during
the wasmtime crate compile. The binary is **~30 MB** stripped.

Heavy transitive dependencies:
- `wasmtime` and friends (`wasmtime-wasi`, `wasmtime-wasi-http`,
  `wasmtime-internal-cranelift`) — pulled in for `component run`. This single
  dep accounts for ~half the build time.
- `oci-client`, `oci-wasm`, `oci-spec` — for `component registry`/`install`.
- `wac-parser` / `wac-graph` / `wac-resolver` — for `component compose`.
- `pubgrub`, `cacache`, `warg-client` — package-manager machinery.

Implication: **you can't quick-iterate on the binary in environments without a
Rust toolchain**. Once upstream cuts a release we get tarballs and this stops
mattering.

## 11. wit2cli fixes in `asw101/component-registry@patch-1` (2026-05-01)

Three commits on `patch-1` / `claude/init-component-registry-OIo6r`:

| Commit | Layer | Fix |
|---|---|---|
| `b2d74b7` | `wit.rs` WIT extraction | Skip functions whose signature contains `stream<T>`, `future<T>`, or other unsupported WIT types instead of aborting the whole interface |
| `7e2811d` | `cli.rs` CLI builder | Skip functions where `build_func_command` returns a CliError (e.g. `option<record>` params), as a second line of defence |
| `0f1e108` | `cli.rs` arg collection | `collect_typed_many` returns `Ok(vec![])` for absent `list<record>` flags instead of erroring unconditionally |

Effect: `component run` can now invoke 8 of 11 components in `components/bin/`.
`github-go` and `github-js` remain broken (WASI 0.2 HTTPS / TLS issues upstream);
`time-server` has a missing WIT world name.

---

## 8. Runtime requirements observed

End-to-end testing on 2026-04-29 against the `main`-built binary (`component
0.3.0`), then re-tested on 2026-05-01 against `patch-1`:

- **`component init`** — works offline. Creates `wasm.toml`, `wasm.lock.toml`,
  and `build/`, `seams/`, `types/`, `vendor/` directories.
- **`component self config` / `component self state`** — work offline.
- **`component registry sync`** — **requires a running meta-registry**
  (`docker compose up --build` in the upstream repo, exposing `:8080`). Without
  it, errors with `could not reach registry at http://localhost:8080`.
- **`component registry search <q>`** — depends on synced data; empty until
  `sync` succeeds.
- **`component install <ghcr-ref>`** — direct OCI install requires registry
  auth (`Not authorized` from `ghcr.io/v2/...`) even for public components.
  Auth is via `component self config` (TOML); investigate `gh auth token`
  integration for ghcr.io.
- **`component run <local.wasm>`** — works offline. Runs WASI 0.2 components
  built by `tinygo -target=wasip2`, `cargo component build`,
  `componentize-py componentize`, etc.

Confirmed bug: `self config` and `self state` report XDG paths under
`~/.config/wasm/`, `~/.local/share/wasm/`, `~/.local/state/wasm/logs` — the
binary was renamed `wasm` → `component` but the XDG app name wasn't updated.
Documented in
[`component-registry-improvements.md` §3](./component-registry-improvements.md#3-wasm-and-component-paths-in-default-config-papercut).

## 9. Other skills' install-X recipes — gotchas observed

- **`install-js-tools`**: `npm install -g` requires sudo (writes to
  `/usr/lib/node_modules`). The Justfile recipe assumes you run it as root. On
  Ubuntu 24.04, `apt install nodejs` gives Node 18.19 + npm 9.2; jco 1.19 emits
  `EBADENGINE` (wants Node 20+) and **fails at runtime** with
  `ERR_MODULE_NOT_FOUND`. Use NodeSource or `nvm install 22` instead.
- **`install-go-tools`**: works with Go 1.22 from `apt install golang-go`,
  even though the recipe's error message says "Install Go 1.23+". The wit-bindgen-go
  v0.7.0 module compiles fine on 1.22.
- **`install-tinygo`**: works as documented. Writes 166 MB tarball to
  `/usr/local/tinygo` and symlinks `/usr/local/bin/tinygo`. Requires sudo.
  TinyGo's `wasip2` build target needs `wasm-tools` on PATH — the Justfile
  populates it via `populate-skills` but `install-tinygo` doesn't list it as a
  dependency. Document this or add a check.
- **`install-rust-tools`**: takes 15-25 min cold. Memory peaks near 1.2 GB
  during cargo-component's compile.
- **No recipe for base toolchains**: `rustup`, `node`/`npm`, `go`, `python+uv`
  must be installed before any `install-X` recipe will succeed. Each recipe
  emits a clear "install from $URL" error. Worth documenting in the top-level
  `docs/` so users don't bounce through the error messages.

## 10. Open follow-ups

Track here as we hit them:

- [ ] When upstream cuts a release, switch `component_version` from
      `"main"` to the tag and update `install-component` to use a tarball.
- [ ] When `patch-1` fixes land upstream, revert install to upstream main
      and drop the fork reference in §2.
- [ ] `github-go` and `github-js` remain broken — investigate the TLS
      (`http: TLS-protocol-error`) and string encoding (`expected a string`)
      failures in their respective runtime stacks.
- [ ] `time-server.wasm` fails with `missing world "time-server"` — the WIT
      world name embedded in the component doesn't match. Investigate whether
      the binary needs to be rebuilt or the world name corrected.
- [ ] `copilot-rs` / `copilot-py`: `chat-buffered` is hidden from the sub-CLI
      because `option<chat-options>` is unsupported. Once `option<record>` is
      supported at the CLI layer, expose it.
- [ ] When P2 (fold `wasm-registry`) lands, audit `SKILL.md` for any
      `wasm-registry`-specific cookbook content that should migrate (e.g.,
      ghcr.io auth flow with `gh auth token`).
- [ ] When P3 (fold `wasm-search`) lands, decide what happens to
      `wasm-search/components.json` — does it move under `component/scripts/`,
      or get replaced by `component registry sync` output?
- [ ] If upstream renames the project a third time, update the canonical URL
      table in §1 and run a repo-wide grep to update all references at once.
- [ ] Verify the Cargo workspace's `repository`/`documentation` URLs (currently
      `yoshuawuyts/wasm`) eventually resolve to a canonical name; file an
      upstream issue if they keep flip-flopping.

### Closed (2026-04-29)

- [x] **Base-toolchain bootstrap recipes** — added `bootstrap-rust`,
      `bootstrap-node`, `bootstrap-go`, `bootstrap-uv`, plus `bootstrap-all`
      aggregate. Idempotent and platform-aware (Linux + macOS, x86_64 +
      aarch64). NodeSource for Linux Node, Homebrew for macOS Node/Go,
      go.dev tarball for Linux Go.
- [x] **Top-level docs use `just install-*`** — replaced raw `cargo install`,
      `npm install -g`, `pip install`, `brew install tinygo`, and
      `npm install -g wasm-opt` snippets in `docs/components.md` and
      `docs/skills-overview.md` with the matching recipe. Build/usage examples
      (e.g. `cargo component build`, `tinygo build -target=wasip2`) are
      unchanged.
- [x] **`install-tinygo` warns about wasm-tools** — TinyGo's `-target=wasip2`
      shells out to `wasm-tools component embed`. Recipe now prints a warning
      after install if `wasm-tools` is missing, pointing at
      `just install-wasm-tools` / `just install-rust-tools`. Troubleshooting
      table in `docs/components.md` covers the failure mode too.
- [x] **`install-js-tools` rejects Node &lt; 20** — recipe now exits with a
      pointer at `just bootstrap-node` instead of installing jco that would
      fail at runtime with `ERR_MODULE_NOT_FOUND`.

