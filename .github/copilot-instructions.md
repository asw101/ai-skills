# WebAssembly Development Repository

This repository contains WebAssembly components and comprehensive WASM tooling expertise across runtime execution, building, component discovery, and publishing.

## Repository Overview

- **Components**: Pre-built WASM components in `components/`
- **Skills**: Claude Code skills in `.claude/skills/`
- **Build System**: Justfile with recipes for common tasks
- **Test Data**: Sample CSV files in `test-data/`

## Core Technologies

- **wasmtime**: WebAssembly runtime (WASI preview2 support)
- **Component Model**: WASI 0.2+ component architecture
- **WIT**: WebAssembly Interface Types for component definitions
- **OCI Registries**: GitHub Container Registry (GHCR) for distribution

---

## WebAssembly Runtime Expertise

### About wasmtime

wasmtime is a fast, secure, and standards-compliant WebAssembly runtime supporting both modules and components (Component Model).

### Running Components

**Basic execution**:
```bash
wasmtime run component.wasm
```

**Grant filesystem access**:
```bash
wasmtime run --dir /path/to/dir component.wasm
```

**Set environment variables**:
```bash
wasmtime run --env KEY=value component.wasm
```

**Invoke specific function**:
```bash
wasmtime run --invoke 'function-name()' component.wasm
wasmtime run --invoke 'add(1, 2)' component.wasm
```

**Ahead-of-time compilation**:
```bash
wasmtime compile component.wasm -o component.cwasm
wasmtime run component.cwasm
```

### Common wasmtime Options

- `--dir DIR` - Grant access to a directory (WASI)
- `--env NAME=VAL` - Set environment variable
- `--invoke FUNC` - Invoke a specific function (default is `_start`)
- `--allow-precompiled` - Allow loading precompiled modules
- `-O, --optimize` - Optimization level (default: 2)
- `--wasi common|preview1|preview2` - WASI version to use
- `--wasm-features FEATURES` - Enable/disable WebAssembly features
- `--profile` - Profile execution

### Component Model Concepts

- Components use WIT (WebAssembly Interface Types) to define interfaces
- Components can import and export functions
- Types are defined in `.wit` files
- Components compose through interfaces
- WASI preview2 is the modern standard (preview1 is legacy)

### Security Considerations

WebAssembly runs in a secure sandbox by default:
- Filesystem access must be explicitly granted with `--dir`
- Network access requires `--tcplisten` or `--allow-ip-name-lookup`
- Environment variables must be passed with `--env`
- Always grant minimal necessary permissions

### Troubleshooting Runtime Issues

**"failed to find a pre-opened file descriptor"**
- Solution: Add `--dir` flag to grant filesystem access

**"unknown import wasi:http"**
- Solution: Ensure wasmtime version supports WASI preview2 (v14.0.0+)

**Component won't start**
- Solution: Check if using correct invoke function with `--invoke`

**Check version**:
```bash
wasmtime --version
```

---

## WebAssembly Build Engineering

### Project Structure Standard

All components follow this structure:
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
└── component-name.wasm      # Built component (sibling to source)
```

### Language Selection Guide

| Language | Component Size | Build Time | Performance | Best For |
|----------|---------------|------------|-------------|----------|
| **Rust** | Small (100-300KB) | Slow | Excellent | Performance, small size |
| **Python** | Large (5-10MB) | Fast | Good | Rapid development |
| **JavaScript** | Medium (500KB-2MB) | Fast | Good | Web integration |
| **Go** | Small (200KB-1MB) | Fast | Excellent | Systems programming |

### Rust Components

**Prerequisites**:
```bash
rustup target add wasm32-wasip2
cargo install cargo-component
```

**Scaffold**:
```bash
cd components
cargo component new component-name --lib
cd component-name
```

**Cargo.toml template**:
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
opt-level = "s"      # Optimize for size
lto = true           # Link-time optimization
strip = true         # Strip symbols
```

**src/lib.rs template**:
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

**Build**:
```bash
cd components/component-name
cargo component build --release --target wasm32-wasip2
cp target/wasm32-wasip2/release/component_name.wasm ../component-name.wasm
```

**Size optimization**:
```bash
# Analyze bloat
cargo bloat --release --target wasm32-wasip2 --crates

# Ultra-small build - use in Cargo.toml:
# opt-level = "z"
# codegen-units = 1
# panic = "abort"
```

### Python Components

