# AGENTS.md

Repo-level guidance for AI coding agents working in this repository.

This repo curates a small set of standalone agent skills for WebAssembly
component work. Each skill under `.agents/skills/<name>/` is self-contained
and describes only what it does — the routing policy that decides which
skill to use lives here.

## Skills inventory

| Skill | What it does |
| --- | --- |
| [`component`](./.agents/skills/component/SKILL.md) | Full WebAssembly component lifecycle via the `component` CLI: init / install / build / run / compose / push / pull / search. |
| [`wasm-toolchain`](./.agents/skills/wasm-toolchain/SKILL.md) | Upstream Bytecode Alliance utilities (`wkg`, `wasm-tools`) and a curated component catalog. |
| [`wasmtime`](./.agents/skills/wasmtime/SKILL.md) | Run / debug / profile components and core modules with the `wasmtime` runtime. |
| [`wasm-build`](./.agents/skills/wasm-build/SKILL.md) | Build components from Rust, Python, JavaScript/TypeScript, or Go. |
| [`wasm-build-multi`](./.agents/skills/wasm-build-multi/SKILL.md) | Build the same component in *every* supported language from one prompt — sibling directories per toolchain for side-by-side comparison. Sits on top of `wasm-build`. |
| [`just`](./.agents/skills/just/SKILL.md) | `just` command runner and Justfile recipes. |
| [`hyperlight-sandbox`](./.agents/skills/hyperlight-sandbox/SKILL.md) | Hyperlight micro-VM Python SDK for hardware-isolated guest code. |

## Skill routing

Three of the WebAssembly skills overlap (`component`, `wasm-toolchain`,
`wasmtime` all touch push/pull/run/inspect to varying degrees). Use this
policy to pick:

1. **Default to `component`** for anything in the WebAssembly component
   lifecycle: init, install, build, run, compose, push, pull, search,
   inspect. The `component` CLI is a superset for the common cases.

2. **Pick `wasm-toolchain` (`wkg` / `wasm-tools`) when** any of:
   - The user explicitly names `wkg` or `wasm-tools`.
   - The task requires raw `org.opencontainers.image.*` annotation
     control on push (the `component` CLI does not expose these yet).
   - The task involves WIT-package authoring (`wkg wit fetch`,
     `wkg wit build`, `wkg publish`, `wkg.lock`).
   - The task needs lower-level component manipulation
     (`wasm-tools component embed`, `wasm-tools component extract`,
     `wasm-tools metadata add/show`, `wasm-tools print`, etc.) that
     `component` does not cover.
   - Component discovery via the curated catalog
     (`.agents/skills/wasm-toolchain/scripts/components.md`).

3. **Pick `wasmtime` when** any of:
   - The user explicitly names `wasmtime`.
   - The task needs `wasmtime` features `component run` does not expose:
     `--invoke <wave>` for direct export calls, AOT `compile` to `.cwasm`,
     `wizer` snapshotting, HTTP `serve` with custom flags, `objdump`,
     `explore`, or `settings`.

4. **`wasm-build` is orthogonal** to lifecycle — it covers source →
   `.wasm` per language. After building, defer back to `component` for
   the rest of the lifecycle. Combine with `wasm-toolchain` if the user
   needs raw `wkg`/`wasm-tools` post-build.

5. **`just` and `hyperlight-sandbox` are orthogonal** to all the above.

For a richer task × tool overlap matrix, see
[`docs/skill-routing.md`](./docs/skill-routing.md).

## Conventions

- All skill SKILL.md files use the convention
  `.agents/skills/<name>/scripts/<binary>` for skill-local tool binaries
  (resolved with `[ -x "$TOOL" ] || TOOL="<tool>"`). The Justfile
  `populate-skills` recipe installs the binaries.
- The `Justfile` is the single source of truth for tool versions
  (run `just versions` to print the table). Bootstrap recipes
  (`bootstrap-rust`, `bootstrap-go`, `bootstrap-node`, `bootstrap-uv`,
  `bootstrap-all`) install the underlying language toolchains.
