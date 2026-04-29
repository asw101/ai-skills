---
name: wasm-build
description: Build WebAssembly components from Rust, Python, JavaScript, or Go source code using WASI preview 2. Helps scaffold, compile, validate, and optimize components for the WebAssembly Component Model.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# wasm-build skill

You specialize in building WebAssembly components from source code in Rust, Python, JavaScript, and Go using WASI preview 2.

## Your capabilities

When this skill is invoked, you help users:

1. **Scaffold new components** - Create component project structure with WIT definitions
2. **Build components** - Compile source to WebAssembly Component Model format (WASI preview 2)
3. **Validate components** - Check WIT interfaces and component structure
4. **Manage dependencies** - Handle language-specific toolchains and dependencies
5. **Optimize builds** - Configure size and performance optimizations

## Project structure

All components live in the `components/` directory:

```
components/
├── component-name/           # Source code directory
│   ├── src/ or app.py/js    # Source files
│   ├── wit/                 # WIT interface definitions
│   ├── Cargo.toml           # Rust config
│   ├── package.json         # JavaScript config
│   ├── pyproject.toml       # Python config
│   ├── go.mod               # Go config
│   ├── USAGE.md             # Usage documentation
│   ├── README.md            # Component overview
│   └── examples/            # Sample data and tests
├── component-name.wasm      # Built component (sibling to source)
└── README.md                # Components index
```

---

## Rust Components

### Prerequisites

```bash
rustup target add wasm32-wasip2
cargo install cargo-component
```

### Scaffold

```bash
cd components
cargo component new component-name --lib
cd component-name
```

### Project structure

```
component-name/
├── Cargo.toml
├── wit/
│   └── world.wit
└── src/
    └── lib.rs
```

### Cargo.toml

```toml
[package]
name = "component-name"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib"]

[dependencies]
wit-bindgen = "0.47.0"

[profile.release]
opt-level = "s"
lto = true
strip = true
```

### src/lib.rs

```rust
wit_bindgen::generate!("component-name");

use exports::namespace::component_name::interface_name::*;

export!(Component);

struct Component;

impl Guest for Component {
    fn process(input: String) -> Result<String, String> {
        Ok(format!("Processed: {}", input))
    }
}
```

### Build

```bash
cd components/component-name
cargo component build --release --target wasm32-wasip2
cp target/wasm32-wasip2/release/component_name.wasm ../component-name.wasm
```

### Alternative: Direct wasm32-wasip2 (Rust 1.82+)

For components that only use WASI interfaces (no custom WIT), you can build directly without cargo-component:

```bash
# No cargo-component needed for WASI-only components
rustup target add wasm32-wasip2
cargo build --release --target wasm32-wasip2
```

**Cargo.toml for direct builds:**

```toml
[package]
name = "component-name"
version = "0.1.0"
edition = "2021"

[dependencies]
wasi = "0.13"

[profile.release]
opt-level = "s"
lto = true
strip = true
```

**src/main.rs:**

```rust
use std::io::{self, Read, Write};

fn main() -> io::Result<()> {
    let mut input = String::new();
    io::stdin().read_to_string(&mut input)?;
    io::stdout().write_all(format!("Processed: {}", input).as_bytes())?;
    Ok(())
}
```

> **When to use**: Direct `wasm32-wasip2` is simpler when you only need WASI interfaces. Use **cargo-component** when you have custom WIT interfaces or third-party WIT packages.

---

## Python Components

### Prerequisites

```bash
# Install componentize-py
pip install componentize-py
# or with uv: uv pip install componentize-py
```

### Scaffold

```bash
cd components
mkdir component-name
cd component-name
mkdir wit
```

### Project structure

```
component-name/
├── pyproject.toml
├── wit/
│   └── world.wit
└── app.py
```

### pyproject.toml

```toml
[project]
name = "component-name"
version = "0.1.0"
requires-python = ">=3.10"
dependencies = []

[tool.componentize-py]
wit-path = "wit"
world = "component-name"
```

### app.py

```python
import component_name

class ComponentName(component_name.Interface):
    def process(self, input: str) -> Result[str, str]:
        return Ok(f"Processed: {input}")
```

