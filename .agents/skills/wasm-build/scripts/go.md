# Go component cookbook

There are two supported flows for building components in Go:

1. **TinyGo** — `tinygo build -target=wasip2`. Native component output. Recommended for production.
2. **Standard Go** — `GOOS=wasip1 GOARCH=wasm go build` plus `wasm-tools component new --adapt`. Works since Go 1.21 (Go 1.24 added reactor/library support). GC has known issues with tagged-union types (`cm.Variant`, `cm.Result`).

Both flows use `wit-bindgen-go` from `go.bytecodealliance.org` (repo: <https://github.com/bytecodealliance/go-modules>, formerly `wasm-tools-go`).

## Choose a path

| You need… | Use |
|---|---|
| Smallest binary, native wasip2, fewest moving parts | **TinyGo** |
| Full Go stdlib, goroutines, large existing codebases | **Standard Go** (with adapter) |
| Heavy use of WIT `result<>` / `variant<>` | **TinyGo** (standard Go GC may panic on tagged unions — see "Standard Go caveats" below) |
| `wasi:http/proxy` server | Either — TinyGo first, fall back to standard Go if missing features |

## Prerequisites (both flows)

```bash
# wit-bindgen-go (Go binding generator) — works with both Go and TinyGo
go install go.bytecodealliance.org/cmd/wit-bindgen-go@v0.7.0

# wasm-tools (needed for the standard-Go adapter step; optional for TinyGo)
cargo install wasm-tools@1.248.0
```

## Flow A — TinyGo (native wasip2)

### Prerequisites

- Go 1.23 or newer.
- TinyGo 0.41.1+ (adds and stabilizes wasip2 work; 0.34 was the first wasip2-capable release).

```bash
# TinyGo (Linux .deb example)
wget https://github.com/tinygo-org/tinygo/releases/download/v0.41.1/tinygo_0.41.1_amd64.deb
sudo dpkg -i tinygo_0.41.1_amd64.deb

# macOS
brew install tinygo
```

### Capability snapshot (verify before committing to Go)

| Capability | Status |
|---|---|
| `wasi:cli/command` world | ✅ well-trodden path |
| Custom WIT exports/imports | ⚠️ supported by `wit-bindgen-go` but not all combinations work cleanly under TinyGo |
| `wasi:http` (proxy / outgoing-handler) | 🟡 emerging; verify against your TinyGo version |
| Standard Go GC + `cm.Result`/`cm.Variant` | ⚠️ tagged-union representation can fault under standard `go` GC. TinyGo is the recommended compiler. |

When in doubt, prefer Rust for components with rich custom WIT.

## Scaffold

```bash
cd components
mkdir my-component && cd my-component
go mod init my-component
mkdir wit
```

### Project layout

```
my-component/
├── go.mod
├── wit/
│   └── world.wit
├── gen/                    # generated bindings (after `go generate`)
└── main.go
```

### go.mod

```go
module my-component

go 1.23

require go.bytecodealliance.org v0.7.0
```

### wit/world.wit

```wit
package local:my-component;

world my-component {
  export process: func(input: string) -> result<string, string>;
}
```

### main.go

```go
package main

import (
    "go.bytecodealliance.org/cm"

    "my-component/gen/local/my-component/my-component"
)

//go:generate wit-bindgen-go generate --world my-component --out gen ./wit

func init() {
    mycomponent.Exports.Process = func(input string) cm.Result[string, string, string] {
        return cm.OK[cm.Result[string, string, string]]("Processed: " + input)
    }
}

func main() {}
```

The exact generated package path under `gen/` depends on the WIT package and world names; check `gen/` after running `go generate` and adjust the import.

### Build

```bash
go generate
tinygo build -target=wasip2 -o ../my-component.wasm .
wasm-tools validate ../my-component.wasm
```

---

## Flow B — Standard Go (`GOOS=wasip1` + adapter)

Standard Go targets WASI Preview 1 only. To produce a Component-Model component, build a core wasip1 module then wrap it with a wasmtime adapter.

### Prerequisites

- **Go 1.24+** (recommended). Go 1.21 added `GOOS=wasip1`; **Go 1.24 added reactor/library support**, which is required for components that export functions (rather than only `_start`).
- The `bytecodealliance/go-modules` Makefile runs CI against both `GOARCH=wasm GOOS=wasip1 go test` and TinyGo, confirming the path is supported.

### Get a preview1 adapter

Adapters are published with each `wasmtime` release. Pick by component shape:

```bash
# Pick ONE. wasmtime 44.0.0 used as example — match your runtime version.
WASMTIME=44.0.0
BASE="https://github.com/bytecodealliance/wasmtime/releases/download/v${WASMTIME}"
curl -L "${BASE}/wasi_snapshot_preview1.command.wasm" -O   # for CLIs (entry: _start)
curl -L "${BASE}/wasi_snapshot_preview1.reactor.wasm" -O   # for libraries (exported funcs)
curl -L "${BASE}/wasi_snapshot_preview1.proxy.wasm"   -O   # for wasi:http/proxy components
```

### main.go (reactor-style — exports a function)

```go
package main

import (
    "go.bytecodealliance.org/cm"

    mycomponent "my-component/gen/local/my-component/my-component"
)

//go:generate wit-bindgen-go generate --world my-component --out gen ./wit

func init() {
    mycomponent.Exports.Process = func(input string) cm.Result[string, string, string] {
        return cm.OK[cm.Result[string, string, string]]("Processed: " + input)
    }
}

// Required, but unused for reactors; the adapter handles entry.
func main() {}
```

### Build

```bash
go generate

# 1. Compile to a core wasip1 module.
GOOS=wasip1 GOARCH=wasm go build -o ../my-component.core.wasm .

# 2. Wrap as a Component using the reactor adapter.
wasm-tools component new ../my-component.core.wasm \
  --adapt wasi_snapshot_preview1=wasi_snapshot_preview1.reactor.wasm \
  -o ../my-component.wasm

# 3. Validate.
wasm-tools validate ../my-component.wasm
wasm-tools component wit ../my-component.wasm
```

For a CLI-style component (entry on `_start`, no custom exports), use `wasi_snapshot_preview1.command.wasm` as the adapter.

### Standard Go caveats

- **GC vs tagged unions.** `cm.Variant` and `cm.Result` represent WIT's `variant<>`/`result<>` as tagged unions where a non-pointer value can occupy a pointer-shaped slot. The standard Go GC may panic ("non-pointer value where pointer expected"). TinyGo's GC is unaffected. This is documented upstream; if you hit it, prefer TinyGo for the affected component.
- **Reactor mode requires Go 1.24+.** Older toolchains compile but produce only command-style modules (`_start`-only).
- **Goroutines / threading.** Standard Go's runtime works on wasip1 with cooperative scheduling, but blocking I/O is limited to what the adapter exposes.
- **Binary size.** A reactor-style standard-Go component is typically several MB (Go runtime baseline), much larger than TinyGo's 200 KB – 1 MB output.
- **No native wasip2 yet.** As of 2026-04, standard Go has no `GOOS=wasip2`. Watch <https://github.com/golang/go/issues/65199> for progress.

### Quick comparison

| Aspect | TinyGo `wasip2` | Standard Go `wasip1` + adapter |
|---|---|---|
| Output | Native component | Core module → wrapped to component |
| Size | 0.2–1 MB | 2–8 MB |
| WIT `variant`/`result` | ✅ stable | ⚠️ GC may panic |
| Goroutines | Limited | Cooperative |
| Stdlib coverage | Subset | Full |
| Component Model maturity | Active | Active via adapter |

---

## Pulling WIT from a registry

`wit-bindgen-go` can fetch WIT from OCI registries:

```bash
wit-bindgen-go generate ghcr.io/webassembly/wasi/http:0.2.0
```

Or pipe a fully-resolved WIT JSON document:

```bash
wasm-tools component wit -j --all-features ./wit | wit-bindgen-go generate -
```

## Tips

- **Smaller binaries:** `tinygo build -target=wasip2 -opt=z -o out.wasm .`.
- **Size breakdown:** `tinygo build -target=wasip2 -size=short -o out.wasm .`.
- TinyGo supports a strict subset of stdlib. Avoid heavy reflection, `text/template`, etc.
- **WASI 0.3 RC:** Go-flavor 0.3 components are **not viable today**. `wit-bindgen-go` v0.7.0 generates 0.3 binding types (`stream<>` / `future<>` / `error-context`, added in [v0.6.0](https://github.com/bytecodealliance/go-modules/blob/main/CHANGELOG.md#v060--2025-03-15)), but **TinyGo has no `wasip3` target** and **standard Go's preview1 adapters map only to WASI 0.2**, not 0.3. Use Rust for 0.3 today. See [`wasi-0.3.md`](./wasi-0.3.md).

## Troubleshooting

- **`tinygo: command not found`** → install from <https://tinygo.org/getting-started/install/>.
- **`wit-bindgen-go: command not found`** → `go install go.bytecodealliance.org/cmd/wit-bindgen-go@latest` and ensure `$GOBIN` (default `$HOME/go/bin`) is on `PATH`.
- **Old import path errors** (`github.com/bytecodealliance/wasm-tools-go`) → migrate to `go.bytecodealliance.org`.
- **Custom WIT not being recognized** (TinyGo) → verify TinyGo supports the world; `wasi:cli/command` is the safest bet. Try a Rust prototype first to isolate whether the problem is the WIT or the Go toolchain.
- **GC panic at runtime when using standard `go build`** → `cm.Variant`/`cm.Result` confuse the standard Go GC. Switch to TinyGo's `wasip2` target for that component.
- **`not a component` after standard Go build** → you forgot the adapter step. Run `wasm-tools component new ... --adapt wasi_snapshot_preview1=wasi_snapshot_preview1.reactor.wasm`.
- **Reactor exports missing with standard Go** → upgrade to Go 1.24+; older Go produces command-style only.
