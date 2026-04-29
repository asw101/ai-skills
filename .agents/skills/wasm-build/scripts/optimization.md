# Optimization, validation, and inspection

## Validation

```bash
# Is this a valid component?
wasm-tools validate components/my-component.wasm

# What does it export/import?
wasm-tools component wit components/my-component.wasm

# Detailed component info (modules, instances, etc.)
wasm-tools component info components/my-component.wasm

# Print with demangled names
wasm-tools print --demangle components/my-component.wasm
```

If `wasm-tools component wit` fails with "not a component", you have a core module. Wrap it:

```bash
wasm-tools component new module.wasm \
  --adapt wasi_snapshot_preview1.command.wasm \
  -o component.wasm
```

Adapter variants (`command`, `reactor`, `proxy`) are published with each `wasmtime` release.

## Size optimization

### All languages — `wasm-opt`

```bash
wasm-opt -Os components/my-component.wasm -o components/my-component.opt.wasm
mv components/my-component.opt.wasm components/my-component.wasm
```

`wasm-opt` ships in the `binaryen` toolkit (`brew install binaryen`, `apt install binaryen`, or `npm install -g wasm-opt`).

### Rust

In `Cargo.toml`:

```toml
[profile.release]
opt-level = "z"      # smaller than "s"
lto = true
codegen-units = 1
panic = "abort"
strip = true
```

Diagnose what's contributing:

```bash
cargo bloat --release --target wasm32-wasip2 --crates
```

### TinyGo

```bash
tinygo build -target=wasip2 -opt=z -o out.wasm .
tinygo build -target=wasip2 -size=short -o out.wasm .   # show segment sizes
```

### Python and JavaScript

Component size is dominated by the embedded runtime (CPython ~5–10 MB, SpiderMonkey ~6–10 MB). `wasm-opt -Os` saves only a few hundred KB. Don't expect Rust-class footprints here.

## Inspection at runtime

For runtime debugging (invoking exports, granting WASI permissions, AOT compilation, HTTP serving), see the **wasm-run** skill. Quick references:

```bash
# Invoke an exported function (component-style WAVE arguments)
wasmtime run --invoke 'process("hello")' components/my-component.wasm

# Serve as HTTP
wasmtime serve components/my-component.wasm

# AOT-compile to .cwasm for faster startup
wasmtime compile components/my-component.wasm -o components/my-component.cwasm
```

## Pre-initialization with `wizer`

If your component implements a `wizer-initialize` export, you can pre-evaluate startup work:

```bash
wasmtime wizer components/my-component.wasm -o components/my-component.init.wasm
```

This is most impactful for JS/Python components where module evaluation is expensive.
