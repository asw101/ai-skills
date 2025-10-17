# Claude Code Skills Overview

This repository contains project-level Claude Code skills designed to enhance development workflows with specialized tooling support.

## Available Skills

### just

**Location:** `.claude/skills/just/`

The `just` skill provides specialized assistance for working with the [just](https://github.com/casey/just) command runner and Justfiles.

**Capabilities:**
- List and explore available recipes in Justfiles
- Run recipes with appropriate arguments
- Show detailed recipe information
- Create and modify Justfiles
- Debug recipe errors and syntax issues
- Explain Justfile syntax and best practices

**Usage:** The skill automatically activates when you mention `just`, Justfiles, or build recipes.

**Local Binary:** Place a `just` binary in `.claude/skills/just/scripts/` to use a specific version instead of your system installation.

---

### wasmtime

**Location:** `.claude/skills/wasmtime/`

The `wasmtime` skill provides specialized assistance for working with WebAssembly components using the [wasmtime](https://wasmtime.dev/) runtime.

**Capabilities:**
- Run WebAssembly modules and components
- Inspect component structure and interfaces
- Configure WASI permissions (filesystem, environment, network)
- Debug WebAssembly execution issues
- Work with WIT (WebAssembly Interface Types) definitions
- Optimize component performance
- Support for both WASI 0.2 and 0.3 (in-progress)

**Usage:** The skill automatically activates when you mention WebAssembly, Wasm, `.wasm` files, wasmtime, WASI, or the Component Model.

**Local Binary:** Place a `wasmtime` binary in `.claude/skills/wasmtime/scripts/` to use a specific version instead of your system installation.

---

### awesome-wasm

**Location:** `.claude/skills/awesome-wasm/`

The `awesome-wasm` skill helps you discover and work with WebAssembly components from the [awesome-wasm-components](https://github.com/yoshuawuyts/awesome-wasm-components) collection.

**Capabilities:**
- Search for components suitable for specific tasks
- Browse components by category (Applications, Libraries, Interfaces)
- Download components from OCI registries
- Maintain a local component registry
- Provide integration guidance with bindings generators
- Explain component interfaces and use cases

**Component Categories:**
- **Applications:** HTTP servers and binary-shaped components
- **Libraries:** Reusable components (fetch, filesystem, weather, QR codes, etc.)
- **Interfaces:** Standard WASI interfaces and custom WIT definitions

**Local Registry:** The skill maintains a `components.json` file tracking available components, their registry URLs, use cases, and download status.

**Included Tools:** The skill includes Linux binaries for `wkg` and `wasm-tools` in its `scripts/` directory, so you can use the skill without installing these tools system-wide.

**Usage:** The skill automatically activates when you search for, discover, or ask about WebAssembly components from the awesome collection.

## How Skills Work

### Activation

Skills are automatically invoked by Claude Code when your requests match their trigger terms. You don't need to explicitly call them - just mention relevant topics:

- "List the recipes in my Justfile" → activates `just` skill
- "How do I run this .wasm file?" → activates `wasmtime` skill
- "Find a WebAssembly component for HTTP requests" → activates `awesome-wasm` skill

### Local Binaries

The `just`, `wasmtime`, and `awesome-wasm` skills support using local binaries:

**just & wasmtime skills:**
1. Place the binary in the skill's `scripts/` directory
2. Ensure it's executable (`chmod +x`)
3. The skill will automatically detect and use it

**awesome-wasm skill:**
- Includes Linux binaries for `wkg` and `wasm-tools` in `scripts/` directory
- These tools are used directly by the skill
- Can be replaced with custom versions if needed

**Benefits:**
- Version pinning for consistent behavior
- Team-wide version standardization
- Test against specific tool versions
- No system-wide installation required (especially for awesome-wasm tools)

**Note:** Local binaries are gitignored to prevent accidental commits.

### File Structure

```
.claude/skills/
├── just/
│   ├── SKILL.md           # Skill definition
│   └── scripts/
│       ├── README.md      # Binary setup instructions
│       └── just           # Optional local binary (gitignored)
├── wasmtime/
│   ├── SKILL.md           # Skill definition
│   └── scripts/
│       ├── README.md      # Binary setup instructions
│       └── wasmtime       # Optional local binary (gitignored)
└── awesome-wasm/
    ├── SKILL.md           # Skill definition
    ├── components.json    # Local component registry
    └── scripts/
        ├── wkg            # Included Linux binary (gitignored)
        └── wasm-tools     # Included Linux binary (gitignored)
```

## Getting Started

1. **Clone the repository** - Skills are project-level and included in this repo
2. **Restart Claude Code** - Skills load when Claude Code starts
3. **Start using them** - Just mention relevant topics in your requests
4. **Optional: Add local binaries** - Follow instructions in each skill's `scripts/README.md`

## Requirements

### System Tools

For the `just` and `wasmtime` skills, you can either:
- Install system-wide, OR
- Place binaries in their respective `scripts/` directories

**just:** `brew install just` or [download from releases](https://github.com/casey/just/releases)

**wasmtime:** `curl https://wasmtime.dev/install.sh -sSf | bash` or [download from releases](https://github.com/bytecodealliance/wasmtime/releases)

### Included Tools

The `awesome-wasm` skill includes these tools in its `scripts/` directory (Linux binaries):
- **wkg:** For downloading components from OCI registries
- **wasm-tools:** For inspecting and manipulating WebAssembly components

No installation required for awesome-wasm tools on Linux systems. On macOS/Windows, you may need to install these separately or use Docker/WSL.

### Optional Tools

- **Bindings generators:** For consuming WebAssembly components from various languages
- **wit-bindgen:** For generating language bindings from WIT definitions

## Learn More

- [Claude Code Skills Documentation](https://docs.claude.com/en/docs/claude-code/skills)
- [just Documentation](https://just.systems/)
- [wasmtime Documentation](https://docs.wasmtime.dev/)
- [WebAssembly Component Model](https://component-model.bytecodealliance.org/)
- [awesome-wasm-components Repository](https://github.com/yoshuawuyts/awesome-wasm-components)

## Contributing

To add or modify skills:

1. Edit skill definitions in `.claude/skills/*/SKILL.md`
2. Update documentation in `docs/`
3. Test by restarting Claude Code
4. Commit changes (binaries are gitignored automatically)

---

**Last Updated:** 2025-10-17
