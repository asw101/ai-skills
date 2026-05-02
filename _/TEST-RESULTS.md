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

### github-rs (Rust / WASI P3) ✅

```bash
component run --inherit-network ./bin/github-rs.wasm api get-user octocat "$GH_TOKEN"
# → {"bio":null,"followers":22508,"following":9,"html-url":"https://github.com/octocat",
#    "id":583231,"login":"octocat","name":"The Octocat","public-repos":8}

component run --inherit-network ./bin/github-rs.wasm api get-repo octocat Hello-World "$GH_TOKEN"
# → {"default-branch":"master","description":"My first repository on GitHub!",
#    "forks-count":6063,"full-name":"octocat/Hello-World","stargazers-count":3569,...}
```

Both `get-user` and `get-repo` pass with `GH_TOKEN` supplied as the positional token argument.

---

### github-py (Python / WASI P3) ✅

```bash
component run --inherit-network ./bin/github-py.wasm api get-user octocat "$GH_TOKEN"
# → {"bio":null,"followers":22508,...,"login":"octocat","name":"The Octocat",...}

component run --inherit-network ./bin/github-py.wasm api get-repo octocat Hello-World "$GH_TOKEN"
# → {"default-branch":"master","forks-count":6063,...}
```

Both exports pass. Output is identical to `github-rs`, confirming the shared WIT contract.

---

### github-go (Go / WASI P2) ❌

```bash
component run --inherit-network ./bin/github-go.wasm api get-user octocat "$GH_TOKEN"
# → http: TLS-protocol-error
```

TLS handshake fails regardless of token. Likely a TLS stack incompatibility between the Go/TinyGo WASM HTTP implementation and the wasmtime embedded HTTP stack used by `component run`.

---

### github-js (JavaScript / WASI P2) ❌

```bash
component run --inherit-network ./bin/github-js.wasm api get-user octocat "$GH_TOKEN"
# → expected a string
#   Stack: utf8Encode@.../initializer.js:140
```

Crashes even with a valid token. The JS component's `utf8Encode` call receives an unexpected value — likely a WIT `option<string>` serialisation mismatch between the dynamic sub-CLI and the jco runtime. The crash is the same with or without a token.

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
| github-rs     | Rust        | P3   | ✅ pass | `get-user` + `get-repo` pass with GH_TOKEN |
| github-py     | Python      | P3   | ✅ pass | `get-user` + `get-repo` pass with GH_TOKEN; output matches rs |
| github-go     | Go/TinyGo   | P2   | ❌ fail | TLS-protocol-error regardless of token |
| github-js     | JavaScript  | P2   | ❌ fail | Crashes on `option<string>` CLI encoding (with or without token) |
| copilot-rs    | Rust        | P3   | ⚠️ stream | `stream<string>` not supported by `component run` CLI |
| copilot-py    | Python      | P3   | ⚠️ stream | `stream<string>` not supported by `component run` CLI |
| time-server   | JavaScript  | HTTP | ❌ fail | WIT world not recognized by runtime |

### Pass: 5 | Partial/Blocked: 3 | Fail: 3

## Issues Found

1. **github-go TLS error** — The Go/TinyGo HTTP client fails TLS inside the `component run` wasmtime runtime. Worth investigating whether a newer TinyGo build or a different TLS config resolves this.

2. **github-js `option<string>` encoding** — The JS component crashes in `utf8Encode` regardless of whether a token is passed. The dynamic sub-CLI's `option<string>` serialisation is incompatible with the jco runtime's expectation. The Rust and Python implementations handle the same WIT interface correctly.

3. **time-server WIT world** — `component run` fails to find the WIT world `"time-server"`. This may be a naming mismatch between how the Microsoft JS image embeds its WIT and what `component 0.3.0` expects.

4. **csv-groupby complex types** — Nested record lists (`list<aggregation>`) are not expressible through the dynamic sub-CLI. A JSON-based input mode would unlock this.

5. **copilot stream support** — `stream<string>` (WASI 0.3 async) is not yet supported by `component run`'s CLI dispatch. These components require a WASI P3-aware runner.
