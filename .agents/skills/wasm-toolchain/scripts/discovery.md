# Component discovery cookbook

Find a pre-built WebAssembly component for a task before writing one.

This cookbook covers three discovery paths in priority order. The first that
yields a hit wins.

| Source | Freshness | Auth | Tool |
|---|---|---|---|
| `awesome-wasm-components` README (live) | live | none (public) | WebFetch |
| Curated catalog ([`components.md`](./components.md)) | last refresh dated in file | none | `view`/`grep` |
| Meta-registry search | live | depends on registry | `component registry search` (see `component` skill) |

---

## Path 1 — WebFetch the awesome-wasm-components README

This is the freshest source and should be tried first when network is
available.

```
WebFetch: https://raw.githubusercontent.com/yoshuawuyts/awesome-wasm-components/main/README.md
```

The README is grouped by **Applications** (binary-shaped, typically `wasi:http`
or `wasi:cli`), **Libraries** (callable from any host language), and
**Interfaces** (WIT packages).

Once you find a candidate, follow its repo link to find a published OCI
reference (typically under `ghcr.io/<owner>/...`).

---

## Path 2 — Curated catalog ([`components.md`](./components.md))

Static fallback when the WebFetch path fails (rate-limited, offline, etc.)
or for components Microsoft's `wassette` examples have published. The catalog
is a single markdown table — `view` or `grep` it directly:

```bash
# Find Rust components
grep -i 'rust' .agents/skills/wasm-toolchain/scripts/components.md

# Find HTTP-related components
grep -i 'http' .agents/skills/wasm-toolchain/scripts/components.md

# Find WIT interface packages
sed -n '/## Interfaces/,/^## /p' .agents/skills/wasm-toolchain/scripts/components.md
```

The catalog is hand-maintained and slated for deprecation once
`component registry search` against a real meta-registry is reliable.

---

## Path 3 — `component registry search` (when meta-registry available)

The future of discovery. Requires a running meta-registry (default
`localhost:8080` in `~/.config/wasm/config.toml`).

```bash
component registry search <query>
component registry list
component registry known
```

If the meta-registry is offline or not configured, these commands report a
connection error — fall back to Path 1 or 2.

See the `component` skill for full coverage of the meta-registry flow.

---

## After discovery: pull and inspect

Once you have an OCI reference, pull it with `wkg` (see [`wkg.md`](./wkg.md))
and inspect with `wasm-tools` (see [`wasm-tools.md`](./wasm-tools.md)):

```bash
$WKG oci pull ghcr.io/microsoft/fetch-rs:latest -o /tmp/fetch.wasm
$WASM_TOOLS validate /tmp/fetch.wasm
$WASM_TOOLS component wit /tmp/fetch.wasm   # learn the imports/exports
```

Or, if you have `component` configured against a meta-registry:

```bash
component install <name>
component run <name> -- ...
```

---

## Sources currently aggregated

| Source | URL | Notes |
|---|---|---|
| `awesome-wasm-components` | <https://github.com/yoshuawuyts/awesome-wasm-components> | Curated list — primary upstream |
| Microsoft `wassette` examples | <https://github.com/microsoft/wassette/tree/main/examples> | Pre-published under `ghcr.io/microsoft/...:latest` |
| WebAssembly WASI interfaces | <https://github.com/WebAssembly> | Standard `wasi:*` interface packages under `ghcr.io/webassembly/wasi/...` |

---

## Picking a component for a task

A short workflow:

1. **Restate the task.** "I need an HTTP server", "I need to fetch a URL",
   "I need a Python expression evaluator".
2. **WebFetch awesome-wasm-components** (or fall back to `components.md`).
3. **Filter by language** if the user expressed a preference.
4. **Filter by interface compatibility** — applications expose
   `wasi:http`/`wasi:cli`; libraries expose custom interfaces (see WIT after
   pull).
5. **Pull and inspect** before recommending — don't rely on the description
   alone if the component is going to be wired into a build.
6. **Note the WASI version** — most components today are WASI 0.2; if the
   user's runtime is WASI 0.3-RC, verify the component is built for it.
