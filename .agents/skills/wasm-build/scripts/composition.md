# Component composition

Two tools combine multiple components into one:

- **`wac`** — declarative WAC language; preferred for non-trivial wiring.
- **`wasm-tools compose`** — YAML-driven; fine for simple cases.

## Install

```bash
cargo install wac-cli@0.10.0
cargo install wasm-tools@1.248.0
```

## `wac` (recommended)

`wac` uses a small DSL to instantiate components and wire imports/exports.

### Example: `app.wac`

```wac
package mycorp:composed;

let main = new mycorp:main { ... };
let helper = new mycorp:helper { ... };

// Wire helper.process into main's import slot.
let app = new mycorp:main {
  ...main,
  "mycorp:helper/process": helper.process,
};

export app...;
```

### Compose

```bash
wac compose app.wac \
  --dep mycorp:main=./components/main.wasm \
  --dep mycorp:helper=./components/helper.wasm \
  -o composed.wasm

wasm-tools validate composed.wasm
```

## `wasm-tools compose`

Simple wiring driven by a YAML configuration.

### `compose.yaml`

```yaml
instantiate:
  main:
    path: components/main.wasm
  helper:
    path: components/helper.wasm

dependencies:
  main:
    "mycorp:helper/process": helper
```

### Compose

```bash
wasm-tools compose -c compose.yaml -o composed.wasm
wasm-tools validate composed.wasm
```

## Verifying the result

```bash
# Inspect the composed component's external interface
wasm-tools component wit composed.wasm

# Confirm internal modules are resolved
wasm-tools component info composed.wasm
```

## Tips

- `wac plug` is a shorthand for the common case of "satisfy missing imports of A using exports of B": `wac plug --plug ./helper.wasm ./main.wasm -o composed.wasm`.
- Composed components can themselves be composed; nesting is supported.
- After composition, all imports must either be satisfied or remain explicit imports of the composed component. Unresolved imports are a validation error only at instantiation time, not at compose time.