### Build

```bash
cd components/component-name

# Generate bindings
componentize-py bindings .

# Build component
componentize-py componentize app -o ../component-name.wasm
```

---

## JavaScript/TypeScript Components

### Prerequisites

```bash
npm install -g @bytecodealliance/jco @bytecodealliance/componentize-js
```

> **Note**: JavaScript components are ~8MB due to SpiderMonkey runtime embedding. jco 1.0 is now stable, but `jco componentize` is still considered experimental.

### Scaffold

```bash
cd components
mkdir component-name
cd component-name
npm init -y
mkdir wit src
```

### Project structure

```
component-name/
├── package.json
├── wit/
│   └── world.wit
└── src/
    └── index.js
```

### package.json

```json
{
  "name": "component-name",
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "build": "jco componentize src/index.js -w wit -o ../component-name.wasm"
  },
  "devDependencies": {
    "@bytecodealliance/componentize-js": "^0.16.0",
    "@bytecodealliance/jco": "^1.8.0"
  }
}
```

### src/index.js

```javascript
export const interfaceName = {
  process(input) {
    return { tag: 'ok', val: `Processed: ${input}` };
  }
};
```

### Build

```bash
cd components/component-name
npm install
npm run build
```

---

## Go Components

### Prerequisites

```bash
# Install TinyGo 0.34+ (required for WASI support)
# macOS:
brew install tinygo

# Linux:
wget https://github.com/tinygo-org/tinygo/releases/download/v0.34.0/tinygo_0.34.0_amd64.deb
sudo dpkg -i tinygo_0.34.0_amd64.deb

# Install wit-bindgen-go (now part of go.bytecodealliance.org)
go install go.bytecodealliance.org/cmd/wit-bindgen-go@latest
```

> **Note**: Go 1.23+ required. TinyGo's `wasip2` target currently only supports the `wasi:cli/command` world. Custom worlds with custom WIT interfaces have limited support.

### Scaffold

```bash
cd components
mkdir component-name
cd component-name
go mod init component-name
mkdir wit
```

### Project structure

```
component-name/
├── go.mod
├── wit/
│   └── world.wit
└── main.go
```

### go.mod

```go
module component-name

go 1.23

require go.bytecodealliance.org v0.4.0
```

### main.go

```go
package main

import (
    "go.bytecodealliance.org/cm"
)

//go:generate wit-bindgen-go generate --world component-name --out gen ./wit

func init() {
    a := &ComponentImpl{}
    exports.SetExportsNamespaceComponentNameInterface(a)
}

type ComponentImpl struct{}

func (c *ComponentImpl) Process(input string) cm.Result[string, string, string] {
    return cm.OK[cm.Result[string, string, string]]("Processed: " + input)
}

func main() {}
```

### Build

```bash
cd components/component-name

# Generate bindings
go generate

# Build component with TinyGo
tinygo build -target=wasip2 -o ../component-name.wasm .
```

---

## WIT Interface Definition

All languages use the same WIT definition in `wit/world.wit`:

```wit
package namespace:component-name;

world component-name {
    export interface-name;
}

interface interface-name {
    process: func(input: string) -> result<string, string>;
}
```

### With WASI preview 2 imports

```wit
package namespace:component-name;

world component-name {
    import wasi:cli/environment@0.2.0;
    import wasi:cli/stdin@0.2.0;
    import wasi:cli/stdout@0.2.0;

    export interface-name;
}

interface interface-name {
    run: func() -> result<_, string>;
}
```

---

## Build scripts

### Rust build.sh

```bash
#!/bin/bash
set -e
NAME="component-name"
cargo component build --release --target wasm32-wasip2
cp target/wasm32-wasip2/release/${NAME//-/_}.wasm ../$NAME.wasm
echo "✓ Built ../$NAME.wasm"
```

### Python build.sh

```bash
#!/bin/bash
set -e
NAME="component-name"
componentize-py componentize app -o ../$NAME.wasm
echo "✓ Built ../$NAME.wasm"
```

### JavaScript build.sh

