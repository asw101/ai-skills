# Agent Skills Overview

This repository contains project-level agent skills for WebAssembly component development. These skills work with VS Code Copilot, Claude Code, and other agents supporting the [Agent Skills standard](https://agentskills.io/).

## Available Skills

### wasm-run

**Location:** `.agents/skills/wasm-run/`
**Invoke:** `/wasm-run`

Run and debug WebAssembly components using the [wasmtime](https://wasmtime.dev/) runtime.

**Capabilities:**
- Run WebAssembly modules and components
- Inspect component structure and interfaces
- Configure WASI permissions (filesystem, environment, network)
- Debug WebAssembly execution issues
- Work with WIT (WebAssembly Interface Types) definitions

**Example:** `/wasm-run` then "Run csv-groupby.wasm with the test data"

---

### wasm-build

**Location:** `.agents/skills/wasm-build/`
**Invoke:** `/wasm-build`

Build WebAssembly components from Rust, Python, JavaScript, or Go source code.

**Capabilities:**
- Scaffold new component projects with WIT definitions
- Build components using WASI preview 2
- Validate WIT interfaces and component structure
- Manage language-specific toolchains
- Optimize for size and performance

**Example:** `/wasm-build` then "Create a new Rust component that processes JSON"

---

### wasm-search

**Location:** `.agents/skills/wasm-search/`
**Invoke:** `/wasm-search`

Discover and integrate pre-built components from [awesome-wasm-components](https://github.com/yoshuawuyts/awesome-wasm-components).

**Capabilities:**
- Search for components by functionality
- Browse by category (Applications, Libraries, Interfaces)
- Download components from OCI registries
- Provide integration guidance

**Example:** `/wasm-search` then "Find an HTTP client component"

---

### wasm-registry

**Location:** `.agents/skills/wasm-registry/`
**Invoke:** `/wasm-registry`

Push and pull WebAssembly components to/from OCI registries (GitHub Container Registry).

**Capabilities:**
- Authenticate with GHCR
- Push components with metadata annotations
- Pull components from registries
- Manage versioning and tags

**Example:** `/wasm-registry` then "Publish my-component.wasm to ghcr.io"

---

### just

**Location:** `.agents/skills/just/`
**Invoke:** `/just`

Work with the [just](https://github.com/casey/just) command runner and Justfiles.

**Capabilities:**
- List and run recipes
- Create and modify Justfiles
- Debug recipe errors
- Explain Justfile syntax

**Example:** `/just` then "Show me all available recipes"

---

## How Skills Work

### Invocation

Skills are explicitly invoked using slash commands:

```
/wasm-run
/wasm-build
/wasm-search
/wasm-registry
/just
```

After invoking a skill, describe what you want to do. The skill provides specialized context and capabilities for that domain.

### Local Binaries

Skills can use local binaries from their `scripts/` directory:

1. Place the binary in the skill's `scripts/` directory
2. Ensure it's executable (`chmod +x`)
3. The skill will prefer local binaries over system installations

**Benefits:**
- Version pinning for consistent behavior
- Team-wide standardization
- No system-wide installation required

### File Structure

```
.agents/skills/
├── wasm-run/
│   ├── SKILL.md
│   └── scripts/
├── wasm-build/
│   └── SKILL.md
├── wasm-search/
│   ├── SKILL.md
│   ├── components.json
│   └── scripts/
├── wasm-registry/
│   ├── SKILL.md
│   └── scripts/
│       └── run-wkg.sh
└── just/
    ├── SKILL.md
    └── scripts/
```

## Requirements

The repo's `Justfile` has recipes for everything below. Quickest path:

```bash
just bootstrap-all   # rustup, uv, Node 22, Go 1.23 (idempotent)
just install-all     # core CLIs + all language component-build tools
```

Or install pieces one at a time as documented below.

### Core Tools

| Tool       | One-liner                                  |
|------------|--------------------------------------------|
| just       | `brew install just` (or [releases](https://github.com/casey/just/releases)) — needed first to run any other recipe |
| wasmtime   | `just install-wasmtime` (downloads release tarball) |
| wasm-tools | `just install-wasm-tools` (downloads release tarball — no Rust toolchain needed) |
| wkg        | `just install-wkg` (downloads release tarball) |

### Language Toolchains (for wasm-build)

Each language recipe assumes the base toolchain is on PATH; install the base
toolchain first via the matching `bootstrap-*` recipe, then run `install-*`:

| Language    | Base toolchain         | Component tools          |
|-------------|------------------------|--------------------------|
| Rust        | `just bootstrap-rust`  | `just install-rust-tools` (adds wasip1/wasip2 targets, wasm-tools, wit-bindgen-cli, cargo-component) |
| Python      | `just bootstrap-uv`    | `just install-py-tools` (componentize-py) |
| JavaScript  | `just bootstrap-node`  | `just install-js-tools` (jco, componentize-js — requires Node 20+) |
| Go (TinyGo) | `just bootstrap-go`    | `just install-go-tools` + `just install-tinygo` (also requires `wasm-tools` on PATH) |

## Learn More

- [Agent Skills Standard](https://agentskills.io/)
- [VS Code Agent Skills](https://code.visualstudio.com/docs/copilot/customization/agent-skills)
- [wasmtime Documentation](https://docs.wasmtime.dev/)
- [WebAssembly Component Model](https://component-model.bytecodealliance.org/)
- [awesome-wasm-components](https://github.com/yoshuawuyts/awesome-wasm-components)

---

**Last Updated:** 2026-01-19
