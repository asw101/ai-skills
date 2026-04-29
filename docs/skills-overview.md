# Agent Skills Overview

This repository ships a small set of **Agent Skills** for WebAssembly
component development. Each skill is a self-contained folder under
`.agents/skills/<name>/` with a `SKILL.md` (frontmatter +
instructions) and an optional `scripts/` directory.

The skills work with Claude Code, Cursor, GitHub Copilot, and any
other agent that supports the [Agent Skills standard](https://agentskills.io/).

For the routing policy that picks among them, see
[AGENTS.md](../AGENTS.md). For a richer task × tool overlap matrix,
see [skill-routing.md](skill-routing.md).

## Skills

### `component`

**Location:** `.agents/skills/component/`

Manages the full WebAssembly component lifecycle through the
[`component` CLI](https://github.com/yoshuawuyts/component-registry).
Covers `init`, `install`, `build`, `run`, `compose`, `push`, `pull`,
`search`, `inspect`, against OCI registries (GHCR, Docker Hub, ACR)
and meta-registries.

**Capabilities:**
- Project initialization with WIT scaffolding
- Dependency management (`component install ba:wasi-cli@0.2`)
- Build via the underlying language toolchains
- Run components and HTTP services
- Compose multi-component apps
- Push / pull / search components on registries

---

### `wasm-toolchain`

**Location:** `.agents/skills/wasm-toolchain/`

Upstream Bytecode Alliance utilities (`wkg`, `wasm-tools`) plus a
curated catalog of pre-built components for discovery.

**Capabilities:**
- `wkg`: OCI push/pull with full annotation control,
  WIT-package authoring (`wkg wit fetch/build/publish`,
  `wkg.lock`), GHCR/Docker auth.
- `wasm-tools`: `validate`, `print`, `dump`, `metadata add/show`,
  `component embed/extract/wit`, low-level inspection.
- Curated component catalog at `scripts/components.md` (~25
  pre-built components, OCI references).

---

### `wasmtime`

**Location:** `.agents/skills/wasmtime/`

Run, debug, and profile WebAssembly components and core modules with
the [`wasmtime` runtime](https://wasmtime.dev/).

**Capabilities:**
- `wasmtime run` and `wasmtime serve`
- `--invoke 'fn(args)'` with WAVE syntax for direct export calls
- `wasmtime compile` for AOT to `.cwasm`
- `wasmtime wizer` for snapshotting
- `objdump` / `explore` / `settings` for inspection
- WASIp2 and WASIp3 support

---

### `wasm-build`

**Location:** `.agents/skills/wasm-build/`

Build WebAssembly components from Rust, Python, JavaScript/TypeScript,
or Go using WASI Preview 2 and the Component Model.

**Capabilities:**
- Scaffold new component projects with WIT definitions
- Language-specific cookbooks: Rust (`cargo-component`), Python
  (`componentize-py`), JS/TS (`jco` + `componentize-js`), Go
  (`tinygo` + `wit-bindgen-go`).
- Compile to `wasm32-wasip2`
- Validate WIT interfaces and component structure
- Optimize size and startup

---

### `just`

**Location:** `.agents/skills/just/`

Work with the [`just`](https://github.com/casey/just) command runner
and Justfile recipes.

**Capabilities:**
- List, run, create, modify recipes
- Debug recipe errors
- Explain Justfile syntax

---

### `hyperlight-sandbox`

**Location:** `.agents/skills/hyperlight-sandbox/`

Run untrusted code in hardware-isolated [Hyperlight](https://github.com/hyperlight-dev/hyperlight)
micro-VMs via the `hyperlight-sandbox` Python SDK.

**Capabilities:**
- Sandbox creation and code execution
- Tool dispatch (host functions callable from guest)
- File I/O, network allowlisting
- Snapshot / restore

---

## How skills work

### Discovery

The agent host (Claude Code, Cursor, etc.) reads each `SKILL.md`'s
frontmatter `description:` and matches it against the user's request.
The repo-level [AGENTS.md](../AGENTS.md) provides additional routing
policy for when more than one skill might match.

### Local binaries

Skills prefer a binary at `.agents/skills/<name>/scripts/<tool>` when
it exists, falling back to the system-installed binary on `$PATH`:

```bash
SKILL_DIR=".agents/skills/<name>"
TOOL="$SKILL_DIR/scripts/<tool>"
[ -x "$TOOL" ] || TOOL="<tool>"
```

Populate skill-local binaries with `just populate-skills`. Remove with
`just clean-skills`.

### File structure

```
.agents/skills/
├── component/
│   ├── SKILL.md
│   └── scripts/
├── wasm-toolchain/
│   ├── SKILL.md
│   └── scripts/      # wkg, wasm-tools binaries + cookbook .md files
├── wasmtime/
│   ├── SKILL.md
│   └── scripts/
├── wasm-build/
│   ├── SKILL.md
│   └── scripts/      # per-language cookbooks
├── just/
│   ├── SKILL.md
│   └── scripts/
└── hyperlight-sandbox/
    └── SKILL.md
```

## Requirements

The repo's `Justfile` has recipes for everything below. Quickest path:

```bash
just bootstrap-all   # rustup, uv, Node 22, Go 1.23 (idempotent)
just install-all     # core CLIs + all language component-build tools
```

Or install pieces one at a time as documented below.

### Core tools

| Tool       | One-liner                                  |
|------------|--------------------------------------------|
| `just`     | `brew install just` (or [releases](https://github.com/casey/just/releases)) — needed first to run any other recipe |
| `wasmtime` | `just install-wasmtime` (downloads release tarball) |
| `wasm-tools` | `just install-wasm-tools` (downloads release tarball) |
| `wkg`      | `just install-wkg` (downloads release tarball) |
| `component` | `just install-component` (builds from `yoshuawuyts/component-registry` main; needs Rust toolchain) |

### Language toolchains (for `wasm-build`)

Each language recipe assumes the base toolchain is on `$PATH`; install
the base toolchain first via the matching `bootstrap-*` recipe, then
run `install-*`:

| Language    | Base toolchain         | Component tools          |
|-------------|------------------------|--------------------------|
| Rust        | `just bootstrap-rust`  | `just install-rust-tools` (wasip1/wasip2 targets, wasm-tools, wit-bindgen-cli, cargo-component) |
| Python      | `just bootstrap-uv`    | `just install-py-tools` (componentize-py) |
| JavaScript  | `just bootstrap-node`  | `just install-js-tools` (jco, componentize-js — requires Node 20+) |
| Go (TinyGo) | `just bootstrap-go`    | `just install-go-tools` + `just install-tinygo` (also requires `wasm-tools` on `$PATH`) |

## Learn More

- [Agent Skills Standard](https://agentskills.io/)
- [VS Code Agent Skills](https://code.visualstudio.com/docs/copilot/customization/agent-skills)
- [`component` CLI (yoshuawuyts/component-registry)](https://github.com/yoshuawuyts/component-registry)
- [`wkg` (bytecodealliance/wasm-pkg-tools)](https://github.com/bytecodealliance/wasm-pkg-tools)
- [`wasm-tools` (bytecodealliance/wasm-tools)](https://github.com/bytecodealliance/wasm-tools)
- [`wasmtime` Documentation](https://docs.wasmtime.dev/)
- [WebAssembly Component Model](https://component-model.bytecodealliance.org/)
- [awesome-wasm-components](https://github.com/yoshuawuyts/awesome-wasm-components)

---

**Last Updated:** 2026-04-29