```bash
#!/bin/bash
set -e
NAME="component-name"
jco componentize src/index.js -w wit -o ../$NAME.wasm
echo "✓ Built ../$NAME.wasm"
```

### Go build.sh

```bash
#!/bin/bash
set -e
NAME="component-name"
go generate
tinygo build -target=wasip2 -o ../$NAME.wasm .
echo "✓ Built ../$NAME.wasm"
```

---

## Testing components

All components can be tested with wasmtime:

```bash
# Simple function call
wasmtime run --invoke 'process("hello")' components/component-name.wasm

# With WAVE format for complex types
wasmtime run --invoke 'process({field: "value"})' components/component-name.wasm
```

---

## Validation

```bash
# Validate component
wasm-tools validate components/component-name.wasm

# Inspect WIT interface
wasm-tools component wit components/component-name.wasm

# Check size
ls -lh components/component-name.wasm
```

---

## Language comparison

| Feature | Rust | Python | JavaScript | Go |
|---------|------|--------|------------|-----|
| **Component size** | Small (100-300KB) | Large (5-10MB) | Large (~8MB) | Small (200KB-1MB) |
| **Build time** | Slow | Fast | Fast | Fast |
| **Performance** | Excellent | Good | Good | Excellent |
| **Ease of use** | Moderate | Easy | Easy | Moderate |
| **Ecosystem** | Mature | Growing | Stable (jco 1.0) | Growing |
| **Custom WIT** | Full support | Full support | Full support | Limited (wasip2) |
| **Best for** | Performance, small size | Rapid development | Web integration | Systems programming |

> **Note**: JavaScript component size (~8MB) is due to SpiderMonkey runtime embedding.

---

## Language-specific tips

### Rust
- **Smallest size**: Use `opt-level = "z"`, consider `no_std`
- **Best performance**: Use `opt-level = 3`, `lto = "fat"`
- **Most mature** Component Model support
- **WASI-only builds**: Use direct `wasm32-wasip2` target (Rust 1.82+) without cargo-component
- **Custom WIT**: Requires cargo-component for non-WASI interfaces

### Python
- **Keep it pure Python**: Avoid C extensions (not WASI-compatible)
- **Minimal dependencies**: Each dependency increases component size significantly
- **Use bindings**: Always run `componentize-py bindings` after WIT changes
- **Large components**: Python components are typically 5-10MB due to runtime
- **Latest version**: Use componentize-py 0.19.3+ for best compatibility

### JavaScript
- **ES modules**: Use `"type": "module"` in package.json
- **TypeScript**: Generate types with `jco types wit/`
- **jco 1.0 stable**: The toolchain is now stable for production use
- **Large components**: ~8MB due to SpiderMonkey embedding (this is expected)
- **Experimental componentize**: `jco componentize` may have breaking changes

### Go
- **TinyGo required**: Standard Go doesn't support WASI components
- **Go 1.23+**: Required for latest wit-bindgen-go
- **New import path**: Use `go.bytecodealliance.org` (not the old github path)
- **Limited worlds**: TinyGo wasip2 only supports `wasi:cli/command` world
- **Strict subset**: Not all Go features available in TinyGo
- **Small binaries**: Comparable to Rust with good performance
- **Registry support**: wit-bindgen-go can fetch WIT from OCI registries:
  ```bash
  wit-bindgen-go generate ghcr.io/webassembly/wasi/http:0.2.0
  ```

---

## Size optimization

### All languages

```bash
# Use wasm-opt (install: npm install -g wasm-opt)
wasm-opt -Os components/component-name.wasm -o components/component-name.opt.wasm
mv components/component-name.opt.wasm components/component-name.wasm
```

### Rust-specific

```bash
# Analyze bloat
cargo bloat --release --target wasm32-wasip2 --crates

# Ultra-small build
# In Cargo.toml:
# opt-level = "z"
# codegen-units = 1
# panic = "abort"
```

### Go-specific

```bash
# Smaller builds
tinygo build -target=wasip2 -opt=z -o component.wasm .

# Check what's included
tinygo build -target=wasip2 -size=short -o component.wasm .
```

---

## Common workflows

### Create new component (any language)

**Rust:**
```bash
cd components && cargo component new my-component --lib
```

