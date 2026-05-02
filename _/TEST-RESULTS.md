# Component Test Results

**Date**: 2026-05-02  
**Tool**: `component` v0.3.0 (from `asw101/component-registry` release `v0.4.0`)  
**Binary**: `component-x86_64-unknown-linux-gnu.tar.gz`  
**Skill**: `.agents/skills/component/SKILL.md`

## Setup

```bash
# Binary installed at:
.agents/skills/component/scripts/component

# All 11 pre-built .wasm files found in components/bin/:
component local list
```

```
╭────┬─────────────────────────╮
│ #  ┆ File Path               │
╞════╪═════════════════════════╡
│ 1  ┆ ./bin/copilot-py.wasm   │
│ 2  ┆ ./bin/copilot-rs.wasm   │
│ 3  ┆ ./bin/csv-groupby.wasm  │
│ 4  ┆ ./bin/github-go.wasm    │
│ 5  ┆ ./bin/github-js.wasm    │
│ 6  ┆ ./bin/github-py.wasm    │
│ 7  ┆ ./bin/github-rs.wasm    │
│ 8  ┆ ./bin/stock-ticker.wasm │
│ 9  ┆ ./bin/tech-ticker.wasm  │
│ 10 ┆ ./bin/time-server.wasm  │
│ 11 ┆ ./bin/wasip3-demo.wasm  │
╰────┴─────────────────────────╯
```

## Test Results

### tech-ticker (Rust / WASI P2) ✅

```bash
component run ./bin/tech-ticker.wasm ticker ping
# → tech-ticker ready

component run ./bin/tech-ticker.wasm ticker random-string 10
# → inmKEkaOzz
```

Both exports work. The dynamic sub-CLI correctly introspects the `ticker` world.

---

### stock-ticker (Go / WASI P2) ✅

```bash
component run ./bin/stock-ticker.wasm ticker get-price msft
# → {"price": 420.5, "symbol": "msft", "timestamp": 43}

component run ./bin/stock-ticker.wasm ticker get-all-prices
# → [{"price":420.5,"symbol":"msft",...}, {"price":185.75,"symbol":"aapl",...}, ...]

component run ./bin/stock-ticker.wasm ticker tick --interval-ms 100 --duration-sec 1
# → [] (empty — tick streaming appears to return no events in the current build)
```

`get-price` and `get-all-prices` pass. `tick` loads and accepts args but returns `[]`.

---

### wasip3-demo (Rust / WASI P3) ✅

```bash
component run ./bin/wasip3-demo.wasm greet p2
# → Hello sync, p2!

component run ./bin/wasip3-demo.wasm greet-async p3
# → Hello async, p3!
```

Both sync and async exports work with `component run`.

---

### csv-groupby (Rust / WASI P2) ⚠️

```bash
component run ./bin/csv-groupby.wasm groupby execute-group-by \
  --csv-data "a,b\n1,2\n1,3" --group-columns a --has-header true
# → Error: unsupported argument type for `aggregations`: nested record list not supported as CLI input
```

The component loads and its WIT is correctly introspected. The `aggregations` parameter (`list<aggregation>` where `aggregation` is a record) cannot be passed through the dynamic sub-CLI. This is a known limitation of `component run` for complex nested record list types — not a defect in the component itself.

---

### github-rs (Rust / WASI P3) ⚠️ needs GH_TOKEN

```bash
component run --inherit-network ./bin/github-rs.wasm api get-user octocat none
# → HTTP 401: {"message": "Bad credentials", ...}
```

Network connectivity confirmed. Returns 401 without a token, as expected.

---

### github-py (Python / WASI P3) ⚠️ needs GH_TOKEN

```bash
component run --inherit-network ./bin/github-py.wasm api get-user octocat none
# → RuntimeError: HTTP 401: {"message": "Bad credentials", ...}
```

Network connectivity confirmed. Returns 401 without a token. Error surfaced as a Python `RuntimeError` propagated through the WASM runtime.

---

### github-go (Go / WASI P2) ❌

```bash
component run --inherit-network ./bin/github-go.wasm api get-user octocat none
# → http: TLS-protocol-error
```

