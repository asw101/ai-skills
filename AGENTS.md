## Skills
A skill is a set of local instructions to follow that is stored in a `SKILL.md` file under `.agent/skills`. Below is the list of skills that can be used. Each entry includes a name, description, and file path so you can open the source for full instructions when using a specific skill.

### Available skills
- just: Use this skill when working with just command runner, Justfiles, or build recipes. Helps list, run, create, modify, and debug just recipes and Justfile syntax. (file: .agent/skills/just/SKILL.md)
- wasm-build: Build WebAssembly components from Rust, Python, JavaScript, or Go source code using WASI preview 2. Helps scaffold, compile, validate, and optimize components for the WebAssembly Component Model. (file: .agent/skills/wasm-build/SKILL.md)
- wasm-registry: Use this skill when publishing, pulling, or managing WebAssembly components in OCI registries like GitHub Container Registry (GHCR). Helps with wkg commands, authentication, and registry operations. (file: .agent/skills/wasm-registry/SKILL.md)
- wasm-run: Use this skill when working with WebAssembly (Wasm), .wasm files, wasmtime runtime, WASI, or WebAssembly Component Model. Helps run, inspect, debug, and configure WebAssembly modules and components, including WIT interface definitions. (file: .agent/skills/wasm-run/SKILL.md)
- wasm-search: Use this skill when searching for, discovering, exploring, or working with WebAssembly components from the awesome-wasm-components collection. Helps find suitable components for specific tasks, list available components, download components from registries, and maintain a local component inventory. (file: .agent/skills/wasm-search/SKILL.md)
- wasm-wassette: Use this skill when creating WebAssembly components based on microsoft/wassette examples and patterns. Helps scaffold, adapt, and validate components using Wassette's language-specific cookbook guides and example projects. (file: .agent/skills/wasm-wassette/SKILL.md)

### How to use skills
- Discovery: The list above is the skills available in this repo (name + description + file path). Skill bodies live on disk at the listed paths.
- Trigger rules: If the user names a skill (with `$SkillName` or plain text) OR the task clearly matches a skill's description shown above, you must use that skill for that turn. Multiple mentions mean use them all. Do not carry skills across turns unless re-mentioned.
- Missing/blocked: If a named skill isn't in the list or the path can't be read, say so briefly and continue with the best fallback.
- How to use a skill (progressive disclosure):
  1) After deciding to use a skill, open its `SKILL.md`. Read only enough to follow the workflow.
  2) If `SKILL.md` points to extra folders such as `references/`, load only the specific files needed for the request; don't bulk-load everything.
  3) If `scripts/` exist, prefer running or patching them instead of retyping large code blocks.
  4) If `assets/` or templates exist, reuse them instead of recreating from scratch.
- Coordination and sequencing:
  - If multiple skills apply, choose the minimal set that covers the request and state the order you'll use them.
  - Announce which skill(s) you're using and why (one short line). If you skip an obvious skill, say why.
- Context hygiene:
  - Keep context small: summarize long sections instead of pasting them; only load extra files when needed.
  - Avoid deep reference-chasing: prefer opening only files directly linked from `SKILL.md` unless you're blocked.
  - When variants exist (frameworks, providers, domains), pick only the relevant reference file(s) and note that choice.
- Safety and fallback: If a skill can't be applied cleanly (missing files, unclear instructions), state the issue, pick the next-best approach, and continue.
