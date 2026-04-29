---
name: component-cli
description: Use this skill when managing WebAssembly packages, installing dependencies, composing components, running Wasm from registries, or working with the `component` CLI tool. Covers init, install, run, compose, local, registry, and self operations.
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
3. **Run components**: Execute Wasm components by OCI reference, file path, or manifest key
4. **Compose components**: Build composite components from `.wac` scripts
5. **Manage local components**: List `.wasm` files and clean lockfile/vendored deps
6. **Work with registries**: Search, pull, push, inspect, and manage components in OCI registries
7. **Configure the tool**: View config/state/logs, generate shell completions and man pages, clean storage

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

## Top-level subcommands

| Subcommand | Description |
|------------|-------------|
| `run` | Execute a Wasm Component (OCI ref, file path, or manifest key) |
| `init` | Create a new Wasm component in an existing directory |
| `install` | Install a dependency from an OCI registry |
| `compose` | Compose Wasm components from WAC scripts |
| `local` | Detect and manage local `.wasm` files (nested) |
| `registry` | Manage components and WIT interfaces in OCI registries (nested) |
| `self` | Configure the tool, generate completions, manage state (nested) |
| `help` | Print help for any subcommand |

## Global options

Available on every command:

| Option | Description |
|--------|-------------|
| `--color <WHEN>` | Colored output: `auto`, `always`, `never` (default: `auto`) |
| `--offline` | Run in offline mode (no network requests) |
| `-v, --verbose` | Increase logging verbosity (repeatable) |
| `-q, --quiet` | Decrease logging verbosity (repeatable) |
| `-h, --help` | Print help |
| `-V, --version` | Print version |

## Workflows

Examples below use `$COMPONENT`, set per the Binary location section.

### `init` — start a new project

```bash
$COMPONENT init           # initialize in current directory
$COMPONENT init ./my-app  # initialize in specified directory
```

Sets up the project manifest and lockfile.

### `install` — add dependencies

```bash
# Install a specific component (OCI reference or scope:component manifest key)
$COMPONENT install ghcr.io/webassembly/wasi-logging:1.0.0
$COMPONENT install wasi:logging

# With no arguments, installs every package listed in the manifest
$COMPONENT install

# Use the local cache only (no network)
$COMPONENT install --offline wasi:logging
```

### `run` — execute a component

`run` accepts a local file path, an OCI reference, or a manifest key (`scope:component`).

| Option | Description |
|--------|-------------|
| `--env <KEY=VAL>` | Pass an env var to the guest (repeatable) |
| `--dir <HOST_PATH>` | Pre-open a host directory for the guest (repeatable) |
| `--inherit-env` | Inherit all host environment variables |
| `--inherit-network` | Allow the guest to access the network |
| `--no-stdio` | Suppress stdin/stdout/stderr inheritance |
| `--listen <ADDR>` | Bind address for `wasi:http/proxy` components (default `127.0.0.1:8080`) |
| `-g, --global` | Run from the global cache, bypassing local installation |

```bash
# Local file
$COMPONENT run ./component.wasm

# OCI reference
$COMPONENT run ghcr.io/example/hello:latest

# Manifest key
$COMPONENT run wasi:http-rust

# With guest env vars and a pre-opened directory
$COMPONENT run --env LOG=debug --dir ./data ./component.wasm

# HTTP component on a custom port, with network access
$COMPONENT run --listen 0.0.0.0:9000 --inherit-network ./server.wasm
```

### `compose` — build composite components from WAC

`compose` reads `.wac` (WebAssembly Composition) scripts from a `seams/` directory in the project.

| Option | Description |
|--------|-------------|
| `--linker <static\|dynamic>` | `static`: embed all deps (default). `dynamic`: import them |
| `-o, --output <OUTPUT>` | Output path for the composed component (default `build`) |

```bash
# Compose seams/foo.wac → build/foo.wasm
$COMPONENT compose foo

# Compose every .wac file in seams/
$COMPONENT compose

# Dynamic linking, custom output dir
$COMPONENT compose --linker dynamic -o dist foo
```

### `local` — work with local `.wasm` files

| Sub-subcommand | Description |
|----------------|-------------|
| `list [PATH]` | List `.wasm` files (defaults to `.`) |
| `clean [PATH]` | Remove the lockfile and vendored dependencies |

`local list` options: `--hidden` (include dotfiles/dirs), `--follow-links`.

```bash
$COMPONENT local list                        # scan current directory
$COMPONENT local list --hidden ./build       # include hidden files
$COMPONENT local clean                       # wipe lockfile + vendored deps here
```

### `registry` — OCI registry operations

| Sub-subcommand | Description |
|----------------|-------------|
| `search [QUERY]` | Search packages across configured registries |
| `pull <REFERENCE>` | Pull a component from the registry |
| `push` | Push a component to a registry |
| `show` | Fetch OCI metadata for a component |
| `inspect <REFERENCE>` | Inspect package metadata on the registry |
| `tags <REFERENCE>` | List available tags for a component |
| `list` | List all installed packages |
| `known` | List all packages previously synced or pulled |
| `sync` | Force-sync the index from the configured meta-registry |
| `delete <REFERENCE>` | Delete a package from the local store |

