# Build Component Workflow

This prompt template guides you through creating a new WebAssembly component from scratch.

## Step 1: Choose Language

Select the language based on your requirements:

**Rust** - Best for:
- Small size (100-300KB)
- High performance
- Low-level control
- When build time is not critical

**Python** - Best for:
- Rapid development
- Rich ecosystem of pure Python libraries
- When size (5-10MB) is acceptable
- Prototyping and iteration

**JavaScript** - Best for:
- Web integration
- Familiar syntax
- Medium size (500KB-2MB)
- Fast development cycle

**Go** - Best for:
- Systems programming
- Fast builds
- Small size (200KB-1MB)
- Concurrent operations

**Your choice**: [LANGUAGE]

---

## Step 2: Define Interface

Design the WIT interface for your component:

```wit
package namespace:component-name;

world component-name {
    // What WASI capabilities do you need?
    // Uncomment as needed:
    // import wasi:cli/environment@0.2.0;
    // import wasi:filesystem/types@0.2.0;
    // import wasi:http/outgoing-handler@0.2.0;
    
    export interface-name;
}

interface interface-name {
    // Define your exported functions:
    // Example:
    // process: func(input: string) -> result<string, string>;
}
```

**Your interface**: [WIT_DEFINITION]

---

## Step 3: Scaffold Project

### For Rust:
```bash
cd components
cargo component new [component-name] --lib
cd [component-name]
```

### For Python:
```bash
cd components
mkdir [component-name]
cd [component-name]
mkdir wit
```

### For JavaScript:
```bash
cd components
mkdir [component-name]
cd [component-name]
npm init -y
mkdir wit src
```

### For Go:
```bash
cd components
mkdir [component-name]
cd [component-name]
go mod init [component-name]
mkdir wit
```

**Component name**: [COMPONENT_NAME]

---

## Step 4: Configure Build

### Rust (Cargo.toml):
```toml
[package]
name = "[component-name]"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib"]

[dependencies]
wit-bindgen = "0.35.0"
# Add other dependencies

[profile.release]
opt-level = "s"
lto = true
strip = true
```

### Python (pyproject.toml):
```toml
[project]
name = "[component-name]"
version = "0.1.0"
requires-python = ">=3.10"
dependencies = []

[tool.componentize-py]
wit-path = "wit"
world = "[component-name]"
```

### JavaScript (package.json):
```json
{
  "name": "[component-name]",
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "build": "jco componentize src/index.js -w wit -o ../[component-name].wasm"
  },
  "devDependencies": {
    "@bytecodealliance/componentize-js": "^0.11.0",
    "@bytecodealliance/jco": "^1.0.0"
  }
}
```

### Go (main.go):
```go
package main

import "github.com/bytecodealliance/wasm-tools-go/cm"

//go:generate wit-bindgen-go generate --world [component-name] --out gen ./wit

func init() {
    a := &ComponentImpl{}
    exports.SetExportsNamespaceComponentNameInterface(a)
}

type ComponentImpl struct{}

func main() {}
```

---

## Step 5: Implement

Implement your component logic following language-specific patterns.

**Implementation checklist**:
- [ ] Error handling implemented
- [ ] Edge cases covered
- [ ] Input validation included
- [ ] Output formatting correct
- [ ] Memory efficiency considered

---

## Step 6: Build

### Rust:
```bash
cargo component build --release --target wasm32-wasip2
cp target/wasm32-wasip2/release/[component_name].wasm ../[component-name].wasm
```

### Python:
```bash
componentize-py bindings .
componentize-py componentize app -o ../[component-name].wasm
```

### JavaScript:
```bash
npm install
npm run build
```

### Go:
```bash
go generate
tinygo build -target=wasip2 -o ../[component-name].wasm .
```

**Build output**: `components/[component-name].wasm`

---

## Step 7: Test

```bash
# Validate
wasm-tools validate components/[component-name].wasm

# Inspect interface
wasm-tools component wit components/[component-name].wasm

# Run basic test
wasmtime run components/[component-name].wasm

# Run with permissions (if needed)
wasmtime run --dir ./test-data --env KEY=value components/[component-name].wasm

# Check size
ls -lh components/[component-name].wasm
```

**Test results**: [PASS/FAIL]

---

## Step 8: Optimize (Optional)

```bash
# Optimize with wasm-opt
wasm-opt -Os components/[component-name].wasm -o components/[component-name].opt.wasm
mv components/[component-name].opt.wasm components/[component-name].wasm

# Verify still works
wasmtime run components/[component-name].wasm
```

**Size before**: [SIZE_BEFORE]
**Size after**: [SIZE_AFTER]

---

## Step 9: Document

Create `README.md`:
```markdown
# [Component Name]

Brief description.

## Interface

Exported functions and types.

## Usage

\`\`\`bash
wasmtime run components/[component-name].wasm
\`\`\`

## Building

[Build instructions]

## Examples

[Usage examples]
```

Create `USAGE.md` with detailed examples.

---

## Step 10: Publish (Optional)

```bash
# Authenticate
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Publish
wkg oci push ghcr.io/[username]/[component-name]:v1.0.0 components/[component-name].wasm \
  --annotation org.opencontainers.image.source="[REPO_URL]" \
  --annotation org.opencontainers.image.description="[DESCRIPTION]" \
  --annotation org.opencontainers.image.licenses="[LICENSE]"

# Verify
wkg oci list ghcr.io/[username]/[component-name]
```

**Published**: [YES/NO]
**Registry URL**: [URL]

---

## Completion Checklist

- [ ] Language selected and justified
- [ ] WIT interface defined
- [ ] Project scaffolded
- [ ] Build configured
- [ ] Logic implemented
- [ ] Component builds successfully
- [ ] Tests pass with wasmtime
- [ ] Validation passes
- [ ] Size acceptable for use case
- [ ] README.md created
- [ ] USAGE.md created
- [ ] Examples provided
- [ ] Published (if sharing)

---

## Common Issues

**Rust**:
- Missing target → `rustup target add wasm32-wasip2`
- Large binary → Check Cargo.toml profile settings

**Python**:
- Import errors → Run `componentize-py bindings .` again
- C extensions → Use pure Python alternatives

**JavaScript**:
- Module errors → Ensure `"type": "module"` in package.json
- Build fails → Check Node.js version (v18+)

**Go**:
- TinyGo not found → Install from https://tinygo.org
- Unsupported feature → Check TinyGo compatibility docs
