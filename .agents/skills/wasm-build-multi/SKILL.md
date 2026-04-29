---
name: wasm-build-multi
description: Build a single WebAssembly component in multiple languages (Rust, Python, JavaScript, Go) from a single prompt. Generates parallel implementations with language-suffixed directories so you can compare output, size, and behavior across toolchains.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# wasm-build-multi skill

You build the **same** WebAssembly component in every supported language from a single user prompt. Each implementation lives in its own directory with a language suffix and produces an identically-named `.wasm` artifact so outputs can be compared side by side.

**This skill builds on the `wasm-build` skill.** For language-specific project structure, templates, Cargo.toml/pyproject.toml/package.json/go.mod boilerplate, build commands, troubleshooting, optimization tips, and WASI 0.3 details, refer to the `wasm-build` SKILL.md. This skill adds the multi-language orchestration layer on top.

## When to use this skill

- User wants to compare component implementations across languages
- User wants to validate that a WIT interface works in multiple toolchains
- User wants polyglot examples of the same component for documentation or testing

## Output structure

Given a component name `foo`, you produce:

```
components/
├── Justfile                 # Per-language build / validate / test recipes
├── foo-rs/                  # Rust implementation
│   ├── Cargo.toml
│   ├── wit/world.wit
│   └── src/lib.rs
├── foo-rs.wasm              # Built Rust component
├── foo-py/                  # Python implementation
│   ├── pyproject.toml
│   ├── wit/world.wit
│   └── app.py
├── foo-py.wasm              # Built Python component
├── foo-js/                  # JavaScript implementation
│   ├── package.json
│   ├── wit/world.wit
│   └── src/index.js
├── foo-js.wasm              # Built JavaScript component
├── foo-go/                  # Go implementation
│   ├── go.mod
│   ├── wit/world.wit
│   └── main.go
└── foo-go.wasm              # Built Go component
```

The single `Justfile` owns the build convention: each toolchain produces
its `.wasm` at its native target location, and the recipe copies it to
the stable sibling name `foo-<lang>.wasm`. There is **no per-language
`build.sh`** — the Justfile inlines each toolchain command directly, so
the convention lives in one place.

All directories share the **same** `wit/world.wit` — the WIT is the contract, and each language implements it identically.

## Workflow

When invoked, follow these steps **in order**:

### Step 1 — Parse the prompt

Extract from the user's request:
- **Component name** (kebab-case, e.g. `hello-http`)
- **WIT world and interfaces** — what the component exports (and optionally imports)
- **Business logic** — what each exported function should do
- **Languages to target** — default to all four (`rs`, `py`, `js`, `go`). The user may request a subset.

If any of the above is ambiguous, ask the user before proceeding.

### Step 2 — Write the shared WIT

Create `wit/world.wit` once. All language directories will get an identical copy. See the `wasm-build` skill for WIT syntax and examples (including WASI preview 2 imports and WASI 0.3 async types).

### Step 3 — Scaffold each language

For each requested language, create `<name>-<lang>/` using the project structure and templates documented in the `wasm-build` skill. The key difference is the directory naming convention: always append the language suffix (`-rs`, `-py`, `-js`, `-go`).

### Step 4 — Implement the logic

Write the business logic in each language, keeping behaviour identical. Every export should produce the same observable output for the same input. Follow the `wasm-build` skill's language-specific patterns for implementing WIT interfaces.

### Step 5 — Build each component

Run `just build-<name>-<lang>` for each requested language (or `just build-all-<name>` to build them all). Each recipe outputs to `<name>-<lang>.wasm` next to the language directory. Report success/failure and output `.wasm` file sizes.

### Step 6 — Validate and compare

Use `just validate-<name>` (defined in the Justfile below) to validate every produced `.wasm`. The recipe wraps `wasm-tools validate` and `wasm-tools component wit` so each language's output is sanity-checked uniformly.

Report a comparison table:

| Language | File | Size | Status |
|----------|------|------|--------|
| Rust     | foo-rs.wasm | 120KB | ✓ |
| Python   | foo-py.wasm | 6.2MB | ✓ |
| JavaScript | foo-js.wasm | 8.1MB | ✓ |
| Go       | foo-go.wasm | 350KB | ✓ |

---

## Justfile