**Python:**
```bash
cd components && mkdir my-component && cd my-component && mkdir wit
```

**JavaScript:**
```bash
cd components && mkdir my-component && cd my-component && npm init -y && mkdir wit src
```

**Go:**
```bash
cd components && mkdir my-component && cd my-component && go mod init my-component && mkdir wit
```

---

## Troubleshooting

### Rust
- **Missing target**: `rustup target add wasm32-wasip2`
- **cargo-component not found**: `cargo install cargo-component`
- **wit-bindgen version mismatch**: Ensure Cargo.toml uses `wit-bindgen = "0.47.0"` or later
- **Build without cargo-component**: For WASI-only, use direct `cargo build --target wasm32-wasip2`

### Python
- **componentize-py not found**: `pip install componentize-py` (latest: 0.19.3+)
- **Import errors**: Run `componentize-py bindings .` after WIT changes
- **C extension errors**: Use pure Python alternatives (no C extensions in WASI)

### JavaScript
- **jco not found**: `npm install -g @bytecodealliance/jco @bytecodealliance/componentize-js`
- **Module errors**: Ensure `"type": "module"` in package.json
- **Large component size**: Expected (~8MB due to SpiderMonkey); use wasm-opt for minor reduction
- **AOT compilation unavailable**: Weval AOT is currently disabled due to LLVM compatibility

### Go
- **TinyGo not found**: Install from https://tinygo.org/getting-started/install/
- **wit-bindgen-go not found**: `go install go.bytecodealliance.org/cmd/wit-bindgen-go@latest`
- **Old import path**: Update from `github.com/bytecodealliance/wasm-tools-go` to `go.bytecodealliance.org`
- **Custom WIT not working**: TinyGo wasip2 only supports `wasi:cli/command` world currently
- **Unsupported feature**: Check TinyGo compatibility docs
- **Large binary**: TinyGo should produce small binaries; check for unexpected dependencies

### General
- **Not a component error**: You have a core module, not a component. Use adapter:
  ```bash
  wasm-tools component new module.wasm -o component.wasm --adapt wasi_snapshot_preview1.wasm
  ```
- **WIT resolution failed**: Run `wkg wit fetch` to download dependencies
- **Registry auth failed**: Configure credentials in `~/.config/wasm-pkg/config.toml`

---

## WASI preview 2 interfaces

Available for all languages:

- `wasi:cli/*` - Command-line (environment, stdin/stdout/stderr, exit)
- `wasi:clocks/*` - Time and clocks
- `wasi:filesystem/*` - File system access
- `wasi:http/*` - HTTP client/server
- `wasi:io/*` - I/O streams and polls
- `wasi:random/*` - Random number generation
- `wasi:sockets/*` - Network sockets

---

## WASI 0.3 Preview (Async Support)

WASI 0.3.0 is expected in February 2026 and introduces native async support with `stream<T>` and `future<T>` types. Preview available in Wasmtime 37+.

### New WIT types

```wit
package example:async-demo;

interface async-io {
    // Stream of bytes for incremental data
    read-stream: func() -> stream<u8>;

    // Future for async operations
    fetch: func(url: string) -> future<response>;
}
```

### Key improvements in WASI 0.3

- **Native async**: Any component function can be async without polling overhead
- **Simplified APIs**: `wasi:http@0.3.0` has 5 resource types vs 11 in 0.2
- **Composable concurrency**: Multiple components can do I/O concurrently
- **Cross-language interop**: Rust, C++, and Zig components can share streams/futures

> **Note**: WASI 0.3 is preview only. Use WASI 0.2 for production components.

---

## Package Management with wkg

The `wkg` tool (wasm-pkg-tools) manages WIT packages and components from OCI registries.

### Installation

```bash
# From source
cargo install wkg

# Or download from releases
# https://github.com/bytecodealliance/wasm-pkg-tools/releases
```

### Configuration

Create `~/.config/wasm-pkg/config.toml`:

```toml
[registry]
default = "ghcr.io"

[registry."ghcr.io"]
type = "oci"
```

### Common commands

