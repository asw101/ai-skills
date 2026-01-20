# WebAssembly Components

This directory contains WebAssembly components built using the Component Model and WASI preview 2.

## Available Components

| Component | Language | Size | Description |
|-----------|----------|------|-------------|
| [csv-groupby](csv-groupby/README.md) | Rust | 175KB | SQL-like GROUP BY on CSV data (COUNT, SUM, AVG, MIN, MAX) |
| [stock-ticker](stock-ticker/README.md) | Go | 427KB | Stock price simulator for MSFT, AAPL, GOOGL, AMZN |
| [tech-ticker](tech-ticker/README.md) | Rust | 65KB | Health check and random string generation |
| time-server | JavaScript | 11MB | Current UTC time (from `ghcr.io/microsoft/time-server-js`) |

## Directory Structure

```
components/
├── component-name/           # Source code directory
│   ├── src/                 # Source files
│   ├── wit/                 # WIT interface definitions
│   └── README.md            # Component documentation
└── component-name.wasm      # Built component
```

## Skills

Use the following skills for working with components:

- **wasm-build** - Build components from source (Rust, Go, Python, JavaScript)
- **wasm-run** - Run and test components with wasmtime
- **wasm-search** - Find components in OCI registries
- **wasm-registry** - Pull/push components to OCI registries

See each component's README for detailed usage examples.
