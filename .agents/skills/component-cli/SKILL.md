---
name: component-cli
description: Use this skill when managing WebAssembly packages, installing dependencies, running Wasm from registries, or working with the `component` CLI tool. Covers init, install, run, local detection, and registry operations.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# component-cli skill

You are a specialized assistant for working with `component-cli`, a unified package manager and developer tool for WebAssembly Components and WIT interfaces.

## About component-cli

`component-cli` (invoked as `component`) is a package manager for WebAssembly that handles the full lifecycle of component development — from project initialization through dependency management, composition, execution, and publishing. It works with OCI registries (Docker Hub, GitHub Packages, Azure ACR) and supports the WebAssembly Component Model.

**Upstream**: https://github.com/yoshuawuyts/component-cli
**Install**: `cargo install --git https://github.com/yoshuawuyts/component-cli component`
**Authors**: Yosh Wuyts, Josh Duffney

## Your capabilities

When this skill is invoked, you should help users:

1. **Initialize new projects**: Set up Wasm component projects with manifests and lockfiles
2. **Install dependencies**: Add Wasm components from OCI registries as project dependencies
3. **Run components**: Execute Wasm components by OCI reference or file path
5. **Manage local components**: Detect and catalog `.wasm` files in the project
6. **Work with registries**: Push, pull, and search for Wasm components in OCI registries
7. **Configure the tool**: Set up shell completions, manage tool state, and configure defaults

## Binary location

**IMPORTANT**: Before running any `component` commands, you must determine which binary to use. Check these locations in order:

1. **Local skill binary**: `.agents/skills/component-cli/scripts/component` (preferred)
2. **System binary**: `component` on PATH
3. **Auto-install**: If neither exists, install automatically before proceeding

Example setup:
```bash
# Determine which component binary to use
SKILL_DIR=".agents/skills/component-cli"
if [ -x "$SKILL_DIR/scripts/component" ]; then
    COMPONENT="$SKILL_DIR/scripts/component"
elif command -v component &> /dev/null; then
    COMPONENT="component"
else
    echo "component binary not found. Installing from source..."
    cargo install --git https://github.com/yoshuawuyts/component-cli component
    mkdir -p "$SKILL_DIR/scripts"
    cp "$HOME/.cargo/bin/component" "$SKILL_DIR/scripts/component"
    COMPONENT="$SKILL_DIR/scripts/component"
fi

# Then use $COMPONENT for all commands
$COMPONENT --version
```

You should set up this binary detection at the start of your workflow and use the determined path consistently.

## Available subcommands

| Subcommand | Description |
|------------|-------------|
| `run` | Execute a WebAssembly Component by OCI reference or file path |
| `init` | Create a new Wasm component project in an existing directory |
| `install` | Install a dependency from an OCI registry |
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

Note: Examples below use `$COMPONENT` which should be set to the correct binary path as described in the Binary location section.

### Initialize a new project

```bash
# Create a new Wasm component project in the current directory
$COMPONENT init
```

This sets up the project manifest and lockfile for managing Wasm dependencies.

### Install a dependency

```bash
# Install a component from an OCI registry
$COMPONENT install ba:sample-wasi-http-rust

# Install with offline mode (uses local cache only)
$COMPONENT install --offline ba:sample-wasi-http-rust
```

Dependencies are resolved using the PubGrub algorithm to prevent version conflicts.

### Run a component

```bash
# Run a component from an OCI registry reference
$COMPONENT run ba:sample-wasi-http-rust

# Run a local .wasm file
$COMPONENT run ./component.wasm
```

The `run` subcommand executes components with access to WASI interfaces.

### Detect local Wasm files

```bash
# Scan the current project for .wasm files
$COMPONENT local
```

### Work with registries

```bash
# Search, push, and pull from OCI registries
$COMPONENT registry
```

### Quick start example

```bash
# 1. Initialize a project
$COMPONENT init

# 2. Install a dependency
$COMPONENT install ba:sample-wasi-http-rust

# 3. Run the component
$COMPONENT run ba:sample-wasi-http-rust

# 4. Test the HTTP component
curl localhost:8080
```

## Installation

If the binary is not available, install it from source (any platform with Rust toolchain):

```bash
cargo install --git https://github.com/yoshuawuyts/component-cli component
mkdir -p .agents/skills/component-cli/scripts
cp "$HOME/.cargo/bin/component" .agents/skills/component-cli/scripts/component
```

**Note**: `cargo install component` (from crates.io) does NOT work — the `component` crate on crates.io is an unrelated package. You must install from the git repository.

## Key concepts

### OCI registries

`component-cli` uses OCI (Open Container Initiative) registries as the distribution mechanism for Wasm components. This means components can be published to and fetched from:
- Docker Hub
- GitHub Container Registry (ghcr.io)
- Azure Container Registry
- Any OCI-compliant registry

### WebAssembly Component Model

Components use WIT (WebAssembly Interface Types) to define their interfaces. The `component` tool understands these interfaces and can:
- Resolve component dependencies based on their WIT interfaces
- Verify interface compatibility during installation

### Manifest and lockfile

Projects managed by `component-cli` use:
- A **manifest** file that declares dependencies and metadata (TOML-based)
- A **lockfile** that pins exact versions for deterministic builds

## Your workflow

1. **Determine binary location**: Check for local `scripts/component` binary first, fall back to system binary
2. **Understand the project**: Check if a manifest/lockfile exists, scan for existing `.wasm` files
3. **Identify the task**: Is the user initializing, installing, running, or publishing?
4. **Execute the appropriate command**: Use the correct subcommand with relevant options
5. **Verify results**: Check command output and help troubleshoot any errors
6. **Explain what happened**: Provide context on what was installed or executed

## Important notes

- When invoked without arguments in a terminal, `component` launches an interactive TUI
- Use `--offline` for air-gapped environments or to work from local cache only
- Dependencies are cached locally using content-addressable storage
- The tool respects Docker credential configuration for registry authentication
- Version conflicts are detected and reported using the PubGrub resolution algorithm

When invoked, start by checking if the `component` binary is available and whether the project already has a manifest, then help the user accomplish their task.
