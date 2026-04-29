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
├── foo-rs/                  # Rust implementation
│   ├── Cargo.toml
│   ├── wit/world.wit
│   ├── src/lib.rs
│   └── build.sh
├── foo-rs.wasm              # Built Rust component
├── foo-py/                  # Python implementation
│   ├── pyproject.toml
│   ├── wit/world.wit
│   ├── app.py
│   └── build.sh
├── foo-py.wasm              # Built Python component
├── foo-js/                  # JavaScript implementation
│   ├── package.json
│   ├── wit/world.wit
│   ├── src/index.js
│   └── build.sh
├── foo-js.wasm              # Built JavaScript component
├── foo-go/                  # Go implementation
│   ├── go.mod
│   ├── wit/world.wit
│   ├── main.go
│   └── build.sh
└── foo-go.wasm              # Built Go component
```

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

Run each language's build step. Each `build.sh` should output to `../<name>-<lang>.wasm`. Report success/failure and output `.wasm` file sizes.

### Step 6 — Validate and compare

```bash
for f in components/<name>-{rs,py,js,go}.wasm; do
  echo "=== $(basename $f) ==="
  wasm-tools component wit "$f" 2>/dev/null && echo "✓ valid" || echo "✗ invalid"
  ls -lh "$f" | awk '{print "  size:", $5}'
done
```

Report a comparison table:

| Language | File | Size | Status |
|----------|------|------|--------|
| Rust     | foo-rs.wasm | 120KB | ✓ |
| Python   | foo-py.wasm | 6.2MB | ✓ |
| JavaScript | foo-js.wasm | 8.1MB | ✓ |
| Go       | foo-go.wasm | 350KB | ✓ |

---

## Build-all script

After scaffolding, create a `build-all.sh` at the component group level:

```bash
#!/bin/bash
set -euo pipefail

NAME="COMPONENT_NAME"
LANGS=(rs py js go)
PASS=0
FAIL=0

for lang in "${LANGS[@]}"; do
  dir="$NAME-$lang"
  echo "━━━ Building $dir ━━━"
  if [ -d "$dir" ] && [ -f "$dir/build.sh" ]; then
    pushd "$dir" > /dev/null
    if bash build.sh; then
      ((PASS++))
    else
      echo "✗ $dir failed"
      ((FAIL++))
    fi
    popd > /dev/null
  else
    echo "⚠ $dir not found, skipping"
  fi
  echo
done

echo "━━━ Results ━━━"
echo "Passed: $PASS / $((PASS + FAIL))"
echo

echo "━━━ Size comparison ━━━"
printf "%-15s %10s\n" "Component" "Size"
printf "%-15s %10s\n" "─────────" "────"
for lang in "${LANGS[@]}"; do
  f="$NAME-$lang.wasm"
  if [ -f "$f" ]; then
    sz=$(du -h "$f" | cut -f1)
    printf "%-15s %10s\n" "$f" "$sz"
  fi
done
```

---

## Toolchain check

Run this before building to report readiness:

```bash
echo "Checking toolchains..."
check() { command -v "$1" &>/dev/null && echo "  ✓ $1" || echo "  ✗ $1 (missing)"; }

echo "Rust:"
check cargo
check cargo-component
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
