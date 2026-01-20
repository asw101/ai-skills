# WebAssembly Components

This directory contains all WebAssembly components built using the Component Model and WASI preview 2.

## Directory Structure

```
components/
├── component-name/           # Source code directory
│   ├── src/                 # Source files
│   ├── wit/                 # WIT interface definitions
│   ├── Cargo.toml           # Build configuration
│   ├── build.sh             # Build script
│   ├── USAGE.md             # Usage documentation
│   ├── README.md            # Component overview
│   └── examples/            # Sample data and tests
└── component-name.wasm      # Built component (sibling to source)
```

## Available Components

### csv-groupby (Rust)
**File**: `csv-groupby.wasm` (175KB)
**Interface**: `csv:groupby/groupby`
**Description**: Performs SQL-like GROUP BY operations on CSV data with aggregations (COUNT, SUM, AVG, MIN, MAX)
**Source**: Built locally from `csv-groupby/`

**Usage**:
```bash
wasmtime run --invoke 'execute-group-by({
  csv-data: "region,sales\nNorth,1000\nSouth,2000",
  group-columns: ["region"],
  aggregations: [{column: "sales", operation: sum, alias: some("total")}],
  has-header: true
})' components/csv-groupby.wasm
```

See [csv-groupby/README.md](csv-groupby/README.md) for detailed documentation.

### stock-ticker (Go)
**File**: `stock-ticker.wasm` (427KB)
**Interface**: `stock:ticker/ticker`
**Description**: Simulates a stock ticker for tech stocks (MSFT, AAPL, GOOGL, AMZN) with realistic price movements
**Source**: Built locally from `stock-ticker/`

**Usage**:
```bash
# Get price for a specific stock
wasmtime run --invoke 'get-price(msft)' components/stock-ticker.wasm

# Get all stock prices
wasmtime run --invoke 'get-all-prices()' components/stock-ticker.wasm

# Simulate price updates
wasmtime run --invoke 'tick({symbols: [msft, aapl], interval-ms: 100, duration-sec: 1})' components/stock-ticker.wasm
```

See [stock-ticker/README.md](stock-ticker/README.md) for detailed documentation.

### tech-ticker (Rust)
**File**: `tech-ticker.wasm` (65KB)
**Interface**: `component:tech-ticker/ticker`
**Description**: Lightweight utility component with health check and random string generation
**Source**: Built locally from `tech-ticker/`

**Usage**:
```bash
# Health check
wasmtime run --invoke 'ping()' components/tech-ticker.wasm

# Generate random string
wasmtime run --invoke 'random-string(16)' components/tech-ticker.wasm
```

See [tech-ticker/README.md](tech-ticker/README.md) for detailed documentation.

### time-server (JavaScript)
**File**: `time-server.wasm` (11MB)
**Interface**: `local:time-server/time`
**Description**: Returns the current UTC time in ISO 8601 format
**Source**: `ghcr.io/microsoft/time-server-js:latest`

**Usage**:
```bash
wasmtime run --invoke 'get-current-time()' components/time-server.wasm
```

## Building Components

### Prerequisites

Install the wasm-build skill dependencies for your language:

**Rust**:
```bash
rustup target add wasm32-wasip2
cargo install cargo-component
```

**Python**:
```bash
pip install componentize-py
```

**JavaScript**:
```bash
npm install -g @bytecodealliance/jco @bytecodealliance/componentize-js
```

**Go**:
```bash
brew install tinygo  # or download from tinygo.org
go install github.com/bytecodealliance/wit-bindgen-go/cmd/wit-bindgen-go@latest
```

### Build a specific component

```bash
cd components/component-name
./build.sh
```

Or manually:

**Rust**:
```bash
cd components/component-name
cargo component build --release --target wasm32-wasip2
cp target/wasm32-wasip2/release/component_name.wasm ../component-name.wasm
```

**Python**:
```bash
cd components/component-name
componentize-py componentize app -o ../component-name.wasm
```

**JavaScript**:
```bash
cd components/component-name
jco componentize src/index.js -w wit -o ../component-name.wasm
```

**Go**:
```bash
cd components/component-name
go generate
tinygo build -target=wasip2 -o ../component-name.wasm .
```

### Build all components

```bash
for dir in components/*/; do
  if [ -x "$dir/build.sh" ]; then
    (cd "$dir" && ./build.sh)
  fi
done
```

## Testing Components

### Validate

```bash
wasm-tools validate components/component-name.wasm
```

### Inspect interface

```bash
wasm-tools component wit components/component-name.wasm
```

### Run with wasmtime

```bash
wasmtime run --invoke 'function-name(args)' components/component-name.wasm
```

## Creating New Components

Use the `wasm-build` skill to create new components:

```bash
# Activate the skill in Claude Code, then:
# "Create a new Rust component called my-component"
```

Or manually:

**Rust**:
```bash
cd components
cargo component new my-component --lib
```

**Python**:
```bash
cd components
mkdir my-component && cd my-component && mkdir wit
```

**JavaScript**:
```bash
cd components
mkdir my-component && cd my-component && npm init -y && mkdir wit src
```

**Go**:
```bash
cd components
mkdir my-component && cd my-component && go mod init my-component && mkdir wit
```

## Component Size Reference

| Language | Typical Size | Build Time | Best For |
|----------|-------------|------------|----------|
| Rust | 100-300KB | Slow | Performance, small size |
| Python | 5-10MB | Fast | Rapid development |
| JavaScript | 500KB-2MB | Fast | Web integration |
| Go (TinyGo) | 200KB-1MB | Fast | Systems programming |

## Publishing Components

Components can be published to OCI registries (such as Github Packages registry) using `wkg`:

```bash
./.agent/skills/wasm-registry/scripts/run-wkg.sh oci push \
  ghcr.io/username/component-name:latest \
  components/component-name.wasm
```

See the `wasm-oci` skill for details.

## Documentation

- See `.agent/skills/wasm-build/SKILL.md` for comprehensive build instructions
- Each component has its own `USAGE.md` with detailed examples
- WIT interfaces are documented in each component's `wit/` directory
