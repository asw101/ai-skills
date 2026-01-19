# Claude Code Skills Overview

This repository contains project-level Claude Code skills for WebAssembly component development.

## Available Skills

### wasm-run

**Location:** `.claude/skills/wasm-run/`
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

**Location:** `.claude/skills/wasm-build/`
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

**Location:** `.claude/skills/wasm-search/`
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

**Location:** `.claude/skills/wasm-registry/`
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

**Location:** `.claude/skills/just/`
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
.claude/skills/
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

### Core Tools

- **wasmtime:** `curl https://wasmtime.dev/install.sh -sSf | bash`
- **wasm-tools:** `cargo install wasm-tools`
- **wkg:** Download from [wasm-pkg-tools releases](https://github.com/bytecodealliance/wasm-pkg-tools/releases)
- **just:** `brew install just` or [download](https://github.com/casey/just/releases)

### Language Toolchains (for wasm-build)

- **Rust:** `rustup target add wasm32-wasip2 && cargo install cargo-component`
- **Python:** `pip install componentize-py`
- **JavaScript:** `npm install -g @bytecodealliance/jco @bytecodealliance/componentize-js`
- **Go:** `brew install tinygo` + `go install github.com/bytecodealliance/wit-bindgen-go/cmd/wit-bindgen-go@latest`

## Learn More

- [Claude Code Skills Documentation](https://docs.anthropic.com/en/docs/claude-code)
- [wasmtime Documentation](https://docs.wasmtime.dev/)
- [WebAssembly Component Model](https://component-model.bytecodealliance.org/)
- [awesome-wasm-components](https://github.com/yoshuawuyts/awesome-wasm-components)

---

**Last Updated:** 2026-01-19
