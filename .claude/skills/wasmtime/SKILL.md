---
name: wasmtime
description: Use this skill when working with WebAssembly (Wasm), .wasm files, wasmtime runtime, WASI, or WebAssembly Component Model. Helps run, inspect, debug, and configure WebAssembly modules and components, including WIT interface definitions.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# wasmtime skill

You are a specialized assistant for working with WebAssembly components using the `wasmtime` runtime.

## About wasmtime

`wasmtime` is a fast, secure, and standards-compliant WebAssembly runtime. It supports running WebAssembly modules and WebAssembly components (using the Component Model).

## Your capabilities

When this skill is invoked, you should help users:

1. **Run WebAssembly components**: Execute `.wasm` files using wasmtime
2. **Inspect components**: Examine component structure and interfaces
3. **Debug execution**: Help troubleshoot runtime errors
4. **Configure execution**: Set up WASI permissions, environment variables, and resource limits
5. **Work with component interfaces**: Help understand and work with WIT (WebAssembly Interface Types) definitions
6. **Optimize execution**: Tune performance settings and caching

## Available wasmtime commands

- `wasmtime run MODULE` - Run a WebAssembly module or component
- `wasmtime compile MODULE` - Compile a module ahead-of-time
- `wasmtime config new` - Create a new configuration file
- `wasmtime wast MODULE` - Run a WebAssembly test script

## Common wasmtime options

- `--dir DIR` - Grant access to a directory (WASI)
- `--env NAME=VAL` - Set environment variable
- `--invoke FUNC` - Invoke a specific function (default is `_start`)
- `--allow-precompiled` - Allow loading precompiled modules
- `-O, --optimize` - Optimization level (default: 2)
- `--wasi common|preview1|preview2` - WASI version to use
- `--wasm-features FEATURES` - Enable/disable WebAssembly features
- `--profile` - Profile execution

## WebAssembly Component Model basics

Components use WIT (WebAssembly Interface Types) to define interfaces:
- Components can import and export functions
- Types are defined in `.wit` files
- Components compose through interfaces

## Binary location

**IMPORTANT**: Before running any `wasmtime` commands, you must determine which binary to use:

1. Check if `scripts/wasmtime` exists in this skill's directory (`.claude/skills/wasmtime/scripts/wasmtime`)
2. If it exists and is executable, use the full path to that binary
3. Otherwise, fall back to the system-installed `wasmtime` binary

Example setup:
```bash
# Determine which wasmtime binary to use
SKILL_DIR=".claude/skills/wasmtime"
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

## Your workflow

1. **Determine binary location**: Check for local `scripts/wasmtime` binary first, fall back to system binary
2. **Identify the WebAssembly file**: Find `.wasm` files in the project
3. **Inspect if needed**: Check the component's structure and requirements
4. **Set up execution environment**: Configure WASI permissions, directories, and environment
5. **Run the component**: Execute with appropriate flags using the correct binary path
6. **Handle results**: Display output and help interpret any errors
7. **Debug if needed**: Use wasmtime's debugging features to troubleshoot

## Common patterns

Note: Examples below use `$WASMTIME` which should be set to the correct binary path as described in the Binary location section.

### Running a simple component
```bash
$WASMTIME run component.wasm
```

### Running with directory access
```bash
$WASMTIME run --dir /path/to/dir component.wasm
```

### Running with environment variables
```bash
$WASMTIME run --env KEY=value component.wasm
```

### Running a specific function
```bash
$WASMTIME run --invoke function_name component.wasm
```

### Compiling ahead-of-time
```bash
$WASMTIME compile component.wasm -o component.cwasm
$WASMTIME run component.cwasm
```

## Important notes

- Components compiled with component model use WASI preview2 by default
- Core modules typically use WASI preview1
- Use `--dir` to grant filesystem access (denied by default for security)
- Network access is controlled via WASI sockets
- Check wasmtime version: `$WASMTIME --version` (or `wasmtime --version` if using system binary)

## Security considerations

- By default, WebAssembly runs in a secure sandbox
- Filesystem access must be explicitly granted with `--dir`
- Network access must be explicitly granted with `--tcplisten` or `--allow-ip-name-lookup`
- Environment variables must be explicitly passed with `--env`

When invoked, start by understanding what WebAssembly file the user wants to work with and what they want to accomplish, then proceed with the appropriate wasmtime commands.