**Prerequisites**:
```bash
pip install componentize-py
# or: uv pip install componentize-py
```

**Scaffold**:
```bash
cd components
mkdir component-name
cd component-name
mkdir wit
```

**pyproject.toml template**:
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

**app.py template**:
```python
import component_name

class ComponentName(component_name.Interface):
    def process(self, input: str) -> Result[str, str]:
        return Ok(f"Processed: {input}")
```

**Build**:
```bash
cd components/component-name

# Generate bindings
componentize-py bindings .

# Build component
componentize-py componentize app -o ../component-name.wasm
```

**Important notes**:
- Keep dependencies pure Python (C extensions not WASI-compatible)
- Python components are large (5-10MB) due to included runtime
- Always regenerate bindings after WIT changes

### JavaScript/TypeScript Components

**Prerequisites**:
```bash
npm install -g @bytecodealliance/jco @bytecodealliance/componentize-js
```

**Scaffold**:
```bash
cd components
mkdir component-name
cd component-name
npm init -y
mkdir wit src
```

**package.json template**:
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

**src/index.js template**:
```javascript
export const interfaceName = {
  process(input) {
    return { tag: 'ok', val: `Processed: ${input}` };
  }
};
```

**Build**:
```bash
cd components/component-name
npm install
npm run build
```

**TypeScript support**:
```bash
jco types wit/world.wit -o types.d.ts
```

### Go Components

**Prerequisites**:
```bash
# macOS:
brew install tinygo

# Linux:
wget https://github.com/tinygo-org/tinygo/releases/download/v0.33.0/tinygo_0.33.0_amd64.deb
sudo dpkg -i tinygo_0.33.0_amd64.deb

# Install wit-bindgen-go
go install github.com/bytecodealliance/wit-bindgen-go/cmd/wit-bindgen-go@latest
```

**Scaffold**:
```bash
cd components
mkdir component-name
cd component-name
go mod init component-name
mkdir wit
```

**main.go template**:
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

**Build**:
```bash
cd components/component-name

# Generate bindings
go generate

# Build with TinyGo
tinygo build -target=wasip2 -o ../component-name.wasm .
```

**Size optimization**:
```bash
tinygo build -target=wasip2 -opt=z -o component.wasm .
```

### WIT Interface Definition

Standard WIT pattern:
```wit
package namespace:component-name;

world component-name {
    export interface-name;
}

interface interface-name {
    process: func(input: string) -> result<string, string>;
}
```

With WASI imports:
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

### Testing Components

All components can be tested with wasmtime:
```bash
# Simple function call
wasmtime run --invoke 'process("hello")' components/component-name.wasm

# With WAVE format for complex types
wasmtime run --invoke 'process({field: "value"})' components/component-name.wasm
```

### Validation Commands

```bash
# Validate component
wasm-tools validate components/component-name.wasm

# Inspect WIT interface
wasm-tools component wit components/component-name.wasm

# Check size
ls -lh components/component-name.wasm
```

### Universal Size Optimization

For all languages:
```bash
# Install wasm-opt
npm install -g wasm-opt

# Optimize
wasm-opt -Os components/component-name.wasm -o components/component-name.opt.wasm
mv components/component-name.opt.wasm components/component-name.wasm
```

### Common Build Issues

**Rust**:
- Missing target: `rustup target add wasm32-wasip2`
- cargo-component not found: `cargo install cargo-component`

**Python**:
- Import errors: Run `componentize-py bindings .` after WIT changes
- C extension errors: Use pure Python alternatives

**JavaScript**:
- Module errors: Ensure `"type": "module"` in package.json
- jco not found: `npm install -g @bytecodealliance/jco`

**Go**:
- TinyGo not found: Install from https://tinygo.org
- Unsupported feature: Check TinyGo compatibility docs
- Large binary: Check for unexpected dependencies

### WASI Preview 2 Interfaces

Available for all languages:
- `wasi:cli/*` - Command-line (environment, stdin/stdout/stderr, exit)
- `wasi:clocks/*` - Time and clocks
- `wasi:filesystem/*` - File system access
- `wasi:http/*` - HTTP client/server
- `wasi:io/*` - I/O streams and polls
- `wasi:random/*` - Random number generation
- `wasi:sockets/*` - Network sockets

---

## WebAssembly Component Discovery

### Component Categories

**Applications** (wasi:http, wasi:cli):
- sample-wasi-http-rust: HTTP server (Rust)
- sample-wasi-http-js: HTTP server (JavaScript)

