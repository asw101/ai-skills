# WebAssembly Components Guide

Reference documentation for building, testing, and publishing WebAssembly components using WASI preview 2 and the Component Model.

## Directory Structure

```
components/
├── component-name/           # Source code directory
│   ├── src/                 # Source files (Rust, Go)
│   ├── wit/                 # WIT interface definitions
│   │   └── world.wit
│   ├── Cargo.toml           # Rust config
│   ├── package.json         # JavaScript config
│   ├── pyproject.toml       # Python config
│   ├── go.mod               # Go config
│   ├── build.sh             # Build script
│   └── README.md            # Component documentation
└── component-name.wasm      # Built component (sibling to source)
```

---

## WIT Interface Definition

All components define their interface in `wit/world.wit`:

### Basic Example

```wit
package namespace:component-name;

world component-name {
    export interface-name;
}

interface interface-name {
    process: func(input: string) -> result<string, string>;
}
```

### With WASI Imports

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

### Complex Example (csv-groupby)

```wit
package csv:groupby;

world csv-groupby {
    export groupby;
}

interface groupby {
    enum agg-operation {
        count,
        sum,
        avg,
        min,
        max,
    }

    record aggregation {
        column: string,
        operation: agg-operation,
        alias: option<string>,
    }

    record group-by-request {
        csv-data: string,
        group-columns: list<string>,
        aggregations: list<aggregation>,
        has-header: bool,
    }

    record grouped-row {
        group-values: list<string>,
        aggregated-values: list<string>,
    }

    record group-by-result {
        headers: list<string>,
        rows: list<grouped-row>,
    }

    execute-group-by: func(request: group-by-request) -> result<group-by-result, string>;
}
```

---

## Language Guide

### Language Comparison

| Language | Size | Build Time | Performance | Best For |
|----------|------|------------|-------------|----------|
| Rust | 100-300KB | Slow | Excellent | Performance, small size |
| Go (TinyGo) | 200KB-1MB | Fast | Excellent | Systems programming |
| JavaScript | 500KB-2MB | Fast | Good | Web integration |
| Python | 5-10MB | Fast | Good | Rapid development |

---

### Rust

**Prerequisites:**
```bash
just bootstrap-rust       # rustup + stable toolchain (skip if installed)
just install-rust-tools   # adds wasm32-wasip1/p2 targets, wasm-tools, wit-bindgen-cli, cargo-component
```

**Scaffold:**
```bash
cd components
cargo component new my-component --lib
```

**Cargo.toml:**
```toml
[package]
name = "my-component"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib"]

[dependencies]
wit-bindgen = "0.35.0"

[profile.release]
opt-level = "s"
lto = true
strip = true
```

**src/lib.rs:**
```rust
wit_bindgen::generate!("my-component");

use exports::namespace::my_component::interface_name::*;

export!(Component);

struct Component;

impl Guest for Component {
    fn process(input: String) -> Result<String, String> {
        Ok(format!("Processed: {}", input))
    }
}
```

**Build:**
```bash
cargo component build --release --target wasm32-wasip2
cp target/wasm32-wasip2/release/my_component.wasm ../my-component.wasm
```

---

### Go (TinyGo)

**Prerequisites:**
```bash
just bootstrap-go         # Go 1.23+ (skip if installed)
just install-go-tools     # wit-bindgen-go
just install-tinygo       # TinyGo binary release
just install-wasm-tools   # required by 'tinygo build -target=wasip2'
```

**Scaffold:**
```bash
cd components
mkdir my-component && cd my-component
go mod init my-component
mkdir wit
```

**main.go:**
```go
package main

import (
    "github.com/bytecodealliance/wasm-tools-go/cm"
)

//go:generate wit-bindgen-go generate --world my-component --out gen ./wit

func init() {
    a := &ComponentImpl{}
    exports.SetExportsNamespaceMyComponentInterface(a)
}

type ComponentImpl struct{}

func (c *ComponentImpl) Process(input string) cm.Result[string, string, string] {
    return cm.OK[cm.Result[string, string, string]]("Processed: " + input)
}

func main() {}
```

**Build:**
```bash
go generate
tinygo build -target=wasip2 -o ../my-component.wasm .
```

---

### JavaScript

**Prerequisites:**
```bash
just bootstrap-node       # Node 22 LTS (jco requires Node 20+)
just install-js-tools     # jco + componentize-js
```

