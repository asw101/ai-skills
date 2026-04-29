# docs

Reference documentation for this repo. Most of the routing context
lives at the repo root in [`AGENTS.md`](../AGENTS.md) and
[`README.md`](../README.md); these files cover specifics.

| File | Purpose |
| --- | --- |
| [`skill-routing.md`](skill-routing.md) | Task × tool overlap matrix for the four overlapping WebAssembly skills (`component`, `wasm-toolchain`, `wasmtime`, `wasm-build`) plus a quick decision tree. |
| [`allowed-tools.md`](allowed-tools.md) | What `allowed-tools` each skill declares, plus the local-binary preference snippet used in skill scripts. |
| [`components.md`](components.md) | Reference for **building** WebAssembly components: WIT, language toolchains, build flows, troubleshooting. |

## See also

- [`AGENTS.md`](../AGENTS.md) — repo-level skill inventory and routing
  policy. Read first.
- [`README.md`](../README.md) — project overview, quick start, layout.
- [Agent Skills standard](https://agentskills.io/) — the format used
  by the `.agents/skills/<name>/SKILL.md` files.
