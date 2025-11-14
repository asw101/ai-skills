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
wit-bindgen = "0.35.0"

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
    "@bytecodealliance/componentize-js": "^0.11.0",
    "@bytecodealliance/jco": "^1.0.0"
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
# Install TinyGo (required for WASI support)
# macOS:
brew install tinygo

# Linux:
wget https://github.com/tinygo-org/tinygo/releases/download/v0.33.0/tinygo_0.33.0_amd64.deb
sudo dpkg -i tinygo_0.33.0_amd64.deb

# Install wit-bindgen-go
go install github.com/bytecodealliance/wit-bindgen-go/cmd/wit-bindgen-go@latest
```

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

go 1.21

require github.com/bytecodealliance/wasm-tools-go v0.1.0
```

### main.go

```go
package main

import (
    "github.com/bytecodealliance/wasm-tools-go/cm"
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
| **Component size** | Small (100-300KB) | Large (5-10MB) | Medium (500KB-2MB) | Small (200KB-1MB) |
| **Build time** | Slow | Fast | Fast | Fast |
| **Performance** | Excellent | Good | Good | Excellent |
| **Ease of use** | Moderate | Easy | Easy | Moderate |
| **Ecosystem** | Mature | Growing | Mature | Growing |
| **Best for** | Performance, small size | Rapid development | Web integration | Systems programming |

---

## Language-specific tips

### Rust
- **Smallest size**: Use `opt-level = "z"`, consider `no_std`
- **Best performance**: Use `opt-level = 3`, `lto = "fat"`
- **Most mature** Component Model support

### Python
- **Keep it pure Python**: Avoid C extensions (not WASI-compatible)
- **Minimal dependencies**: Each dependency increases component size significantly
- **Use bindings**: Always run `componentize-py bindings` after WIT changes
- **Large components**: Python components are typically 5-10MB due to runtime

### JavaScript
- **ES modules**: Use `"type": "module"` in package.json
- **Tree shaking**: Modern module system helps reduce size
- **TypeScript**: Generate types with `jco types wit`
- **Good balance**: Decent size and performance

### Go
- **TinyGo only**: Standard Go doesn't support WASI
- **Strict subset**: Not all Go features available in TinyGo
- **Small binaries**: Comparable to Rust with good performance
- **Limited stdlib**: Some standard library packages don't work in TinyGo

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

### Python
- **componentize-py not found**: `pip install componentize-py`
- **Import errors**: Run `componentize-py bindings .` after WIT changes
- **C extension errors**: Use pure Python alternatives

### JavaScript
- **jco not found**: `npm install -g @bytecodealliance/jco @bytecodealliance/componentize-js`
- **Module errors**: Ensure `"type": "module"` in package.json

### Go
- **TinyGo not found**: Install from https://tinygo.org/getting-started/install/
- **wit-bindgen-go not found**: `go install github.com/bytecodealliance/wit-bindgen-go/cmd/wit-bindgen-go@latest`
- **Unsupported feature**: Check TinyGo compatibility docs
- **Large binary**: TinyGo should produce small binaries; check for unexpected dependencies

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

When invoked, help users choose the right language for their use case and build components following WASI preview 2 and Component Model best practices.

**Language recommendations:**
- **Rust**: When you need maximum performance and smallest size
- **Python**: When you want rapid development and have large runtime budget
- **JavaScript**: When you need web integration or moderate size/performance
- **Go**: When you want Go's simplicity with good performance and small size