Notable options:
- `registry search`: `--exports <iface>`, `--imports <iface>`, `--limit <N>` (default 20)
- `registry inspect`: `--json`
- `registry tags`: `--signatures` (include `.sig` tags), `--attestations` (include `.att` tags)
- `registry known`: `--limit <N>` (default 100)

```bash
# Find packages that export wasi:http
$COMPONENT registry search --exports wasi:http --limit 10

# Inspect a specific package as JSON
$COMPONENT registry inspect ghcr.io/example/hello:1.0.0 --json

# List tags including signatures and attestations
$COMPONENT registry tags ghcr.io/example/hello --signatures --attestations

# Sync the meta-registry index, then list known packages
$COMPONENT registry sync
$COMPONENT registry known --limit 50

# Local store operations
$COMPONENT registry list                              # what's installed
$COMPONENT registry delete ghcr.io/example/old:1.0.0  # remove from local store

# Pull / push
$COMPONENT registry pull ghcr.io/example/hello:1.0.0
$COMPONENT registry push
```

### `self` — tool configuration and diagnostics

| Sub-subcommand | Description |
|----------------|-------------|
| `state` | Print diagnostics about the local state |
| `config` | Show config file location and current settings |
| `log` | Show the application log file |
| `completions <SHELL>` | Generate shell completions (bash, elvish, fish, powershell, zsh) |
| `man-pages` | Generate a man page for the CLI |
| `clean` | Clean up storage (remove all data, images, metadata) |

`self log` options: `-f, --follow` (tail like `tail -f`), `-n, --lines <N>`.

```bash
$COMPONENT self state                  # diagnostics
$COMPONENT self config                 # where is config, what's loaded
$COMPONENT self log -f                 # stream the log
$COMPONENT self log -n 100             # last 100 lines
$COMPONENT self completions zsh > ~/.zfunc/_component
$COMPONENT self man-pages              # generate man pages
$COMPONENT self clean                  # nuke local store (destructive)
```

### Quick start example

```bash
# 1. Initialize a project
$COMPONENT init

# 2. Install a dependency (manifest key form)
$COMPONENT install wasi:http-rust

# 3. Run the component
$COMPONENT run wasi:http-rust

# 4. Test the HTTP component
curl localhost:8080
```

## Installation

If the binary is not available, install from source (requires Rust toolchain):

```bash
cargo install --git https://github.com/yoshuawuyts/component-cli component
mkdir -p .agents/skills/component-cli/scripts
cp "$HOME/.cargo/bin/component" .agents/skills/component-cli/scripts/component
```

**Note**: `cargo install component` (from crates.io) does NOT work — the `component` crate on crates.io is an unrelated package. You must install from the git repository.

## Key concepts

### OCI registries

`component-cli` uses OCI (Open Container Initiative) registries as the distribution mechanism for Wasm components. Components can be published to and fetched from:
- Docker Hub
- GitHub Container Registry (ghcr.io)
- Azure Container Registry
- Any OCI-compliant registry

Registry authentication respects Docker credential configuration.

### References (three forms accepted by `run` / `install`)

- **Local file path**: `./component.wasm`
- **OCI reference**: `ghcr.io/example/hello:1.0.0`
- **Manifest key**: `scope:component` (e.g. `wasi:logging`) — resolved against the project manifest

### WAC composition

`compose` reads `.wac` (WebAssembly Composition) scripts from a `seams/` directory and produces a single composite `.wasm` artifact. Use `--linker static` to embed dependencies (default) or `--linker dynamic` to import them at runtime.

### WebAssembly Component Model

Components use WIT (WebAssembly Interface Types) to define their interfaces. The `component` tool understands these interfaces and can resolve dependencies and verify interface compatibility during installation.

### Manifest and lockfile

Projects managed by `component-cli` use:
- A **manifest** (TOML) declaring dependencies and metadata
- A **lockfile** pinning exact versions for deterministic builds

`component local clean` removes both the lockfile and vendored dependencies for a fresh install.

## Your workflow

1. **Determine binary location**: Check `scripts/component` first, fall back to system binary
2. **Understand the project**: Check if a manifest/lockfile exists, scan for `.wasm` files (`component local list`)
3. **Identify the task**: init / install / run / compose / publish?
4. **Execute**: Use the right subcommand and options
5. **Verify**: Check output and help troubleshoot
6. **Explain**: Provide context on what was installed, composed, or executed

## Important notes

- Use `--offline` for air-gapped environments or to work from local cache only
- Dependencies are cached locally using content-addressable storage
- Registry authentication respects Docker credential configuration
- `component self clean` and `component registry delete` are destructive — confirm before invoking
- For HTTP components (`wasi:http/proxy`), `run --listen <ADDR>` controls the bind address; combine with `--inherit-network` for outbound network access

When invoked, start by checking if the `component` binary is available and whether the project already has a manifest, then help the user accomplish their task.
