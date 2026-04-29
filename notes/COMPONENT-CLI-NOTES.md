# `component-cli` skill notes

Local notes about the `component-cli` skill in this repo: naming, install
choices, version pinning, and follow-up TODOs.

For *upstream* bugs and improvement requests, see
[`component-registry-improvements.md`](./component-registry-improvements.md).
For the consolidation plan that brings other skills under `component-cli`, see
[`CONSOLIDATION-PLAN.md`](./CONSOLIDATION-PLAN.md).

---

## 1. The naming maze

`component-cli` carries a lot of names, and they don't all point at the same
thing. As of 2026-04-29:

| Where | Name | Notes |
| --- | --- | --- |
| Skill folder | `.agents/skills/component-cli/` | Friendly project name. Stable. |
| GitHub repo | `yoshuawuyts/component-registry` | Renamed from `component-cli` (which was renamed from `wasm-cli`). Old URLs redirect. |
| Cargo workspace dir | `crates/component-cli/` | Matches the project's friendly name. |
| Cargo package name | `component` | What you pass to `cargo install`. |
| Binary name | `component` | What's on `$PATH` after install. |
| README heading | "component-cli" | Project's user-facing identity. |
| Workspace `Cargo.toml` `repository`/`documentation` | `yoshuawuyts/wasm` | Yet another redirect target — points back at `component-registry`. |
| asw101 release fork (legacy) | `asw101/component-cli` v0.0.1 | Tarball is `wasm-<triple>.tar.gz` containing a `wasm` binary (predates the binary rename). Don't use. |

**Convention adopted in this repo**:
- Skill name = **`component-cli`** (matches the project's user-facing name).
- Binary on disk = **`component`** (matches what upstream installs).
- All canonical URLs use **`yoshuawuyts/component-registry`** (the canonical
  repo name; redirects from old names work but are stale).

If upstream renames the project again (it has happened twice), the **skill
name** stays `component-cli` until upstream renames the README / Cargo crate
dir; the **URL** updates immediately to the new canonical repo name.

## 2. Install method

We use **`cargo install --git https://github.com/yoshuawuyts/component-registry component`**.

Rationale:
- Upstream has **no tagged releases** as of 2026-04-29. `git ls-remote --tags`
  is empty; `https://github.com/yoshuawuyts/component-registry/releases/latest`
  returns 404.
- The asw101 fork has a v0.0.1 release, but the tarball ships an old `wasm`
  binary (pre-rename) and is not kept in sync with upstream.
- Cargo handles cross-platform (no per-OS triple logic in the Justfile).
- Trade-off: requires a Rust toolchain to install. `install-component-cli`
  pre-flights `cargo` and exits with a clear error if missing.

Once upstream cuts a release (tracked in
[`component-registry-improvements.md` §6](./component-registry-improvements.md)),
revisit and consider switching to a tarball install for environments without
Rust.

## 3. Version pin

`Justfile` pins `component_cli_version := "main"`. This is **informational
only** — the install builds from upstream main, so the pin doesn't actually
gate the version. The `check-versions` recipe annotates this with
`(no upstream releases — tracks yoshuawuyts/component-registry main)`.

When upstream cuts a release:
1. Change pin to the tag (e.g. `0.3.0`).
2. Update `install-component-cli` to download the release tarball.
3. Update `check-versions` to compare against `gh asw101/component-registry` or
   `gh yoshuawuyts/component-registry`.

## 4. Skill scope and overlap

`component-cli` (the skill) is a strict superset of the now-deleted `wasm-cli`
skill and overlaps with:

- **`wasm-registry`**: registry pull/push/inspect/tags/search/sync/list/delete
  → `component-cli` covers all of these via its `registry` subcommand.
  → P2 of `CONSOLIDATION-PLAN.md`: fold `wasm-registry` into `component-cli`.
- **`wasm-search`**: namespace/component discovery via meta-registry
  → `component-cli registry search` + the `components.json` inventory.
  → P3 of `CONSOLIDATION-PLAN.md`: fold `wasm-search` into `component-cli`.
- **`wasm-build`**: the `compose` subcommand overlaps with the
  `wasm-build/scripts/composition.md` cookbook.
  → P4 of `CONSOLIDATION-PLAN.md`: trim `composition.md` to defer to
    `component-cli`.
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

The skill prefers a binary at `.agents/skills/component-cli/scripts/component`
over the system `$PATH`. The Justfile populates this via
`just install-component-cli .agents/skills/component-cli/scripts` (called from
`just populate-skills`).

Rationale: lets a user run the skill against a known-good binary without
polluting `/usr/local/bin`, and lets us version-pin per-skill if upstream gets
unstable.

The local binary is **gitignored** (`.gitignore` line:
`.agents/skills/component-cli/scripts/component`).

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

## 8. Runtime requirements observed

End-to-end testing on 2026-04-29 against the `main`-built binary (`component
0.3.0`):

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

- [ ] When upstream cuts a release, switch `component_cli_version` from
      `"main"` to the tag and update `install-component-cli` to use a tarball.
- [ ] When P2 (fold `wasm-registry`) lands, audit `SKILL.md` for any
      `wasm-registry`-specific cookbook content that should migrate (e.g.,
      ghcr.io auth flow with `gh auth token`).
- [ ] When P3 (fold `wasm-search`) lands, decide what happens to
      `wasm-search/components.json` — does it move under `component-cli/scripts/`,
      or get replaced by `component registry sync` output?
- [ ] If upstream renames the project a third time, update the canonical URL
      table in §1 and run a repo-wide grep to update all references at once.
- [ ] Verify the Cargo workspace's `repository`/`documentation` URLs (currently
      `yoshuawuyts/wasm`) eventually resolve to a canonical name; file an
      upstream issue if they keep flip-flopping.
- [ ] Consider adding base-toolchain bootstrap recipes to the Justfile or a
      separate `bootstrap.sh`: `bootstrap-rust` (rustup), `bootstrap-node`
      (NodeSource for Node 20+), `bootstrap-go`, `bootstrap-uv`.
- [ ] Update top-level `docs/components.md` and `docs/skills-overview.md` to
      reference the `just install-*` recipes instead of duplicating raw
      `cargo install` / `npm install -g` snippets.
- [ ] Add `wasm-tools` as a documented prerequisite for `install-tinygo`'s
      output (or add `install-wasm-tools` as a recipe dep).
- [ ] `install-js-tools` should warn (or fail) on Node &lt; 20 — jco 1.19
      doesn't actually run on Node 18.
