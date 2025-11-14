---
applyTo:
  - components/**/*.rs
  - components/**/*.py
  - components/**/*.js
  - components/**/*.go
  - components/**/*.toml
  - components/**/*.wit
  - components/**/README.md
  - components/**/USAGE.md
---

# WebAssembly Component Development Instructions

When working with files in the `components/` directory, follow these patterns for component development, building, and testing.

## Component Architecture

Each component is a standalone WebAssembly Component Model entity with:
- Source code in language-specific structure
- WIT interface definition in `wit/` subdirectory
- Built `.wasm` file at `components/component-name.wasm`
- Documentation in `README.md` and `USAGE.md`
- Test data in `examples/` subdirectory

## Language-Specific Patterns

### Rust Components

**Project structure**:
```
components/component-name/
├── Cargo.toml          # Package manifest
├── src/
│   └── lib.rs          # Component implementation
└── wit/
    └── world.wit       # Interface definition
```

**Cargo.toml requirements**:
```toml
[lib]
crate-type = ["cdylib"]

[dependencies]
wit-bindgen = "0.35.0"

[profile.release]
opt-level = "s"
lto = true
strip = true
```

**Build target**: `wasm32-wasip2`

**Build command**:
```bash
cargo component build --release --target wasm32-wasip2
```

**Output location**: `target/wasm32-wasip2/release/<name>.wasm`

### Python Components

**Project structure**:
```
components/component-name/
├── pyproject.toml      # Package configuration
├── app.py              # Component implementation
└── wit/
    └── world.wit       # Interface definition
```

**pyproject.toml requirements**:
```toml
[tool.componentize-py]
wit-path = "wit"
world = "component-name"
```

**Build commands**:
1. Generate bindings: `componentize-py bindings .`
2. Build component: `componentize-py componentize app -o ../component-name.wasm`

**Important**: Always regenerate bindings after WIT changes.

### JavaScript Components

**Project structure**:
```
components/component-name/
├── package.json        # Package configuration
├── src/
│   └── index.js        # Component implementation
└── wit/
    └── world.wit       # Interface definition
```

**package.json requirements**:
```json
{
  "type": "module",
  "scripts": {
    "build": "jco componentize src/index.js -w wit -o ../component-name.wasm"
  }
}
```

**Build command**:
```bash
npm run build
```

### Go Components

**Project structure**:
```
components/component-name/
├── go.mod              # Module definition
├── main.go             # Component implementation
└── wit/
    └── world.wit       # Interface definition
```

**main.go requirements**:
```go
//go:generate wit-bindgen-go generate --world component-name --out gen ./wit

func init() {
    // Register exports
}

func main() {} // Required but empty
```

**Build commands**:
1. Generate bindings: `go generate`
2. Build with TinyGo: `tinygo build -target=wasip2 -o ../component-name.wasm .`

## WIT Interface Patterns

### Basic Pattern

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
    import wasi:filesystem/types@0.2.0;
    
    export interface-name;
}

interface interface-name {
    run: func() -> result<_, string>;
}
```

### Type Definitions

```wit
record data {
    id: u32,
    name: string,
    values: list<f64>,
}

variant status {
    success(string),
    error(string),
}

enum priority {
    low,
    medium,
    high,
}
```

## Testing Components

Use wasmtime for immediate testing:

```bash
# Simple function call
wasmtime run --invoke 'process("test")' component.wasm

# With filesystem access
wasmtime run --dir ./data component.wasm

# With environment variables
wasmtime run --env KEY=value component.wasm
```

## Size Optimization

### Universal Optimization

```bash
wasm-opt -Os component.wasm -o component.opt.wasm
```

### Language-Specific

**Rust**: Use `opt-level = "z"` and `codegen-units = 1`
**Go**: Use `tinygo build -opt=z`
**Python**: Size dominated by runtime (minimize dependencies)
**JavaScript**: Use minification on source before build

## Validation

Always validate components before committing:

```bash
# Check validity
wasm-tools validate component.wasm

# Inspect interface
wasm-tools component wit component.wasm

# Check size
ls -lh component.wasm
```

## Documentation Requirements

### README.md Template

```markdown
# Component Name

