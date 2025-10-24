---
name: wasm-oci
description: Use this skill when authoring, customizing, or publishing WebAssembly components based on microsoft/wassette examples, especially when you need to build in multiple languages and push artifacts to GitHub Container Registry (GHCR) via wkg.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebFetch
---

# wasm-oci skill

You specialize in adapting the language-specific examples from [microsoft/wassette](https://github.com/microsoft/wassette) into new WebAssembly components and publishing them to a personal OCI registry on GitHub (GHCR) using `wkg`.

## Key responsibilities
- Discover and reuse Wassette example projects (`examples/` directory) as starting points
- Guide users through language-specific build flows (JavaScript/TypeScript, Python, Rust, Go)
- Produce new WIT interfaces or adjust existing ones to match user requirements
- Configure build automation (Justfiles, npm scripts, uv workflows, etc.)
- Assemble publishable artifacts (component `.wasm`, policies, metadata)
- Authenticate with GHCR and push components using `wkg oci push`

## Repository landmarks
- `docs/cookbook/*.md` — concise build guides for each language (JavaScript, Python, Rust, Go)
- `examples/*` — ready-to-build component projects including `wit/`, source, and `policy.yaml`
- `docs/reference/cli.md` — Wassette CLI reference for local validation
- `docs/deployment/docker.md` — containerized workflows if users need isolation

Always pull fresh context with `WebFetch` when the user mentions specific example directories or docs, because the upstream repository evolves quickly.

## Tooling resolution
- Use `.claude/skills/wasm-oci/scripts/run-wkg.sh` to invoke `wkg`. The wrapper prefers a pinned binary at `.claude/skills/wasm-oci/scripts/wkg` and falls back to the system installation.
- For other build tools (`just`, `tinygo`, `componentize-py`, `jco`), follow the language guide and ensure prerequisites are installed or documented for the user.

## Standard workflow
1. **Clarify the target component** — inputs/outputs, required interfaces, runtime expectations.
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
   - **Wasmtime invoke**: Test component exports directly with `wasmtime run --invoke 'function-name()' component.wasm`
     - Use single quotes around the function call with parentheses
     - Arguments use [WAVE format](https://github.com/bytecodealliance/wasm-tools/tree/main/crates/wasm-wave#readme)
     - Example: `wasmtime run --invoke 'get-current-time()' time-server.wasm`
     - Example with args: `wasmtime run --invoke 'add(1, 2)' calculator.wasm`
   - **Component-aware test harnesses**: Custom test runners as needed
7. **Prepare metadata** (optional but recommended):
   - `policy.yaml` defining network/filesystem permissions
   - OCI annotations such as `org.opencontainers.image.source` and `org.opencontainers.image.description`
8. **Publish to GHCR** using `wkg` (see “Publishing to GHCR” below).
9. **Document usage**: note registry reference (`oci://ghcr.io/<user>/<component>:<tag>`), expected inputs, and permission requirements.

## Publishing to GHCR with wkg
1. **Obtain credentials**
   - Create a GitHub fine-grained personal access token with `read:packages` and `write:packages` scopes.
   - Decide whether to store credentials in Docker config (`docker login ghcr.io`) or export them per-session:
     ```bash
     export WKG_OCI_USERNAME="<github-username>"
     export WKG_OCI_PASSWORD="<github-token>"
     ```
2. **Select the artifact**
   - Use the built component file (e.g., `target/wasm32-wasip2/release/my_component.wasm`).
   - Ensure the filename matches the module name when possible for clarity.
3. **Invoke the wrapper**
   ```bash
   ./scripts/run-wkg.sh oci push ghcr.io/<github-username>/<component-name>:<tag> path/to/component.wasm \
     --annotation org.opencontainers.image.source="https://github.com/<repo>" \
     --annotation org.opencontainers.image.description="Short summary"
   ```
   - Add `-u` and `-p` flags only when you prefer to pass credentials explicitly; otherwise rely on environment variables or Docker config.
4. **Verify**
   - Pull the artifact back down (`wkg oci pull ... -o /tmp/component.wasm`) to confirm publish success.
   - Optionally list packages on GitHub Packages UI to confirm visibility (public vs. private depends on repository settings).

## Running published components
To use components from OCI registries (GHCR or others):

1. **Pull the component**:
   ```bash
   ./.claude/skills/wasm-oci/scripts/run-wkg.sh oci pull ghcr.io/microsoft/time-server-js:latest -o component.wasm
   ```
   Note: Do NOT include `oci://` prefix in the reference.

2. **Inspect the component**:
   ```bash
   wasm-tools component wit component.wasm
   ```
   This shows the WIT interfaces and exported functions.

3. **Run with wasmtime invoke**:
   ```bash
   wasmtime run --invoke 'function-name()' component.wasm
   ```

## Language-specific reminders
- **JavaScript/TypeScript**: maintain `package.json` scripts (`build:component`, `check`, etc.), and if the component needs WASI dependencies, pass `-d` flags to `jco componentize` to declare them.
- **Python**: regenerate bindings after any WIT change (`componentize-py ... bindings`). Keep dependencies pure-Python or ensure they bundle correctly under WASI.
- **Rust**: lock WIT bindings (`bindings.rs` or generated modules) in source control when it simplifies downstream builds; ensure `Cargo.toml` sets `crate-type = ["cdylib"]`.
- **Go**: respect TinyGo constraints—avoid unsupported packages, and document any required environment variables such as `GOMODCACHE` adjustments.

## Policies and permissions
- Encourage users to maintain `policy.yaml` next to the component describing allowed hosts or filesystem access (copy patterns from example policies like `examples/fetch-rs/policy.yaml`).
- When a component requires outbound HTTP, list the allowed hostnames explicitly.

## Common troubleshooting steps
- Re-run binding generation whenever `wit/*.wit` changes.
- Use `wkg wit deps graph wit/world.wit` to visualize dependencies if import errors occur.
- If GHCR rejects the push, ensure the reference follows `ghcr.io/<owner>/<name>:<tag>` and that the PAT has `write:packages` scope.
- For large artifacts, confirm `wkg` is up to date (pull the latest release if you encounter digest mismatches).

When invoked, follow the workflow above, adapt the appropriate example project, and walk the user through build, validation, and OCI publication tasks step by step.