After scaffolding, generate a single `Justfile` at the same level as the language directories. Recipes follow this repo's convention: each toolchain produces a `.wasm` at its native location, and the recipe copies it to the stable `<name>-<lang>.wasm` sibling. Substitute `<NAME>` with the actual component name when generating.

```just
# === Build / validate / test recipes for the <NAME> component group ===
# One Justfile owns the convention. Each toolchain produces its .wasm
# at its native target path; the recipe copies it to <NAME>-<lang>.wasm.
#
# wasm-tools validate is invoked with --features all everywhere because
# WASI 0.3 components use stream<> / future<> / async func, and the
# default validator feature set rejects them.

# List recipes
default:
    @just --list

# Build all available languages (skips a language if its directory is missing)
build-all-<NAME>: build-<NAME>-rs build-<NAME>-py build-<NAME>-js build-<NAME>-go

# --- Rust ---
build-<NAME>-rs:
    #!/usr/bin/env bash
    set -euo pipefail
    [ -d <NAME>-rs ] || { echo "⚠ <NAME>-rs not found, skipping"; exit 0; }
    cd <NAME>-rs
    cargo build --release --target wasm32-wasip2
    cd ..
    cp <NAME>-rs/target/wasm32-wasip2/release/$(echo "<NAME>-rs" | tr - _).wasm <NAME>-rs.wasm
    wasm-tools validate --features all <NAME>-rs.wasm
    echo "✓ <NAME>-rs.wasm $(ls -lh <NAME>-rs.wasm | awk '{print $5}')"

# --- Python ---
# componentize-py has no --force flag; clear previous bindings outputs
# before regenerating, otherwise `bindings .` errors with
# "AssertionError: File exists (os error 17)".
build-<NAME>-py:
    #!/usr/bin/env bash
    set -euo pipefail
    [ -d <NAME>-py ] || { echo "⚠ <NAME>-py not found, skipping"; exit 0; }
    cd <NAME>-py
    rm -rf wit_world componentize_py_async_support componentize_py_runtime.pyi componentize_py_types.py poll_loop.py
    componentize-py -d wit -w <NAME> bindings .
    componentize-py -d wit -w <NAME> componentize app -o ../<NAME>-py.wasm
    cd ..
    wasm-tools validate --features all <NAME>-py.wasm
    echo "✓ <NAME>-py.wasm $(ls -lh <NAME>-py.wasm | awk '{print $5}')"

# --- JavaScript ---
build-<NAME>-js:
    #!/usr/bin/env bash
    set -euo pipefail
    [ -d <NAME>-js ] || { echo "⚠ <NAME>-js not found, skipping"; exit 0; }
    cd <NAME>-js
    [ -d node_modules ] || npm install --silent
    npx jco componentize src/index.js \
        --wit wit/world.wit --world-name <NAME> \
        --out ../<NAME>-js.wasm
    cd ..
    wasm-tools validate --features all <NAME>-js.wasm
    echo "✓ <NAME>-js.wasm $(ls -lh <NAME>-js.wasm | awk '{print $5}')"

# --- Go (TinyGo) ---
build-<NAME>-go:
    #!/usr/bin/env bash
    set -euo pipefail
    [ -d <NAME>-go ] || { echo "⚠ <NAME>-go not found, skipping"; exit 0; }
    cd <NAME>-go
    tinygo build -target wasip2 -opt=2 \
        --wit-package ./wit --wit-world <NAME> \
        -o ../<NAME>-go.wasm main.go
    cd ..
    wasm-tools validate --features all <NAME>-go.wasm
    echo "✓ <NAME>-go.wasm $(ls -lh <NAME>-go.wasm | awk '{print $5}')"

# Validate every built .wasm and print its exported WIT
validate-<NAME>:
    #!/usr/bin/env bash
    set -euo pipefail
    for f in <NAME>-rs.wasm <NAME>-py.wasm <NAME>-js.wasm <NAME>-go.wasm; do
        [ -f "$f" ] || continue
        echo "=== $f ==="
        wasm-tools validate --features all "$f" && echo "  ✓ valid · $(ls -lh "$f" | awk '{print $5}')"
        wasm-tools component wit "$f" 2>/dev/null | head -5 || echo "  (no extractable WIT)"
        echo
    done

# Run a single language's component with wasmtime.
# Defaults to rs; override with `just test-<NAME> py` etc.
#
# The case statement dispatches the right runtime flags per language. This
# is robust to mixed-WASI-version groups: when (e.g.) Rust + Python are on
# WASI 0.3 but JS + Go are still on 0.2, only this recipe needs to know.
# Adjust the --invoke argument to whichever export of <NAME> you want to test.
test-<NAME> lang="rs":
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{lang}}" in
        rs|py)  flags="-Sp3 -Shttp -Wcomponent-model-async";;  # WASI 0.3
        js|go)  flags="-Shttp";;                               # WASI 0.2
        *)      echo "unknown lang: {{lang}} (use rs|py|js|go)"; exit 1;;
    esac
    set -x
    wasmtime run $flags --invoke 'process("hello")' <NAME>-{{lang}}.wasm

# Run the test recipe for every language in turn (skips missing artifacts).
test-all-<NAME>:
    #!/usr/bin/env bash
    set -euo pipefail
    for lang in rs py js go; do
        [ -f "<NAME>-${lang}.wasm" ] || { echo "⚠ <NAME>-${lang}.wasm not built, skipping"; continue; }
        echo "=== test-<NAME> ${lang} ==="
        just test-<NAME> "${lang}"
    done

# Remove all built .wasm and language target/binding dirs for this component
clean-<NAME>:
    #!/usr/bin/env bash
    set -euo pipefail
    rm -f <NAME>-rs.wasm <NAME>-py.wasm <NAME>-js.wasm <NAME>-go.wasm
    rm -rf <NAME>-rs/target
    rm -rf <NAME>-py/wit_world <NAME>-py/componentize_py_async_support <NAME>-py/componentize_py_runtime.pyi <NAME>-py/componentize_py_types.py <NAME>-py/poll_loop.py
    rm -rf <NAME>-js/node_modules
    rm -rf <NAME>-go/gen
```