TLS handshake fails. Likely a TLS stack incompatibility between the Go/TinyGo WASM HTTP implementation and the wasmtime embedded HTTP stack used by `component run`.

---

### github-js (JavaScript / WASI P2) ❌

```bash
component run --inherit-network ./bin/github-js.wasm api get-user octocat none
# → expected a string
#   Stack: utf8Encode@.../initializer.js:140
```

Crashes when the optional `token` parameter receives the string `"none"` — the JS component expects an actual option type / null, not the string `"none"`. The dynamic sub-CLI serialises the `none` keyword as the literal string `"none"` rather than as a WIT `option<string>`.

---

### copilot-rs (Rust / WASI P3) ⚠️ stream not supported

```bash
component run ./bin/copilot-rs.wasm --help
# → Error: unsupported WIT type kind: stream
```

The copilot components export `stream<string>` (WASI 0.3 async streams). `component run`'s dynamic sub-CLI does not yet support `stream` WIT types, so the interface cannot be introspected. The component file is valid.

---

### copilot-py (Python / WASI P3) ⚠️ stream not supported

```bash
component run ./bin/copilot-py.wasm --help
# → Error: unsupported WIT type kind: stream
```

Same as `copilot-rs` — `stream<string>` exports block CLI introspection.

---

### time-server (JavaScript / HTTP) ❌

```bash
component run ./bin/time-server.wasm
# → Error: failed to decode component WIT: missing world "time-server"
```

`component run` cannot decode the WIT world. The binary is a valid WebAssembly module (`wasm binary module version 0x1000d`) sourced from `ghcr.io/microsoft/time-server-js`, but its embedded WIT world name is not recognized by this version of the `component` runtime.

---

## Summary

| Component     | Language    | WASI | Status | Notes |
|---------------|-------------|------|--------|-------|
| tech-ticker   | Rust        | P2   | ✅ pass | `ping` + `random-string` work |
| stock-ticker  | Go/TinyGo   | P2   | ✅ pass | `get-price` + `get-all-prices` work; `tick` returns `[]` |
| wasip3-demo   | Rust        | P3   | ✅ pass | sync `greet` + async `greet-async` both pass |
| csv-groupby   | Rust        | P2   | ⚠️ partial | loads OK; `aggregations` nested record list unsupported in CLI |
| github-rs     | Rust        | P3   | ⚠️ auth | HTTP 401 without GH_TOKEN; network works |
| github-py     | Python      | P3   | ⚠️ auth | HTTP 401 without GH_TOKEN; network works |
| github-go     | Go/TinyGo   | P2   | ❌ fail | TLS-protocol-error |
| github-js     | JavaScript  | P2   | ❌ fail | Crashes on `option<string>` CLI encoding as `"none"` |
| copilot-rs    | Rust        | P3   | ⚠️ stream | `stream<string>` not supported by `component run` CLI |
| copilot-py    | Python      | P3   | ⚠️ stream | `stream<string>` not supported by `component run` CLI |
| time-server   | JavaScript  | HTTP | ❌ fail | WIT world not recognized by runtime |

### Pass: 3 | Partial/Auth: 5 | Fail: 3

## Issues Found

1. **github-go TLS error** — The Go/TinyGo HTTP client fails TLS inside the `component run` wasmtime runtime. Worth investigating whether a newer TinyGo build or a different TLS config resolves this.

2. **github-js `option<string>` encoding** — The dynamic sub-CLI passes the literal string `"none"` for option params; JS component panics on this. Either the sub-CLI should serialize `none` as a proper WIT option, or the JS component should handle the string fallback.

3. **time-server WIT world** — `component run` fails to find the WIT world `"time-server"`. This may be a naming mismatch between how the Microsoft JS image embeds its WIT and what `component 0.3.0` expects.

4. **csv-groupby complex types** — Nested record lists (`list<aggregation>`) are not expressible through the dynamic sub-CLI. A JSON-based input mode would unlock this.

5. **copilot stream support** — `stream<string>` (WASI 0.3 async) is not yet supported by `component run`'s CLI dispatch. These components require a WASI P3-aware runner.
