# `wasm-tools` cookbook

[`wasm-tools`](https://github.com/bytecodealliance/wasm-tools) is the Bytecode
Alliance Swiss army knife for `.wasm` files: validate, inspect, transform,
embed/extract WIT, manipulate metadata, convert between WAT and binary.

When to reach for `wasm-tools` instead of `component`:

| Task | Tool |
|---|---|
| Validate a `.wasm` file | `wasm-tools validate` |
| Print a component's WIT interface | `wasm-tools component wit` |
| Convert a core module → component | `wasm-tools component new` (with optional adapter) |
| Embed WIT into a core module | `wasm-tools component embed` |
| Disassemble to WAT | `wasm-tools print` |
| Add/inspect custom metadata | `wasm-tools metadata add/show` |
| Compose components manually | `wasm-tools compose` (or `wac` — see `component` for the recommended flow) |

For the run/install/publish lifecycle, prefer the `component` skill.

---

## Binary resolution

```bash
SKILL_DIR=".agents/skills/wasm-toolchain"
WASM_TOOLS="$SKILL_DIR/scripts/wasm-tools"
[ -x "$WASM_TOOLS" ] || WASM_TOOLS="wasm-tools"
```

Install/refresh via `just install-wasm-tools .agents/skills/wasm-toolchain/scripts`.

---

## Validate

```bash
$WASM_TOOLS validate path/to/file.wasm
```

Exits non-zero with a parse error on malformed files. Validates against the
component-model spec when the input is a component.

---

## Inspect a component

### Print WIT interface

```bash
$WASM_TOOLS component wit path/to/component.wasm
# or write to file:
$WASM_TOOLS component wit path/to/component.wasm -o component.wit
```

This is the canonical way to learn what a component imports/exports without
running it. Useful immediately after `wkg oci pull`.

### Disassemble to WAT

```bash
$WASM_TOOLS print path/to/file.wasm | head -50
```

For a component, this expands the component-model section into nested
WAT — readable but verbose.

### Hex dump

```bash
$WASM_TOOLS dump path/to/file.wasm | head -30
```

Shows section headers and offsets — useful for diagnosing custom-section
issues.

### Show metadata

```bash
$WASM_TOOLS metadata show path/to/component.wasm
```

Reports producer information (toolchain that built the component) plus any
custom metadata fields.

---

## Transform: core module → component

Many language toolchains (especially Rust `wasm32-wasip1` builds and TinyGo's
older targets) emit core modules. To turn a core module into a WASI 0.2
component, embed a WIT world and run the adapter:

```bash
# 1. Embed WIT into the core module
$WASM_TOOLS component embed wit/ core-module.wasm -o module-with-wit.wasm

# 2. Wrap as a component, applying the wasi_snapshot_preview1 adapter
$WASM_TOOLS component new module-with-wit.wasm \
    --adapt wasi_snapshot_preview1=wasi_snapshot_preview1.reactor.wasm \
    -o component.wasm
```

**Adapter sources:**
- Latest releases: <https://github.com/bytecodealliance/wasmtime/releases>
  (look for `wasi_snapshot_preview1.{command,reactor}.wasm`)
- `command` adapter for CLI-style components (has `_start` entry point)
- `reactor` adapter for library-style components (no `_start`, exports only)

Note: TinyGo's `-target=wasip2` does this automatically (it shells out to
`wasm-tools component embed` — that's why the `install-tinygo` Justfile recipe
warns when `wasm-tools` is missing).

---

## Transform: extract a core module

```bash
$WASM_TOOLS component extract path/to/component.wasm -o core-module.wasm
```

Inverse of `component new` — useful for inspecting the embedded core module
or feeding it into another component pipeline.

---

## Add custom metadata

```bash
$WASM_TOOLS metadata add path/to/component.wasm \
    --name "csv-groupby" \
    --producers-language "rust:1.85" \
    -o path/to/component-with-meta.wasm
```

Custom metadata fields appear in `metadata show` and most registry UIs.

---

## Compose components (low-level)

`wasm-tools compose` takes a YAML/TOML spec and produces a composed component.
For most composition work, prefer the WAC-based flow documented in the
`component` skill (`component compose`) and the `wasm-build`
composition cookbook. `wasm-tools compose` is the lower-level building block.

---

## Common pipelines

### Pull → validate → inspect

```bash
$WKG oci pull ghcr.io/microsoft/fetch-rs:latest -o /tmp/fetch.wasm
$WASM_TOOLS validate /tmp/fetch.wasm
$WASM_TOOLS component wit /tmp/fetch.wasm
```

### Build (Rust core module) → component

```bash
cargo build --release --target wasm32-wasip1
$WASM_TOOLS component embed wit/ \
    target/wasm32-wasip1/release/my_lib.wasm \
    -o /tmp/embedded.wasm
$WASM_TOOLS component new /tmp/embedded.wasm \
    --adapt wasi_snapshot_preview1=wasi_snapshot_preview1.reactor.wasm \
    -o my_component.wasm
$WASM_TOOLS validate my_component.wasm
```

(For most Rust workflows use `cargo build --release --target
wasm32-wasip2` directly — see the `wasm-build/scripts/rust.md` cookbook.)

---

## Troubleshooting

- **`function … requires module to be a component`** → input is a core
  module; use `component new`/`component embed` first.
- **`failed to convert core module to component`** → missing or wrong
  adapter version. Match the adapter to the wasmtime/wasm-tools release.
- **`unknown import wasi:http/...`** → the runtime doesn't implement that
  WASI interface version. For WASI 0.2 use a wasmtime ≥ 14; for WASI 0.3 RC
  use wasmtime 43+ with `-Sp3 -Wcomponent-model-async`.
- **`metadata add` not persisting** → verify you're writing the output via
  `-o`; `metadata add` is not in-place.