```bash
# Fetch WIT dependencies (creates wkg.lock)
wkg wit fetch

# Build a WIT package from wit/ directory
wkg wit build -o package.wasm

# Publish component to OCI registry
wkg publish ghcr.io/namespace/component:1.0.0

# Pull a component
wkg pull ghcr.io/namespace/component:1.0.0
```

### Using registry dependencies

In your WIT files, reference packages by name:

```wit
package mycompany:mycomponent;

// Dependencies resolved via wkg
use wasi:http/types@0.2.0.{request, response};

world mycomponent {
    import wasi:http/outgoing-handler@0.2.0;
    export process;
}
```

Then fetch:

```bash
wkg wit fetch
# Creates wkg.lock with resolved versions
```

### wkg.lock file

The `wkg.lock` file is cross-language and ensures reproducible builds:

```toml
# wkg.lock - do not edit manually
version = 1

[[package]]
name = "wasi:http"
version = "0.2.0"
digest = "sha256:..."
```

---

## Component Composition

Combine multiple components into a single composed component using `wasm-tools compose` or WAC.

### Using wasm-tools compose

```bash
# Install wasm-tools
cargo install wasm-tools

# Compose with a configuration file
wasm-tools compose -c compose.yaml -o composed.wasm
```

**compose.yaml:**

```yaml
# Define how components wire together
instantiate:
  main:
    path: components/main.wasm
  helper:
    path: components/helper.wasm

# Wire exports to imports
dependencies:
  main:
    "mycompany:helper/process": helper
```

### Using WAC (WebAssembly Composition)

WAC provides a declarative language for composition:

```bash
# Install wac
cargo install wac-cli

# Compose using WAC syntax
wac compose app.wac -o output.wasm
```

**app.wac:**

```wac
package mycompany:composed;

// Import components
let main = new mycompany:main;
let helper = new mycompany:helper;

// Wire them together
let main_with_helper = main with {
    "mycompany:helper/process": helper.process
};

// Export the composed component
export main_with_helper;
```

---

## Debugging and Inspection

### Inspect component structure

```bash
# Print WIT interface of a component
wasm-tools component wit component.wasm

# Detailed component info
wasm-tools component info component.wasm

# Print with demangled names (readable function names)
wasm-tools print --demangle component.wasm

# Validate component
wasm-tools validate component.wasm

# Validate with component model features
wasm-tools validate --features component-model component.wasm
```

### Debugging at runtime

```bash
# Run with verbose logging (wasmtime)
WASMTIME_LOG=wasmtime=debug wasmtime run component.wasm

# Trace function calls
wasmtime run --wasm-features=function-references -W debug-info component.wasm
```

### Size analysis

```bash
# Check component size
ls -lh component.wasm

# Rust: analyze what contributes to size
cargo bloat --release --target wasm32-wasip2 --crates

# TinyGo: show size breakdown
tinygo build -target=wasip2 -size=short -o component.wasm .
```

### Common issues

```bash
# Check if it's a valid component (not just a module)
wasm-tools component wit component.wasm
# If this fails with "not a component", you have a core module

# Convert core module to component (if using WASI preview 1)
wasm-tools component new module.wasm -o component.wasm --adapt wasi_snapshot_preview1.wasm
```

---

When invoked, help users choose the right language for their use case and build components following WASI preview 2 and Component Model best practices.

**Language recommendations:**
- **Rust**: When you need maximum performance and smallest size. Best toolchain maturity and full custom WIT support.
- **Python**: When you want rapid development and have large runtime budget (~5-10MB components acceptable).
- **JavaScript**: When you need web integration. Note: ~8MB component size due to SpiderMonkey embedding.
- **Go**: When you want Go's simplicity with good performance and small size. Limited to `wasi:cli/command` world currently.

**Toolchain maturity (as of early 2026):**
- **Rust**: Production-ready, most mature
- **Python**: Production-ready (componentize-py 0.19+)
- **JavaScript**: Stable (jco 1.0), but componentize is still experimental
- **Go**: Usable but limited world support in TinyGo

**WASI version guidance:**
- **WASI 0.2**: Use for production components (stable)
- **WASI 0.3**: Preview only (Wasmtime 37+), wait for February 2026 release for production