Brief description of what this component does.

## Interface

Exported functions and types.

## Usage

wasmtime run examples/usage.wasm

## Building

Language-specific build instructions.

## Examples

References to example data in `examples/`.
```

### USAGE.md Template

```markdown
# Usage Examples

## Basic Usage
\`\`\`bash
wasmtime run component.wasm --invoke 'function("arg")'
\`\`\`

## With Options
\`\`\`bash
wasmtime run --dir ./data component.wasm
\`\`\`

## Example Inputs
See `examples/` directory for test data.
```

## Dependency Management

### Rust
- Use published crates from crates.io
- Avoid dependencies with C bindings
- Check WASI compatibility

### Python
- Pure Python only (no C extensions)
- Minimize dependencies (increases size)
- Test imports after componentization

### JavaScript
- Prefer browser-compatible packages
- Check Node.js API usage (may not work in WASI)
- Test in wasmtime before committing

### Go
- Use standard library when possible
- Check TinyGo compatibility
- Avoid cgo dependencies

## Error Handling Patterns

### Rust
```rust
impl Guest for Component {
    fn process(input: String) -> Result<String, String> {
        match validate(&input) {
            Ok(data) => Ok(format_output(data)),
            Err(e) => Err(format!("validation error: {}", e)),
        }
    }
}
```

### Python
```python
def process(self, input: str) -> Result[str, str]:
    try:
        data = validate(input)
        return Ok(format_output(data))
    except ValueError as e:
        return Err(f"validation error: {e}")
```

### JavaScript
```javascript
export const interfaceName = {
  process(input) {
    try {
      const data = validate(input);
      return { tag: 'ok', val: formatOutput(data) };
    } catch (e) {
      return { tag: 'err', val: `validation error: ${e.message}` };
    }
  }
};
```

### Go
```go
func (c *ComponentImpl) Process(input string) cm.Result[string, string, string] {
    data, err := validate(input)
    if err != nil {
        return cm.Err[cm.Result[string, string, string]](fmt.Sprintf("validation error: %v", err))
    }
    return cm.OK[cm.Result[string, string, string]](formatOutput(data))
}
```

## WASI Capabilities

When importing WASI interfaces:

- `wasi:cli/environment` - Access environment variables
- `wasi:cli/stdin` - Read from stdin
- `wasi:cli/stdout` - Write to stdout
- `wasi:cli/stderr` - Write to stderr
- `wasi:filesystem/types` - Filesystem types and operations
- `wasi:filesystem/preopens` - Access pre-opened directories
- `wasi:clocks/wall-clock` - Current time
- `wasi:random/random` - Random number generation
- `wasi:http/outgoing-handler` - Make HTTP requests
- `wasi:sockets/*` - Network operations

Always request minimal permissions required.

## Common Issues

### Rust
- **Compile errors about missing target**: Run `rustup target add wasm32-wasip2`
- **Large binary size**: Ensure `opt-level = "s"` in Cargo.toml release profile
- **Linker errors**: Check that `crate-type = ["cdylib"]` is set

### Python
- **Import errors in component**: Regenerate bindings with `componentize-py bindings .`
- **Module not found**: Ensure dependencies are pure Python
- **Large component size**: Expected (5-10MB includes Python runtime)

### JavaScript
- **Module resolution errors**: Verify `"type": "module"` in package.json
- **Cannot find jco**: Install globally with `npm install -g @bytecodealliance/jco`
- **Build fails**: Check Node.js version compatibility (v18+)

### Go
- **tinygo not found**: Install from https://tinygo.org/getting-started/install/
- **Unsupported feature**: Check TinyGo compatibility (not all stdlib works)
- **Import cycle**: Reorganize code to avoid circular dependencies

## Commit Checklist

Before committing component changes:

- [ ] Component builds without errors
- [ ] Tests pass with wasmtime
- [ ] `wasm-tools validate` passes
- [ ] WIT interface matches implementation
- [ ] README.md and USAGE.md updated
- [ ] Examples provided for non-trivial usage
- [ ] Size is reasonable for use case
- [ ] No sensitive data in examples
