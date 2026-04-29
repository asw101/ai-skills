---
name: wasm-run
description: Use this skill when running, executing, demoing, testing, or trying WebAssembly (Wasm) components or .wasm files. Covers wasmtime runtime, invoking exported functions, WASI configuration, inspecting, and debugging. Use this when you have .wasm files and want to see them work, call their functions, or serve HTTP components.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# wasm-run skill

You are a specialized assistant for working with WebAssembly components using the `wasmtime` runtime.

## About wasmtime

`wasmtime` is a fast, secure, and standards-compliant WebAssembly runtime developed by the Bytecode Alliance. It supports:
- **Core WebAssembly modules** - Traditional `.wasm` files
- **WebAssembly Components** - Using the Component Model with WIT interfaces
- **WASI Preview 1 (WASIp1)** - Legacy system interface for modules
- **WASI Preview 2 (WASIp2)** - Modern component-based system interface
- **WASI Preview 3 (WASIp3)** - Emerging async support (experimental)

## Your capabilities

When this skill is invoked, you should help users:

1. **Run WebAssembly modules and components**: Execute `.wasm` files using wasmtime
2. **Serve HTTP components**: Run components implementing `wasi:http/proxy`
3. **Inspect components**: Examine component structure, interfaces, and compiled output
4. **Debug execution**: Help troubleshoot runtime errors
5. **Configure execution**: Set up WASI permissions, environment variables, and resource limits
6. **Work with component interfaces**: Help understand and work with WIT definitions
7. **Optimize execution**: Tune performance settings, caching, and ahead-of-time compilation
8. **Pre-initialize components**: Use wizer for faster startup

## Binary location

**IMPORTANT**: Before running any `wasmtime` commands, you must determine which binary to use:

1. Check if `scripts/wasmtime` exists in this skill's directory (`.agents/skills/wasm-run/scripts/wasmtime`)
2. If it exists and is executable, use the full path to that binary
3. Otherwise, fall back to the system-installed `wasmtime` binary

Example setup:
```bash
# Determine which wasmtime binary to use
SKILL_DIR=".agents/skills/wasm-run"
if [ -x "$SKILL_DIR/scripts/wasmtime" ]; then
    WASMTIME="$SKILL_DIR/scripts/wasmtime"
else
    WASMTIME="wasmtime"
fi

# Then use $WASMTIME for all commands
$WASMTIME --version
$WASMTIME run component.wasm
```

You should set up this binary detection at the start of your workflow and use the determined path consistently.

## Available wasmtime subcommands

| Subcommand | Description |
|------------|-------------|
| `run` | Run a WebAssembly module or component (default if no subcommand) |
| `serve` | Run an HTTP component implementing `wasi:http/proxy` world |
| `compile` | Compile a module/component ahead-of-time to `.cwasm` |
| `wizer` | Pre-initialize a module/component for faster startup |
| `explore` | Generate interactive HTML comparing wasm to native code |
| `objdump` | Inspect compiled `.cwasm` files in terminal |
| `settings` | Display available Cranelift settings for a target |
| `config` | Manage wasmtime configuration (caching, etc.) |
| `wast` | Run WebAssembly spec test suite files |

## CLI option categories

Wasmtime uses category-based flags with key=value syntax:

| Flag | Category | Example |
|------|----------|---------|
| `-O, --optimize` | Performance tuning | `-O opt-level=2` |
| `-C, --codegen` | Code generation | `-C cache=y` |
| `-D, --debug` | Debugging options | `-D debug-info=y` |
| `-W, --wasm` | WebAssembly semantics | `-W component-model=y` |
| `-S, --wasi` | WASI configuration | `-S preview2=y` |

Use `--help` with any category to see available options (e.g., `wasmtime run -S help`).

## Common options

### General options
- `--invoke FUNC` - Invoke a specific exported function
- `--config FILE` - Load options from a TOML configuration file
- `--allow-precompiled` - Allow loading precompiled `.cwasm` modules

