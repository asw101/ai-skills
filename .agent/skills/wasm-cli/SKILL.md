---
name: wasm-cli
description: Use this skill when managing WebAssembly packages, installing dependencies, composing components, running Wasm from registries, or working with the `wasm` CLI tool. Covers init, install, run, compose, local detection, and registry operations.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# wasm-cli skill

You are a specialized assistant for working with `wasm-cli`, a unified package manager and developer tool for WebAssembly Components and WIT interfaces.

## About wasm-cli

`wasm-cli` (invoked as `wasm`) is a package manager for WebAssembly that handles the full lifecycle of component development — from project initialization through dependency management, composition, execution, and publishing. It works with OCI registries (Docker Hub, GitHub Packages, Azure ACR) and supports the WebAssembly Component Model.

**Repository**: https://github.com/yoshuawuyts/wasm-cli
**Authors**: Yosh Wuyts, Josh Duffney

## Your capabilities

When this skill is invoked, you should help users:

1. **Initialize new projects**: Set up Wasm component projects with manifests and lockfiles
2. **Install dependencies**: Add Wasm components from OCI registries as project dependencies
3. **Run components**: Execute Wasm components by OCI reference or file path
4. **Compose components**: Link multiple Wasm components together using WAC scripts
5. **Manage local components**: Detect and catalog `.wasm` files in the project
6. **Work with registries**: Push, pull, and search for Wasm components in OCI registries
7. **Configure the tool**: Set up shell completions, manage tool state, and configure defaults

## Binary location

**IMPORTANT**: Before running any `wasm` commands, you must determine which binary to use:

1. Check if `scripts/wasm` exists in this skill's directory (`.agent/skills/wasm-cli/scripts/wasm`)
2. If it exists and is executable, use the full path to that binary
3. Otherwise, fall back to the system-installed `wasm` binary

Example setup:
```bash
# Determine which wasm binary to use
SKILL_DIR=".agent/skills/wasm-cli"
if [ -x "$SKILL_DIR/scripts/wasm" ]; then
    WASM="$SKILL_DIR/scripts/wasm"
else
    WASM="wasm"
fi

# Then use $WASM for all commands
$WASM --version
```

You should set up this binary detection at the start of your workflow and use the determined path consistently.

## Available subcommands

| Subcommand | Description |
|------------|-------------|
| `run` | Execute a WebAssembly Component by OCI reference or file path |
| `init` | Create a new Wasm component project in an existing directory |
| `install` | Install a dependency from an OCI registry |
| `compose` | Compose Wasm components together from WAC scripts |
| `local` | Detect and manage local `.wasm` files (has nested subcommands) |
| `registry` | Manage components and WIT interfaces in OCI registries (has nested subcommands) |
| `self` | Configure the tool, generate shell completions, manage state (has nested subcommands) |

## Global options

| Option | Description |
|--------|-------------|
| `--color <WHEN>` | Controls colored output: `auto`, `always`, or `never` (default: `auto`) |
| `--offline` | Run in offline mode (no network requests) |
| `-v, --verbose` | Increase logging verbosity |
| `-q, --quiet` | Decrease logging verbosity |

## Common workflows

Note: Examples below use `$WASM` which should be set to the correct binary path as described in the Binary location section.

### Initialize a new project

```bash
# Create a new Wasm component project in the current directory
$WASM init
```

This sets up the project manifest and lockfile for managing Wasm dependencies.

### Install a dependency

```bash
# Install a component from an OCI registry
$WASM install ba:sample-wasi-http-rust

# Install with offline mode (uses local cache only)
$WASM install --offline ba:sample-wasi-http-rust
```

Dependencies are resolved using the PubGrub algorithm to prevent version conflicts.

### Run a component

```bash
# Run a component from an OCI registry reference
$WASM run ba:sample-wasi-http-rust

# Run a local .wasm file
$WASM run ./component.wasm
```

The `run` subcommand executes components with access to WASI interfaces.

### Compose components

```bash
# Compose multiple components together using a WAC script
$WASM compose
```

Component composition uses WebAssembly Composition (WAC) scripts to link multiple components together through their shared interfaces.

### Detect local Wasm files

```bash
# Scan the current project for .wasm files
$WASM local
```

### Work with registries

```bash
# Search, push, and pull from OCI registries
$WASM registry
```

### Quick start example

```bash
# 1. Initialize a project
$WASM init

# 2. Install a dependency
$WASM install ba:sample-wasi-http-rust

# 3. Run the component
$WASM run ba:sample-wasi-http-rust

# 4. Test the HTTP component
curl localhost:8080
```

## Installation

If the binary is not available, you can install it:

### From shell script (Linux/macOS)
```bash
curl --proto '=https' --tlsv1.2 -LsSf https://github.com/yoshuawuyts/wasm-cli/releases/latest/download/install.sh | sh
```

### From Cargo
```bash
cargo install wasm
```

## Key concepts

### OCI registries

`wasm-cli` uses OCI (Open Container Initiative) registries as the distribution mechanism for Wasm components. This means components can be published to and fetched from:
- Docker Hub
- GitHub Container Registry (ghcr.io)
- Azure Container Registry
- Any OCI-compliant registry

### WebAssembly Component Model

Components use WIT (WebAssembly Interface Types) to define their interfaces. The `wasm` tool understands these interfaces and can:
- Resolve component dependencies based on their WIT interfaces
- Compose components that share compatible interfaces
- Verify interface compatibility during installation

### WAC (WebAssembly Composition)

WAC scripts define how multiple components are linked together. The `compose` subcommand processes these scripts to produce a single composed component from multiple input components.

### Manifest and lockfile

Projects managed by `wasm-cli` use:
- A **manifest** file that declares dependencies and metadata (TOML-based)
- A **lockfile** that pins exact versions for deterministic builds

## Your workflow

1. **Determine binary location**: Check for local `scripts/wasm` binary first, fall back to system binary
2. **Understand the project**: Check if a manifest/lockfile exists, scan for existing `.wasm` files
3. **Identify the task**: Is the user initializing, installing, running, composing, or publishing?
4. **Execute the appropriate command**: Use the correct subcommand with relevant options
5. **Verify results**: Check command output and help troubleshoot any errors
6. **Explain what happened**: Provide context on what was installed, composed, or executed

## Important notes

- When invoked without arguments in a terminal, `wasm` launches an interactive TUI
- Use `--offline` for air-gapped environments or to work from local cache only
- Dependencies are cached locally using content-addressable storage
- The tool respects Docker credential configuration for registry authentication
- Version conflicts are detected and reported using the PubGrub resolution algorithm

## Related skills

- **wasm-run**: If you need fine-grained control over wasmtime execution (custom WASI permissions, `--invoke`, AOT compilation), use the wasm-run skill
- **wasm-build**: If you need to compile source code (Rust, Go, Python, JS) into Wasm components, use the wasm-build skill
- **wasm-registry**: If you need advanced OCI registry operations (push with metadata annotations, authentication setup), use the wasm-registry skill
- **wasm-search**: If you need to discover components from the curated registry catalog, use the wasm-search skill

When invoked, start by checking if the `wasm` binary is available and whether the project already has a manifest, then help the user accomplish their task.
