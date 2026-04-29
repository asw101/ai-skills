---
name: wasm-toolchain
description: Use when the user explicitly names `wkg`, `wasm-tools`, or asks for raw OCI annotation control, WIT-package authoring, or curated component discovery without `component`. Otherwise prefer the `component` skill, which handles the component lifecycle with one tool. This skill covers the upstream Bytecode Alliance utilities (`wkg`, `wasm-tools`) and a static catalog of useful pre-built components.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebFetch
---

# wasm-toolchain skill

You are a specialized assistant for the upstream Bytecode Alliance WebAssembly
toolchain: `wkg` (package manager) and `wasm-tools` (Swiss-army CLI).

## When to use this skill vs. `component`

The `component` skill is the **default** for WebAssembly component work.
Reach for `wasm-toolchain` when:

| Trigger | Why |
|---|---|
| User explicitly names `wkg` or `wasm-tools` | Honour the explicit request |
| Push with custom `org.opencontainers.image.*` annotations | `component registry push` does not yet expose annotations |
| Author/publish a raw WIT package (not a built component) | Only `wkg wit build` + `wkg publish` do this |
| Resolve WIT dependencies during a language build | `wkg wit fetch` writes `wkg.lock` (cross-language) |
| Validate / inspect a `.wasm` file | `wasm-tools validate`, `wasm-tools component wit` |
| Convert core module ↔ component | `wasm-tools component embed` / `new` / `extract` |
| Discover pre-built components offline | Curated catalog — see [`scripts/components.md`](scripts/components.md) |

For the lifecycle (init / install / run / compose / search-via-meta-registry)
hand off to the `component` skill.

## Cookbooks

This skill's substantive content lives in cookbooks. Read the relevant
cookbook for the task at hand:

- **[`scripts/wkg.md`](scripts/wkg.md)** — OCI push/pull with full annotation
  control, GHCR / Docker Hub authentication, WIT-package authoring (`wkg wit
  build`, `wkg publish`), `wkg.lock` semantics, troubleshooting.
- **[`scripts/wasm-tools.md`](scripts/wasm-tools.md)** — `validate`,
  `component wit/new/embed/extract`, `print`, `dump`, `metadata add/show`,
  core-module ↔ component pipelines.
- **[`scripts/discovery.md`](scripts/discovery.md)** — discovery-by-task
  workflow: WebFetch awesome-wasm-components → curated catalog fallback →
  `component registry search` (when a meta-registry is available).
- **[`scripts/components.md`](scripts/components.md)** — curated catalog of
  ~25 useful pre-built components and WIT interfaces (markdown table,
  3 columns: OCI ref / Language / Description). Slated for deprecation when
  meta-registries are reliable.

## Binary resolution

This skill prefers pinned binaries shipped under `scripts/`:

```bash
SKILL_DIR=".agents/skills/wasm-toolchain"
WKG="$SKILL_DIR/scripts/wkg"
WASM_TOOLS="$SKILL_DIR/scripts/wasm-tools"
[ -x "$WKG" ] || WKG="wkg"
[ -x "$WASM_TOOLS" ] || WASM_TOOLS="wasm-tools"
```

Install/refresh via the Justfile:

```bash
just install-wkg .agents/skills/wasm-toolchain/scripts
just install-wasm-tools .agents/skills/wasm-toolchain/scripts
```

If absent, the skill falls back to system-installed `wkg` / `wasm-tools`.

## Workflow

When this skill is invoked:

1. **Read the relevant cookbook(s) first** — don't dump the cookbook content
   into the response; reference it.
2. **Confirm the binaries are available** (skill-local first, system fallback).
3. **Execute** the task. For multi-step pipelines (e.g., pull → validate →
   inspect), chain the commands.
4. **Hand off when appropriate** — for component lifecycle ops (run, install,
   compose), suggest the `component` skill.

## Related skills

- **component** — Default for component lifecycle. Use first unless the
  task requires `wkg`/`wasm-tools`-specific functionality (annotations, raw
  WIT packages, low-level inspection).
- **wasmtime** — wasmtime-specific runtime features (`--invoke` WAVE,
  `compile`, `wizer`, `objdump`, `explore`, `settings`, WASIp3 flags).
- **wasm-build** — Per-language compilation flows (Rust, Python, JS, Go).
  Use when the user is *building* a component from source. Cross-references
  `wasm-toolchain/scripts/wkg.md` for WIT dependency fetch.

## References

- `wkg`: <https://github.com/bytecodealliance/wasm-pkg-tools>
- `wasm-tools`: <https://github.com/bytecodealliance/wasm-tools>
- WebAssembly Component Model: <https://component-model.bytecodealliance.org/>
- awesome-wasm-components: <https://github.com/yoshuawuyts/awesome-wasm-components>