**Libraries** (reusable components):
- fetch-rs (`ghcr.io/yoshuawuyts/fetch`): HTTP client
- eval-py: Python expression evaluator
- filesystem-rs: Filesystem operations
- get-weather-js: Weather data API
- timeserver-js: Time service
- qr-code-webassembly: QR code generator

**Interfaces** (WIT definitions):
- wasi:io: Stream abstractions
- wasi:clocks: Time APIs
- wasi:random: Random data
- wasi:filesystem: File operations
- wasi:sockets: TCP/UDP/DNS
- wasi:cli: CLI environment
- browser.wit: Web APIs in WIT

### Discovering Components

When needing HTTP, filesystem, or data processing capabilities:
1. Identify the core functionality required
2. Check awesome-wasm-components collection
3. Consider maintenance and language compatibility
4. Evaluate size impact
5. Check WASI version compatibility

### Downloading Components

```bash
# Download from GitHub Container Registry
wkg oci pull ghcr.io/yoshuawuyts/fetch:latest -o components/fetch.wasm

# Download from Microsoft
wkg oci pull ghcr.io/microsoft/fetch-rs:latest -o components/fetch-rs.wasm

# List available versions
wkg oci list ghcr.io/yoshuawuyts/fetch
```

### Inspecting Components

```bash
# Extract WIT interface
wasm-tools component wit component.wasm

# View component metadata
wasm-tools component metadata show component.wasm
```

### Integration Guidance

**For Rust**:
```bash
wit-bindgen rust wit/
```

**For Python**:
```bash
componentize-py bindings wit/
```

**For JavaScript**:
```bash
jco types wit/world.wit -o types.d.ts
```

**For Go**:
```bash
wit-bindgen-go generate wit/
```

### Common Registry URLs

- Bytecode Alliance: `ghcr.io/bytecodealliance/*`
- awesome-wasm: `ghcr.io/yoshuawuyts/*`
- Microsoft: `ghcr.io/microsoft/*`

### Component Evaluation Criteria

When recommending components:
1. **Language compatibility**: Check if bindings exist
2. **Maintenance**: Prefer actively maintained components
3. **Dependencies**: Simpler chains are better
4. **Size**: Consider bundle size impact
5. **Security**: Evaluate trust and vulnerability history

---

## WebAssembly Publishing and Distribution

### Publishing Workflow

1. **Build component** (see Build Engineering section above)
2. **Validate component**:
   ```bash
   wasm-tools validate component.wasm
   wasm-tools component wit component.wasm
   ```
3. **Create policy** (optional but recommended)
4. **Authenticate to GHCR**
5. **Publish with wkg**
6. **Verify publication**

### Component Policy Configuration

Create `policy.yaml` for resource requirements:

```yaml
apiVersion: v1
kind: Policy
metadata:
  name: component-name
spec:
  # Network access
  network:
    allowed:
      - host: api.example.com
        port: 443
  
  # Filesystem access
  filesystem:
    allowed:
      - path: /tmp
        access: read-write
      - path: /data
        access: read-only
  
  # Environment variables
  environment:
    allowed:
      - API_KEY
      - DATABASE_URL
```

### GitHub Container Registry (GHCR) Authentication

**Create Personal Access Token**:
1. Go to https://github.com/settings/tokens
2. Generate token with `write:packages` and `read:packages` scopes

**Login methods**:

```bash
# Method 1: Docker config (persistent)
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Method 2: Environment variables (per-session)
export WKG_OCI_USERNAME="your-github-username"
export WKG_OCI_PASSWORD="ghp_your_token_here"
```

### Publishing to GHCR

**Basic publish**:
```bash
wkg oci push ghcr.io/username/component-name:v1.0.0 component.wasm
```

**With annotations** (recommended):
```bash
wkg oci push ghcr.io/username/component-name:v1.0.0 component.wasm \
  --annotation org.opencontainers.image.source="https://github.com/username/repo" \
  --annotation org.opencontainers.image.description="Component description" \
  --annotation org.opencontainers.image.licenses="MIT" \
  --annotation org.opencontainers.image.version="1.0.0"
```

### Registry Naming Conventions

**Format**: `ghcr.io/<username-or-org>/<component-name>:<tag>`

**Examples**:
- `ghcr.io/myorg/http-server:latest`
- `ghcr.io/myorg/data-processor:v1.2.3`
- `ghcr.io/myorg/utils:main`

