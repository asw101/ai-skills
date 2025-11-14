# Codex Skill Router

These instructions replace the old `_ /INSTRUCTIONS.md` file and teach Codex how to replicate every `.claude/skills/*` capability directly inside this repository. Always follow the guardrails below before issuing commands.

## Global Guidance
- **Trigger detector** – Scan the user prompt for keywords tied to each skill (Justfile, wasmtime, component download, Wassette, OCI, build, etc.). Pick the single best skill and stay within its workflow unless asked otherwise.
- **Context first** – Before taking action, read the relevant docs: `docs/skills-overview.md`, the target skill’s `SKILL.md`, and any files the user mentioned. Summaries should be stored in your scratchpad so you can cite them later.
- **Binary resolution snippet** – All skills prefer pinned binaries under `.claude/skills/<skill>/scripts/`. Use this shell pattern (adjusting the name) at the top of each Bash command:
  ```bash
  SKILL_DIR=".claude/skills/<skill>"
  BIN="$SKILL_DIR/scripts/<binary>"
  if [ ! -x "$BIN" ]; then
    BIN="<binary>"
  fi
  ```
  Then replace `<binary>` with the resolved variable when executing commands.
- **Tools** – Use Codex `Read`/`Edit`/`Write` for files, `Bash` for shell commands, `Glob`/`Grep` to locate content, and `WebFetch` only when the skill explicitly allows it (awesome-wasm, wasm-oci).
- **Confirmation** – Whenever a command mutates files or pushes artifacts, explain the plan to the user first, wait for consent if they have not asked explicitly, and summarize results afterwards.

---

## Skill: just (Justfile automation)
- **Triggers:** “just”, “Justfile”, “recipe”, “run the build recipe”.
- **Codex tool:** `use tool just_runner {"action":"list"}` to list recipes, then switch to `show`/`run` actions as needed.
- **Startup checklist:**
  1. `Read` `.claude/skills/just/SKILL.md` for refreshers if needed.
  2. `Glob` for `Justfile` starting in repo root.
  3. Run `Bash` to list recipes:
     ```bash
     SKILL_DIR=".claude/skills/just"
     JUST="$SKILL_DIR/scripts/just"
     if [ ! -x "$JUST" ]; then JUST="just"; fi
     "$JUST" --list
     ```
  4. Share the recipe summary with the user, then proceed (show, run, or edit recipes).
- **Executing commands:**
  - `Show recipe`: `"$JUST" --show <recipe>`
  - `Run recipe`: `"$JUST" <recipe> [args...]`
  - Use `Edit`/`Write` to update the Justfile, then re-run `--list` to confirm.
- **Debug hints:** If a recipe fails, re-run with `--verbose`, inspect environment variables, and explain how to modify the recipe or prerequisites.

---

## Skill: wasmtime (Run/inspect WebAssembly)
- **Triggers:** “run this .wasm”, “WASI permissions”, “Component Model”, “wasmtime”.
- **Codex tool:** `use tool wasmtime_exec {"action":"run","file":"components/demo.wasm"}` (plus dirs/env/invoke) or switch to `wit`/`compile`.
- **Startup checklist:**
  1. `Read` `.claude/skills/wasmtime/SKILL.md`.
  2. Identify the target `.wasm`/`.cwasm`/`.wit` files.
  3. Resolve the binary with:
     ```bash
     SKILL_DIR=".claude/skills/wasmtime"
     WASMTIME="$SKILL_DIR/scripts/wasmtime"
     if [ ! -x "$WASMTIME" ]; then WASMTIME="wasmtime"; fi
     ```
- **Common actions:**
  - **Run component:** `"$WASMTIME" run [--dir <path>] [--env KEY=VAL] [--invoke func] component.wasm`
  - **Inspect interfaces:** `"$WASMTIME" component wit component.wasm -o out.wit`
  - **Compile ahead-of-time:** `"$WASMTIME" compile component.wasm -o component.cwasm`
  - **Debug errors:** rerun with `RUST_LOG=wasmtime=trace` or `--debug-info` as needed.
- **Reporting:** Describe which permissions you granted (`--dir`, `--env`) and summarize output/error logs for the user.

---

## Skill: awesome-wasm (Component discovery & downloads)
- **Triggers:** “find a WebAssembly component”, “awesome-wasm”, “fetch component X”.
- **Codex tool:** `use tool awesome_wasm_helper {"action":"wkg_pull","reference":"ghcr.io/...","output":"components/foo.wasm"}` and `registry_update` when logging downloads.
- **Startup checklist:**
  1. `Read` `.claude/skills/awesome-wasm/SKILL.md` and `docs/skills-overview.md`.
  2. `Read` `.claude/skills/awesome-wasm/components.json` if it exists to understand cached components.
  3. Decide whether you need `WebFetch` (allowed) to read upstream docs.