**Scaffold:**
```bash
cd components
mkdir my-component && cd my-component
npm init -y
mkdir wit src
```

**package.json:**
```json
{
  "name": "my-component",
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "build": "jco componentize src/index.js -w wit -o ../my-component.wasm"
  }
}
```

**src/index.js:**
```javascript
export const interfaceName = {
  process(input) {
    return { tag: 'ok', val: `Processed: ${input}` };
  }
};
```

**Build:**
```bash
npm install
npm run build
```

---

### Python

**Prerequisites:**
```bash
just bootstrap-uv         # uv (or use system pip / pip3)
just install-py-tools     # componentize-py
```

**Scaffold:**
```bash
cd components
mkdir my-component && cd my-component
mkdir wit
```

**pyproject.toml:**
```toml
[project]
name = "my-component"
version = "0.1.0"
requires-python = ">=3.10"

[tool.componentize-py]
wit-path = "wit"
world = "my-component"
```

**app.py:**
```python
import my_component

class MyComponent(my_component.Interface):
    def process(self, input: str):
        return Ok(f"Processed: {input}")
```

**Build:**
```bash
componentize-py bindings .
componentize-py componentize app -o ../my-component.wasm
```

**Notes:**
- Keep dependencies pure Python (C extensions not WASI-compatible)
- Regenerate bindings after WIT changes
- Large size (5-10MB) due to bundled runtime

---

## Testing

### Validate Component

```bash
wasm-tools validate components/my-component.wasm
```

### Inspect Interface

```bash
wasm-tools component wit components/my-component.wasm
```

### Run with wasmtime

```bash
# Simple function
wasmtime run --invoke 'process("hello")' components/my-component.wasm

# Complex types (WAVE format)
wasmtime run --invoke 'execute-group-by({
  csv-data: "region,sales\nNorth,100",
  group-columns: ["region"],
  aggregations: [{column: "sales", operation: sum, alias: null}],
  has-header: true
})' components/csv-groupby.wasm
```

---

## Publishing

Publish to OCI registries (GitHub Container Registry) using `wkg`:

```bash
# Authenticate
export WKG_OCI_USERNAME="github-username"
export WKG_OCI_PASSWORD="github-token"

# Push
wkg oci push ghcr.io/username/my-component:v1.0.0 components/my-component.wasm \
  --annotation org.opencontainers.image.source="https://github.com/username/repo"

# Verify
wkg oci pull ghcr.io/username/my-component:v1.0.0 -o /tmp/verify.wasm
```

---

## Size Optimization

### All Languages

`wasm-opt` ships with `binaryen`. Install via:

- macOS: `brew install binaryen`
- Linux: `apt install binaryen` (or build from [WebAssembly/binaryen](https://github.com/WebAssembly/binaryen))

Then:

```bash
wasm-opt -Os component.wasm -o component.opt.wasm
```

### Rust

```toml
# Cargo.toml
[profile.release]
opt-level = "z"
codegen-units = 1
panic = "abort"
lto = true
strip = true
```

### Go

```bash
tinygo build -target=wasip2 -opt=z -o component.wasm .
```

---

## WASI Preview 2 Interfaces

Available imports:
- `wasi:cli/*` - Command-line (environment, stdin/stdout/stderr, exit)
- `wasi:clocks/*` - Time and clocks
- `wasi:filesystem/*` - File system access
- `wasi:http/*` - HTTP client/server
- `wasi:io/*` - I/O streams and polls
- `wasi:random/*` - Random number generation
- `wasi:sockets/*` - Network sockets

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Missing Rust target | `just install-rust-tools` (or `rustup target add wasm32-wasip2`) |
| cargo-component not found | `just install-rust-tools` |
| Python import errors | Run `componentize-py bindings .` after WIT changes |
| jco not found | `just install-js-tools` |
| jco fails with `ERR_MODULE_NOT_FOUND` | Node version too old — `just bootstrap-node` (requires Node 20+) |
| TinyGo not found | `just install-tinygo` |
| `wasm-tools component embed` failed (running TinyGo) | `just install-wasm-tools` (TinyGo's `-target=wasip2` calls wasm-tools internally) |
| "unknown import wasi:http" | Update wasmtime to v14.0.0+ |

---

**Last Updated:** 2026-01-19