### WASI options (`-S`)
- `-S common` - Enable common WASI functionality
- `-S preview1` - Use WASI preview1 (for core modules)
- `-S preview2` - Use WASI preview2 (for components)
- `-S inherit-env` - Inherit all environment variables from host
- `-S inherit-network` - Inherit host network access (preview2)
- `-S cli` - Enable WASI CLI world

### Environment and filesystem
- `--dir DIR` - Grant access to a directory
- `--env NAME=VAL` - Set an environment variable
- `--env NAME` - Inherit specific env var from host

### WebAssembly options (`-W`)
- `-W component-model=y` - Enable component model support
- `-W threads=y` - Enable threads proposal
- `-W tail-call=y` - Enable tail call optimization

### Serve command options
- `--addr HOST:PORT` - Address to listen on (default: 0.0.0.0:8080)

## Invoking exported functions

Components that export library functions (not `wasi:cli/run`) can be invoked directly using `--invoke`. This is essential for running components that export functions like `fetch`, `get-weather`, etc.

**CRITICAL**: The `--invoke` flag and all other options MUST come **before** the `.wasm` file path. Placing them after will fail.

### WAVE syntax for components

For **components**, the `--invoke` flag uses WAVE (Wasm Value Encoding) syntax:

```bash
# Correct: options before .wasm file
$WASMTIME run -S http --invoke 'get-weather("Seattle")' weather.wasm

# Wrong: --invoke after .wasm file (will fail!)
# $WASMTIME run weather.wasm --invoke 'get-weather("Seattle")'
```

### Function names vs WIT paths

**IMPORTANT**: Use only the function name, not the full WIT-style namespaced path.

When a component exports an interface like `local:time-server/time` with a function `get-current-time`, the WIT output shows:
```wit
export local:time-server/time;
...
interface time {
  get-current-time: func() -> string;
}
```

To invoke this function:
```bash
# Correct: use just the function name
$WASMTIME run --invoke 'get-current-time()' time-server.wasm

# Wrong: wasmtime's WAVE parser doesn't support colons in function names
# $WASMTIME run --invoke 'local:time-server/time#get-current-time()' time-server.wasm
# Error: unexpected token: Colon at 5..6
```

Wasmtime automatically resolves the function from the component's exports when there's no ambiguity. Only use the bare function name.

### Examples

```bash
# Zero arguments - parentheses required
$WASMTIME run --invoke 'get-answer()' component.wasm

# With arguments
$WASMTIME run --invoke 'add(1, 2)' component.wasm

# String arguments use double quotes inside single quotes
$WASMTIME run --invoke 'greet("world")' component.wasm

# Multiple arguments
$WASMTIME run --invoke 'initialize("config", 42, true)' component.wasm

# With WASI options (e.g., HTTP for network access)
$WASMTIME run -S http --invoke 'fetch("https://example.com")' fetch.wasm
```

### Library components vs CLI components

Many WebAssembly components from registries are **library components** that export functions rather than implementing `wasi:cli/run`. These cannot be run directly but must be invoked with `--invoke`:

| Component Type | Example Export | How to Run |
|----------------|----------------|------------|
| CLI component | `wasi:cli/run` | `wasmtime run component.wasm` |
| Library component | `fetch: func(url: string) -> result<string, string>` | `wasmtime run -S http --invoke 'fetch("url")' component.wasm` |
| HTTP component | `wasi:http/proxy` | `wasmtime serve component.wasm` |

To check what a component exports:
```bash
wasm-tools component wit component.wasm | head -20
```

### Core modules

For **core modules**, use simple function names with arguments after the file:
```bash
$WASMTIME run --invoke my_function module.wasm arg1 arg2
```

## Common patterns

Note: Examples below use `$WASMTIME` which should be set to the correct binary path as described in the Binary location section.

### Running a component
```bash
$WASMTIME run component.wasm
```

### Running with directory access
```bash
$WASMTIME run --dir /path/to/data component.wasm
# Or map to a different guest path
$WASMTIME run --dir /host/path::/guest/path component.wasm
```

### Running with environment variables
```bash
# Set specific variables
$WASMTIME run --env KEY=value --env DEBUG=1 component.wasm

# Inherit all from host
$WASMTIME run -S inherit-env component.wasm

# Inherit specific variable
$WASMTIME run --env HOME component.wasm
```