- **Tools & commands:**
  - Resolve helper binaries:
    ```bash
    SKILL_DIR=".claude/skills/awesome-wasm"
    WKG="$SKILL_DIR/scripts/wkg"; if [ ! -x "$WKG" ]; then WKG="wkg"; fi
    WASM_TOOLS="$SKILL_DIR/scripts/wasm-tools"; if [ ! -x "$WASM_TOOLS" ]; then WASM_TOOLS="wasm-tools"; fi
    ```
  - **List/Recommend:** Use `Read` to inspect `components.json` and cite relevant entries.
  - **Download:** `"$WKG" oci pull <registry-reference> -o components/<name>.wasm`
  - **Inspect WIT:** `"$WASM_TOOLS" component wit components/<name>.wasm -o components/<name>.wit`
  - **Update registry:** Use `Write`/`Edit` to append metadata (last downloaded, notes) to `components.json`.
- **Integration guidance:** Explain how to run the component (e.g., via `wasmtime`), what interfaces it exports, and any required bindings.

---

## Skill: wasm-build (Build components from source)
- **Triggers:** “build this component”, “scaffold Rust WASI preview2 component”, “componentize-py”, “tinygo”.
- **Codex tool:** `use tool wasm_build_helper {"language":"rust","directory":"components/foo"}` or pass `"commands":[...]` for custom pipelines.
- **Startup checklist:**
  1. `Read` `.claude/skills/wasm-build/SKILL.md` plus the language-specific cookbook referenced there.
  2. Understand the component directory under `components/`.
  3. Determine requested language (Rust, Python, JavaScript/TypeScript, Go).
- **Per-language commands:**
  - **Rust:** Run `cargo component build --release --target wasm32-wasip2` inside the component folder, then copy the `.wasm`.
  - **Python:** Use `uv run componentize-py` (or `componentize-py`) to generate bindings and build.
  - **JavaScript/TypeScript:** Use `npm install`, `npm run build:component`, leveraging `jco/componentize-js`.
  - **Go:** Run `tinygo build -target wasip2 --wit-package ./wit -o ../component.wasm ./...`.
- **Workflow essentials:**
  1. Confirm prerequisites via `rustup`, `npm`, `uv`, or `tinygo`.
  2. Generate/refresh bindings after any `wit/` changes.
  3. Place outputs as siblings of the source directory (e.g., `components/<name>.wasm`).
  4. Summarize build logs and store them (or key lines) in your response for later debugging.

---

## Skill: wasm-oci (Adapt Wassette examples & publish to registries)
- **Triggers:** “wassette”, “publish component to GHCR”, “wkg push”, “Wassette examples”.
- **Codex tool:** `use tool wasm_oci_helper {"action":"push","reference":"ghcr.io/<user>/<component>:tag","artifact":"components/component.wasm","annotations":{"org.opencontainers.image.description":"..."}}` (set credentials via env when needed).
- **Startup checklist:**
  1. `Read` `.claude/skills/wasm-oci/SKILL.md` plus any relevant `docs/cookbook/*.md` files.
  2. Inspect `examples/` for baseline code.
  3. Resolve wrapper:
     ```bash
     SKILL_DIR=".claude/skills/wasm-oci"
     WKG_WRAPPER="$SKILL_DIR/scripts/run-wkg.sh"
     if [ ! -x "$WKG_WRAPPER" ]; then WKG_WRAPPER="wkg"; fi
     ```
- **Workflow:**
  1. Select/clone the nearest Wassette example (JS, Python, Rust, Go) and adapt logic/WIT to the user’s request.
  2. Build the component using the appropriate language instructions (reuse wasm-build procedures).
  3. Prepare metadata (`policy.yaml`, annotations, README snippets).
  4. Publish:
     ```bash
     "$WKG_WRAPPER" oci push ghcr.io/<owner>/<component>:<tag> components/<component>.wasm \
       --annotation org.opencontainers.image.source="https://github.com/<repo>" \
       --annotation org.opencontainers.image.description="..."
     ```
     Ensure `WKG_OCI_USERNAME` / `WKG_OCI_PASSWORD` env vars (or Docker credentials) are set before pushing.
  5. Verify by pulling the artifact back down and optionally running it via `wasmtime`.
- **Documentation updates:** After publishing, edit relevant README/docs to record the OCI reference and usage instructions.

---

## Reporting Back
After executing any skill:
1. Summarize the steps you performed, highlighting commands and files touched.
2. Include next actions or testing suggestions (e.g., “Run `wasmtime run ...` to validate”).
3. Note any obstacles (missing dependencies, auth failures) and propose resolutions.