### Tagging Strategy

- Use semantic versioning: `v1.0.0`, `v1.1.0`, `v2.0.0`
- Maintain `latest` tag for stable releases
- Use branch names for development: `main`, `develop`
- Use commit SHAs for specific builds: `sha-abc123`

### Common Annotations

```bash
--annotation org.opencontainers.image.source="REPO_URL"
--annotation org.opencontainers.image.description="SHORT_DESCRIPTION"
--annotation org.opencontainers.image.licenses="LICENSE_TYPE"
--annotation org.opencontainers.image.version="VERSION"
--annotation org.opencontainers.image.authors="AUTHOR"
--annotation org.opencontainers.image.documentation="DOCS_URL"
```

### Verify Publication

```bash
# List available tags
wkg oci list ghcr.io/username/component-name

# Pull and verify
wkg oci pull ghcr.io/username/component-name:v1.0.0 -o test.wasm
wasm-tools component wit test.wasm
```

### Making Components Public

**On GitHub**:
1. Go to package settings: `https://github.com/users/USERNAME/packages/container/COMPONENT/settings`
2. Scroll to "Danger Zone"
3. Click "Change visibility"
4. Select "Public"

### Consumption

Once published:

```bash
# Pull the component
wkg oci pull ghcr.io/username/component:latest -o component.wasm

# Run with wasmtime
wasmtime run component.wasm

# Or with Wassette (policy enforcement)
wassette run oci://ghcr.io/username/component:latest
```

### Publishing Troubleshooting

**"authentication required"**
- Ensure token has `write:packages` and `read:packages` scopes

**"unauthorized: access denied"**
- Check package visibility (private packages require auth on pull too)

**"manifest invalid"**
- Ensure you're pushing a valid .wasm component file

**"reference not found"**
- Verify registry URL format: `ghcr.io/user/name:tag`
- Do NOT include `oci://` prefix in wkg commands

### Best Practices

1. **Version everything**: Always use explicit version tags
2. **Add metadata**: Use annotations for discoverability
3. **Document policies**: Include policy.yaml for resource requirements
4. **Secure credentials**: Use environment variables or Docker config, never hardcode
5. **Test before publishing**: Validate component locally first
6. **Maintain latest**: Keep `latest` tag pointing to stable release
7. **Sign components**: Consider using cosign for supply chain security

---

## Workflow Patterns

### Create New Component

**Rust**:
```bash
cd components && cargo component new my-component --lib
```

**Python**:
```bash
cd components && mkdir my-component && cd my-component && mkdir wit
```

**JavaScript**:
```bash
cd components && mkdir my-component && cd my-component && npm init -y && mkdir wit src
```

**Go**:
```bash
cd components && mkdir my-component && cd my-component && go mod init my-component && mkdir wit
```

### Build → Test → Publish Sequence

```bash
# 1. Build
cd components/my-component
cargo component build --release --target wasm32-wasip2
cp target/wasm32-wasip2/release/my_component.wasm ../my-component.wasm

# 2. Test
wasmtime run --invoke 'process("test")' ../my-component.wasm

# 3. Validate
wasm-tools validate ../my-component.wasm
wasm-tools component wit ../my-component.wasm

# 4. Publish
wkg oci push ghcr.io/username/my-component:v1.0.0 ../my-component.wasm \
  --annotation org.opencontainers.image.source="https://github.com/username/repo"
```

### Integration with Justfile

The repository includes a Justfile for common tasks. Always check:
```bash
just --list
```

---

## Key Tool Installation

### wasmtime
```bash
# macOS/Linux
curl https://wasmtime.dev/install.sh -sSf | bash

# Or via package manager
brew install wasmtime
```

### wasm-tools
```bash
cargo install wasm-tools
```

### wkg
```bash
# Download from releases
curl -L https://github.com/bytecodealliance/wasm-pkg-tools/releases/latest/download/wkg-<platform> -o wkg
chmod +x wkg
sudo mv wkg /usr/local/bin/
```

---

## Additional Resources

- [wasmtime Documentation](https://docs.wasmtime.dev/)
- [Component Model Specification](https://component-model.bytecodealliance.org/)
- [awesome-wasm-components](https://github.com/yoshuawuyts/awesome-wasm-components)
- [WASI Preview 2](https://github.com/WebAssembly/WASI/tree/main/preview2)
- [WIT Specification](https://github.com/WebAssembly/component-model/blob/main/design/mvp/WIT.md)
