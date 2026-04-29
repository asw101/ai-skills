# WebAssembly Components

This directory contains WebAssembly components built using the Component Model and WASI Preview 2 / 3.

## Available Components

| Component | Language | Size | Description |
|-----------|----------|------|-------------|
| [csv-groupby](csv-groupby/README.md) | Rust | 147KB | SQL-like GROUP BY on CSV data (COUNT, SUM, AVG, MIN, MAX) |
| [stock-ticker](stock-ticker/README.md) | Go | 551KB | Stock price simulator for MSFT, AAPL, GOOGL, AMZN |
| [tech-ticker](tech-ticker/README.md) | Rust | 62KB | Health check and random string generation |
| [wasip3-demo](wasip3-demo/README.md) | Rust | 62KB | Minimal **WASI 0.3** example: sync + `async func` exports |
| github ([rs](github-rs/README.md) / [py](github-py/README.md) / [js](github-js/README.md) / [go](github-go/README.md)) | Rust + Python + JS + Go | 179KB / 19MB / 14MB / 1.2MB | GitHub API client (user / repo) — same WIT, four languages — **Rust + Python on WASI 0.3**, JS + Go still on 0.2; built with [wasm-build-multi](../.agents/skills/wasm-build-multi/SKILL.md) |
| time-server | JavaScript | 11MB | Current UTC time (from `ghcr.io/microsoft/time-server-js`) |

## Directory Structure

```
components/
├── component-name/           # Source code directory
│   ├── src/                 # Source files
│   ├── wit/                 # WIT interface definitions
│   └── README.md            # Component documentation
└── bin/                     # Built .wasm artifacts
    └── component-name.wasm
```

## Further reading

See each component's `README.md` for usage examples. For build / run /
publish task → cookbook mapping see [`../docs/components.md`](../docs/components.md);
for skill-routing policy see [`../AGENTS.md`](../AGENTS.md).
