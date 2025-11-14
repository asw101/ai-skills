# Codex All-Skills Agent Overview

This directory packages every `.claude/skills/*` capability as a single Codex CLI agent. The goal is to let Codex mirror the same project-scoped automation Claude provided, without duplicating instructions across multiple files.

## Layout
- `INSTRUCTIONS.md` – Primary prompt the Codex CLI loads. It implements a “Skill Router” describing when to use each tool and the guardrails (context gathering, binary resolution, confirmation prompts).
- `tools.toml` – Declares the command-line tools Codex can call. Each entry points to a wrapper script.
- `tools/*.py` – Python wrappers that resolve pinned binaries, accept JSON parameters, execute the underlying CLI, and relay stdout/stderr back to Codex. Wrappers exist for:
  - `just_tool.py` – Lists, shows, and runs Justfile recipes.
  - `wasmtime_tool.py` – Runs, inspects, or compiles WebAssembly components via wasmtime.
  - `awesome_wasm_tool.py` – Pulls components with `wkg`, extracts WIT with `wasm-tools`, and updates `components.json`.
  - `wasm_build_tool.py` – Invokes canonical build commands (Rust, Python, JS, Go) or custom command lists.
  - `wasm_oci_tool.py` – Uses `run-wkg.sh`/`wkg` to pull/push artifacts to OCI registries with annotations and credentials.

## Why Python Wrappers?
- **Reliable binary selection:** Every skill prefers binaries staged in `.claude/skills/<skill>/scripts/`. The wrappers handle that lookup once, so Codex doesn’t have to recreate the logic in prompts.
- **Structured inputs:** Codex can submit JSON payloads (`{"recipe":"build","args":["--release"]}`), avoiding shell quoting issues.
- **Centralized policy:** Error messaging, environment variable handling, and registry updates (e.g., timestamping `components.json`) live in code, ensuring consistent behavior across sessions.
- **Easy evolution:** Updating a wrapper instantly adjusts the Codex behavior without rewriting instructions.

## How Codex Uses This Agent
1. From the repo root, launch Codex CLI with `--instructions codex/all-skills/INSTRUCTIONS.md --tools codex/all-skills/tools.toml` (or symlink those files into `codex/` if your CLI expects that layout).
2. The instructions tell Codex to analyze each user request, identify the relevant skill, and call the matching tool (`use tool just_runner {...}` etc.).
3. Each tool runs the wrapped CLI with the correct binaries, arguments, and environment.
4. Codex summarizes the results back to the user and logs follow-up steps.

### Quick-start command
```
codex chat --instructions codex/all-skills/INSTRUCTIONS.md --tools codex/all-skills/tools.toml
```
Run that from `/Users/user/tmp/251000-ai-skills` (or the repo root wherever you clone it) to start a session with full skill coverage.

## Extending the Agent
- **New skill:** Add a wrapper under `tools/`, register it in `tools.toml`, and document the triggers/tool name in `INSTRUCTIONS.md`.
- **Custom logic:** If a skill needs additional state (e.g., caching outputs), implement it directly in the wrapper instead of relying on prompts.
- **Multiple agents:** Create sibling folders (`codex/<agent-name>/`) with their own instructions + tool manifests if you later want specialized personas.

## Testing
Run wrappers directly to validate prerequisites:
```bash
python3 codex/all-skills/tools/just_tool.py '{"action":"list"}'
python3 codex/all-skills/tools/awesome_wasm_tool.py '{"action":"registry_list"}'
python3 codex/all-skills/tools/wasm_build_tool.py '{"directory":"components/foo","language":"rust"}'
```
Add more smoke tests as you introduce new tools. Use the repo Justfile to script repeatable checks if needed.
