# Curated component catalog

Static fallback when [`awesome-wasm-components`](https://github.com/yoshuawuyts/awesome-wasm-components)
(via WebFetch) and a meta-registry are both unavailable.

This file will be deprecated when `component registry search` against a
real meta-registry is reliable; until then, agents may use these OCI
references with `wkg oci pull`.

Last refresh: 2026-04-29.

---

## Applications

Binary-shaped components (typically `wasi:http` or `wasi:cli`).

| OCI ref | Language | Description |
|---|---|---|
| `ghcr.io/bytecodealliance/sample-wasi-http-rust/sample-wasi-http-rust:latest` | Rust | Sample wasi:http server written in Rust |

## Libraries

Library-shaped components callable from any host language.

| OCI ref | Language | Description |
|---|---|---|
| `ghcr.io/microsoft/arxiv-rs:latest` | Rust | An arXiv research component for searching and downloading papers written in Rust |
| `ghcr.io/microsoft/brave-search-rs:latest` | Rust | A web search component using Brave Search API written in Rust |
| `ghcr.io/microsoft/context7-rs:latest` | Rust | A library documentation search component using Context7 API written in Rust |
| `ghcr.io/microsoft/eval-py:latest` | Python | A Python expression evaluation component |
| `ghcr.io/microsoft/fetch-rs:latest` | Rust | A fetch component written in Rust |
| `ghcr.io/microsoft/filesystem-rs:latest` | Rust | A filesystem component written in Rust |
| `ghcr.io/microsoft/get-open-meteo-weather-js:latest` | JavaScript | A weather component using Open-Meteo API written in JavaScript |
| `ghcr.io/microsoft/get-weather-js:latest` | JavaScript | A weather component written in JavaScript |
| `ghcr.io/microsoft/github-js:latest` | JavaScript | A comprehensive GitHub REST API component written in JavaScript |
| `ghcr.io/microsoft/gomodule-go:latest` | Go | A Go module component |
| `ghcr.io/microsoft/memory-js:latest` | JavaScript | A knowledge graph memory storage component written in JavaScript |
| `ghcr.io/microsoft/time-server-js:latest` | JavaScript | A time server component written in JavaScript |

## Interfaces (WIT)

WIT interface packages (not executable; use as build dependencies).

| OCI ref | Language | Description |
|---|---|---|
| `ghcr.io/webassembly/wasi/io:0.2.0` | — | Standard interfaces for I/O stream abstractions |
| `ghcr.io/webassembly/wasi/clocks:0.2.0` | — | Standard interfaces for reading the current time and measuring elapsed time |
| `ghcr.io/webassembly/wasi/random:0.2.0` | — | Standard interfaces for obtaining pseudo-random data |
| `ghcr.io/webassembly/wasi/filesystem:0.2.0` | — | Standard interfaces for interacting with filesystems |
| `ghcr.io/webassembly/wasi/sockets:0.2.0` | — | Standard interfaces for TCP, UDP, and domain name lookup |
| `ghcr.io/webassembly/wasi/cli:0.2.0` | — | Standard interfaces for Command-Line environments |