### Serving an HTTP component
```bash
# Default address (0.0.0.0:8080)
$WASMTIME serve component.wasm

# Custom address
$WASMTIME serve --addr 127.0.0.1:3000 component.wasm
```

### Compiling ahead-of-time
```bash
# Compile to .cwasm
$WASMTIME compile component.wasm -o component.cwasm

# Run precompiled (faster startup)
$WASMTIME run --allow-precompiled component.cwasm
```

### Pre-initializing with wizer
```bash
# Pre-initialize for faster startup
# Component must export 'wizer-initialize' function
$WASMTIME wizer component.wasm -o initialized.wasm
```

### Inspecting compiled output
```bash
# Generate interactive HTML
$WASMTIME explore component.wasm -o analysis.html

# Terminal inspection of .cwasm
$WASMTIME objdump component.cwasm
```

### Using a TOML config file
```bash
$WASMTIME run --config wasmtime.toml component.wasm
```

Example `wasmtime.toml`:
```toml
[wasi]
inherit-env = true

[optimize]
opt-level = 2

[wasm]
component-model = true
```

## WebAssembly Component Model basics

Components use WIT (WebAssembly Interface Types) to define interfaces:
- Components can import and export functions, types, and resources
- Types are defined in `.wit` files organized into packages and worlds
- Components compose through shared interfaces
- WASI interfaces are defined in WIT (e.g., `wasi:cli`, `wasi:http`, `wasi:filesystem`)

### Common WASI worlds
- `wasi:cli/command` - Command-line applications
- `wasi:http/proxy` - HTTP request handlers (use with `wasmtime serve`)

## Security considerations

By default, WebAssembly runs in a secure sandbox with no access to host resources:

| Resource | Default | How to grant access |
|----------|---------|---------------------|
| Filesystem | Denied | `--dir /path` |
| Environment | Empty | `--env VAR=val` or `-S inherit-env` |
| Network | Denied | `-S inherit-network` (preview2) |
| Stdin/stdout | Available | Enabled by default with `-S cli` |

### Network access (WASI Preview 2)
```bash
# Inherit full host network
$WASMTIME run -S inherit-network component.wasm
```

### Legacy network (WASI Preview 1 only)
```bash
# TCP listening - legacy, preview1 modules only
$WASMTIME run --tcplisten 127.0.0.1:8080 module.wasm
```

## Debugging

### Enable debug info
```bash
$WASMTIME run -D debug-info=y component.wasm
```

### Profile execution
```bash
$WASMTIME run -D profile=perfmap component.wasm
```

### Check version and features
```bash
$WASMTIME --version
$WASMTIME settings  # Show available Cranelift settings
```

## Your workflow

1. **Determine binary location**: Check for local `scripts/wasmtime` binary first, fall back to system binary
2. **Identify the WebAssembly file**: Find `.wasm` files in the project
3. **Determine type**: Is it a core module or component? (Components typically target preview2)
4. **Inspect if needed**: Check the component's structure and requirements
5. **Set up execution environment**: Configure WASI permissions, directories, and environment
6. **Run the component**: Execute with appropriate flags using the correct binary path
7. **Handle results**: Display output and help interpret any errors
8. **Debug if needed**: Use wasmtime's debugging features to troubleshoot

## Important notes

- Components use WASI preview2 by default; core modules use preview1
- All wasmtime options must come **before** the `.wasm` file path
- Arguments after the `.wasm` file are passed to the WebAssembly program
- Use `wasmtime serve` for HTTP components, `wasmtime run` for CLI components
- The `wasmtime wizer` subcommand expects an exported `wizer-initialize` function

## Related skills

- **wasm-search**: If you need to find or download WebAssembly components, use the wasm-search skill first
- **wasm-build**: If you need to compile source code into WebAssembly components, use the wasm-build skill
- **wasm-registry**: If you need to publish or pull components from OCI registries, use the wasm-registry skill

When invoked, start by understanding what WebAssembly file the user wants to work with and what they want to accomplish, then proceed with the appropriate wasmtime commands.
