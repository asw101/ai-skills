# WebAssembly Components

This directory contains WebAssembly components built using the Component Model and WASI Preview 2 / 3.

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

## Further reading

See each component's `README.md` for usage examples. For build / run /
publish task → cookbook mapping see [`../docs/components.md`](../docs/components.md);
for skill-routing policy see [`../AGENTS.md`](../AGENTS.md).
