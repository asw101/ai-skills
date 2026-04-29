---
name: wasm-build
description: Build WebAssembly components from Rust, Python, JavaScript/TypeScript, or Go using WASI Preview 2 and the Component Model. Covers scaffolding, language-specific toolchain setup (cargo-component, componentize-py, jco / componentize-js, tinygo), compilation to wasm32-wasip2, WIT binding generation, validation, and size/startup optimization.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebFetch
---

# wasm-build skill

You help users compile source code into WebAssembly components targeting **WASI Preview 2** and the **Component Model**.

> **Last verified:** 2026-04-29. Re-verify versions with `WebFetch` (or the repo's `just check-versions` recipe) before pinning new projects.

## Toolchain version pins

| Tool | Version | Purpose |
|---|---|---|
| Rust | stable (≥ 1.82) | `wasm32-wasip2` target |
| `wit-bindgen` (Rust crate) | 0.57.1 | Manual binding generation |
| `cargo-component` | 0.21.1 | Cargo subcommand for components |
| `componentize-py` | 0.23.0 | Python → component |
| `@bytecodealliance/jco` | 1.19.0 | JS toolchain (stable) |
| `@bytecodealliance/componentize-js` | 0.20.0 | JS → component (still labeled experimental upstream) |
| TinyGo | 0.41.1 | Go → component (`-target=wasip2`) |
| `go.bytecodealliance.org` | v0.7.0 | Go runtime + `wit-bindgen-go`; repo: `bytecodealliance/go-modules` |
| `wasm-tools` | 1.248.0 | Validate, inspect, compose, adapt |
| `wkg` | 0.15.0 | WIT package fetch/build/publish |
| `wac` | 0.10.0 | Component composition DSL |
| `wasmtime` | 44.0.0 | Runtime (WASIp3 RC needs `-Sp3 -Wcomponent-model-async`; supported since 43.0.0) |

**WASI versioning:** This repo is fine targeting either **WASI 0.2** or the **WASI 0.3 RC** (`0.3.0-rc-2026-03-15`). 0.2 is the default for compatibility; 0.3 RC is fully supported by `wasmtime` 43+ via `-Sp3 -Wcomponent-model-async`, and is the path forward for native async (`stream<>`, `future<>`, `async func`). Today's 0.3 guest support: **Rust** (Flow C only — `wit-bindgen = "0.57.1"` macro + adapter; `cargo-component` still pins wit-bindgen 0.41 and is not yet 0.3-capable) and **Python** (`componentize-py` 0.23.0 with shipped `cli-p3` / `http-p3` / `tcp-p3` examples). JavaScript is in active upstream dev but unreleased; Go is not yet viable. See [`scripts/wasi-0.3.md`](./scripts/wasi-0.3.md).

## Capabilities

When invoked, help users:

1. **Scaffold** new components with WIT.
2. **Build** source → `.wasm` component.
3. **Validate** with `wasm-tools validate` and `wasm-tools component wit`.
4. **Manage WIT dependencies** with `wkg`.
5. **Compose** multi-component apps with `wac`.
6. **Optimize** size and startup.

For **running** built components, defer to the **wasmtime** skill.
For **publishing** to OCI registries, defer to **component** by default; reach for **wasm-toolchain** (`wkg`) when you need raw OCI annotation control or WIT-package publishing.

## Project layout

The repo keeps each component as a sibling source folder + built `.wasm`:

```
components/
├── my-component/                # source
│   ├── src/ or app.py / index.js / main.go
│   ├── wit/world.wit
│   ├── Cargo.toml | pyproject.toml | package.json | go.mod
│   ├── README.md  USAGE.md
│   └── examples/                # optional sample data
└── my-component.wasm            # built artifact (sibling)
```

The reference example is **[`components/csv-groupby/`](../../../components/csv-groupby/)**. Read its `Cargo.toml`, `wit/`, and `build.sh` for the canonical Rust pattern (note: that example may pin older crate versions than the table above; the table is the source of truth for new components).

## Naming convention

- Use kebab-case for component names (`my-component`).
- Cargo replaces `-` with `_` in produced artifacts. Build scripts use `${NAME//-/_}.wasm` when copying from `target/`.

## Choose a language

| You want… | Use | Notes |
|---|---|---|
| Smallest size, full WIT support, mature toolchain | **Rust** | 100–500 KB typical. See [`scripts/rust.md`](./scripts/rust.md). |
| Rapid iteration, Python ecosystem (pure-Python deps) | **Python** | 5–10 MB component (embeds CPython). See [`scripts/python.md`](./scripts/python.md). |
| Web/Node integration, TypeScript types | **JavaScript / TypeScript** | 6–10 MB (embeds SpiderMonkey). See [`scripts/javascript.md`](./scripts/javascript.md). |
| Go ergonomics, small binaries | **Go (TinyGo)** | 0.2–1 MB. Custom WIT works but `wasi:cli/command` is the well-trodden path; `wasi:http` emerging. See [`scripts/go.md`](./scripts/go.md). |

**Maturity (2026-04):**
Rust ≥ Python ≥ JavaScript > Go (for components with custom WIT).

## Standard workflow

1. **Pick a language.** Open the matching cookbook in `scripts/`.
2. **Scaffold** the project (`cd components && …`).
3. **Define the world** in `wit/world.wit`. If importing registry packages, run `wkg wit fetch` (see [`scripts/wkg.md`](./scripts/wkg.md)).
4. **Implement** the exports in source.
5. **Build** to `components/my-component.wasm`.
6. **Validate**: `wasm-tools validate` and `wasm-tools component wit` to confirm the exported interface.
7. **Run/test** with `wasmtime` — defer to the **wasmtime** skill for invocation details (WAVE syntax, `--invoke` quirks, `wasmtime serve` for HTTP).

## WIT essentials

Every language uses the same WIT in `wit/world.wit`:

```wit
package local:my-component;

world my-component {
    export process: func(input: string) -> result<string, string>;
}
```

To import WASI Preview 2 interfaces:

```wit
package local:my-component;

world my-component {
    import wasi:cli/environment@0.2.0;
    import wasi:http/outgoing-handler@0.2.0;

    export run: func() -> result<_, string>;
}
```

When you reference packages outside your own (`wasi:*`, third-party), run `wkg wit fetch` to populate `wit/deps/` and pin versions in `wkg.lock`.

## Validation (quick reference)

```bash
wasm-tools validate components/my-component.wasm
wasm-tools component wit components/my-component.wasm
ls -lh components/my-component.wasm
```

If the second command says "not a component", you have a core module — see [`scripts/optimization.md`](./scripts/optimization.md) for the `wasm-tools component new --adapt …` workaround.

## Optimization, composition, packages

- **Size & inspection:** [`scripts/optimization.md`](./scripts/optimization.md)
- **WIT registry deps:** [`scripts/wkg.md`](./scripts/wkg.md)
- **Composing components:** [`scripts/composition.md`](./scripts/composition.md)
- **Targeting WASI 0.3 RC:** [`scripts/wasi-0.3.md`](./scripts/wasi-0.3.md)

## General troubleshooting

- **`not a component`** → core module; wrap with `wasm-tools component new --adapt wasi_snapshot_preview1.command.wasm`.
- **WIT resolution fails** → run `wkg wit fetch`; check `~/.config/wasm-pkg/config.toml`.
- **Mismatched bindings** → re-generate after every `wit/` edit (per-language details in cookbooks).
- **WASI 0.3 RC features unavailable** → run `wasmtime` 43+ with **both** `-Sp3` and `-Wcomponent-model-async`, and pin WIT to `0.3.0-rc-2026-03-15`. Older `wasmtime` (e.g. 40.x) will fail to resolve 0.3 imports; missing the `-W` flag will trap on `stream<>` / `future<>`. See [`scripts/wasi-0.3.md`](./scripts/wasi-0.3.md).

## Related skills

- **wasmtime** — execute components with `wasmtime`, invoke exports, serve HTTP. Use after building.
- **component** — default for the component lifecycle: build → push → pull → run, plus discovery via meta-registries.
- **wasm-toolchain** — raw upstream tools: `wkg` for OCI push/pull with annotations and WIT-package authoring; `wasm-tools` for validate/embed/extract/inspect.
- **just** — the repo's `Justfile` pins tool versions and provides `install-*` recipes.

## When invoked

1. Confirm the target language and WIT shape with the user (or infer from existing files).
2. Open the matching cookbook in `scripts/`.
3. Scaffold or modify, build, validate.
4. Hand off to **wasmtime** for execution; **component** (default) or **wasm-toolchain** (`wkg`) for publishing.