> **Mixed WASI versions across languages.** When a multi-language group has
> some implementations on WASI 0.3 and others stuck on 0.2 (e.g. because
> jco@1.19 lacks p3-shim and TinyGo has no `wasip3` target), the per-recipe
> structure above handles it cleanly: each `build-<NAME>-<lang>` recipe owns
> its own language's WIT and toolchain, and `test-<NAME>` dispatches the
> right `wasmtime` flags. Document the version-per-language matrix in the
> generated `<NAME>-rs/README.md` (or whichever sibling doubles as the
> cross-language overview).

Report the final comparison table after running `just build-all-<NAME>` followed by `just validate-<NAME>`.

---

## Toolchain check

Run this before building to report readiness:

```bash
echo "Checking toolchains..."
check() { command -v "$1" &>/dev/null && echo "  ✓ $1" || echo "  ✗ $1 (missing)"; }

echo "Orchestration:"
check just

echo "Rust:"
check cargo
rustup target list --installed 2>/dev/null | grep -q wasm32-wasip2 && echo "  ✓ wasm32-wasip2" || echo "  ✗ wasm32-wasip2 target (missing)"

echo "Python:"
check python3
check componentize-py

echo "JavaScript:"
check node
check jco

echo "Go:"
check tinygo
check wit-bindgen-go

echo "Shared:"
check wasm-tools
check wasmtime
```

---

## Error handling

- If a language toolchain is not installed, **skip that language** and note it in the summary rather than aborting the entire build.
- If a build fails, capture stderr, report it, and continue to the next language.
- At the end, always print the comparison table showing which succeeded and which failed.

## Partial builds

The user can request a subset of languages:

- "build in rust and python only" → only scaffold `-rs` and `-py`
- "skip javascript" → scaffold `-rs`, `-py`, `-go`

Default is all four languages.

## WASI preview 3

When the user requests WASI 0.3 (async), consult the `wasm-build` skill's WASI 0.3 section for per-language support status and build instructions. As of April 2026:

- **Rust**: Supported via `wasm32-wasip3` (nightly)
- **Python**: Experimental via componentize-py 0.23+
- **Go**: Experimental, TinyGo wasip3 target in progress
- **JavaScript**: Not yet supported

Build the languages that support it; skip the rest with a clear explanation in the summary table.
