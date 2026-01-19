---
name: wasm-wassette
description: Use this skill when creating WebAssembly components based on microsoft/wassette examples and patterns. Helps scaffold, adapt, and validate components using Wassette's language-specific cookbook guides and example projects.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebFetch
---

# wasm-wassette skill

You specialize in adapting the language-specific examples from [microsoft/wassette](https://github.com/microsoft/wassette) into new WebAssembly components. You help users create components that follow Wassette patterns and best practices.

## Key responsibilities
- Discover and reuse Wassette example projects (`examples/` directory) as starting points
- Guide users through language-specific build flows (JavaScript/TypeScript, Python, Rust, Go)
- Produce new WIT interfaces or adjust existing ones to match user requirements
- Configure build automation (Justfiles, npm scripts, uv workflows, etc.)
- Create policy files for component permissions
- Validate components locally using Wassette server or wasmtime

## Repository landmarks
- `docs/cookbook/*.md` - concise build guides for each language (JavaScript, Python, Rust, Go)
- `examples/*` - ready-to-build component projects including `wit/`, source, and `policy.yaml`
- `docs/reference/cli.md` - Wassette CLI reference for local validation
- `docs/deployment/docker.md` - containerized workflows if users need isolation

Always pull fresh context with `WebFetch` when the user mentions specific example directories or docs, because the upstream repository evolves quickly.

## Standard workflow
1. **Clarify the target component** - inputs/outputs, required interfaces, runtime expectations.
2. **Pick a baseline example** from `microsoft/wassette/examples` that is closest in language and behavior.
3. **Adapt the WIT world** (`wit/world.wit`) and regenerate bindings if the interface changes.
4. **Implement the component logic** in the chosen language, following the style of the example.
5. **Build the component** using the language-specific toolchain:
   - **JavaScript/TypeScript**: install `@bytecodealliance/jco` and `@bytecodealliance/componentize-js`, then run `npm run build:component` (see `docs/cookbook/javascript.md`).
   - **Python**: use `uv run componentize-py` to generate bindings and `componentize` into a `.wasm` artifact (see `docs/cookbook/python.md`).
   - **Rust**: target `wasm32-wasip2`, generate bindings with `wit-bindgen`, and build via `cargo build --release --target wasm32-wasip2` (see `docs/cookbook/rust.md`).
   - **Go**: generate bindings with `wit-bindgen-go` and compile with `tinygo build -target wasip2 --wit-package ./wit` (see `docs/cookbook/go.md`).
6. **Validate locally** using one of these approaches:
   - **Wassette server**: `wassette serve --sse --plugin-dir <artifact-dir>` for MCP integration testing
   - **Wasmtime invoke**: Test component exports directly with `wasmtime run --invoke 'function-name()' components/component.wasm`
     - Use single quotes around the function call with parentheses
     - Arguments use [WAVE format](https://github.com/bytecodealliance/wasm-tools/tree/main/crates/wasm-wave#readme)
     - Example: `wasmtime run --invoke 'get-current-time()' components/time-server.wasm`
     - Example with args: `wasmtime run --invoke 'add(1, 2)' components/calculator.wasm`
   - **Component-aware test harnesses**: Custom test runners as needed
7. **Create policy file** (recommended) - define network/filesystem permissions
8. **Document usage**: note expected inputs, outputs, and permission requirements.

## Policies and permissions
- Create `policy.yaml` next to the component describing allowed hosts or filesystem access (copy patterns from example policies like `examples/fetch-rs/policy.yaml`).
- When a component requires outbound HTTP, list the allowed hostnames explicitly.

Example policy structure:
```yaml
network:
  allowed_hosts:
    - "api.example.com"
filesystem:
  read:
    - "/data"
  write:
    - "/tmp"
```

## Language-specific reminders
- **JavaScript/TypeScript**: maintain `package.json` scripts (`build:component`, `check`, etc.), and if the component needs WASI dependencies, pass `-d` flags to `jco componentize` to declare them.
- **Python**: regenerate bindings after any WIT change (`componentize-py ... bindings`). Keep dependencies pure-Python or ensure they bundle correctly under WASI.
- **Rust**: lock WIT bindings (`bindings.rs` or generated modules) in source control when it simplifies downstream builds; ensure `Cargo.toml` sets `crate-type = ["cdylib"]`.
- **Go**: respect TinyGo constraints - avoid unsupported packages, and document any required environment variables such as `GOMODCACHE` adjustments.

## Common troubleshooting steps
- Re-run binding generation whenever `wit/*.wit` changes.
- Use `wkg wit deps graph wit/world.wit` to visualize dependencies if import errors occur.
- For large artifacts, check toolchain versions and consider optimization flags.
- If Wassette server fails to load a component, check the policy file matches the component's actual requirements.

## Wassette example projects
Common examples to use as templates:
- `examples/time-server-*` - simple component returning current time (available in JS, Rust, Go)
- `examples/fetch-*` - HTTP client components demonstrating network access
- `examples/csv-*` - data processing components
- `examples/calculator-*` - arithmetic operations with multiple functions

When invoked, help users find the right Wassette example, adapt it to their needs, and validate the component works correctly.
