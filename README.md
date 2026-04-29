# ai-skills

A small collection of standalone agent skills for WebAssembly component
work, packaged as the **Agent Skills** standard so they load in Claude
Code, Copilot CLI, Codex CLI, and any other agent that supports it.

## Skills

| Skill | What it does |
| --- | --- |
| [`component`](.agents/skills/component/SKILL.md) | Full WebAssembly component lifecycle via the `component` CLI: init / install / build / run / compose / push / pull / search. |
| [`wasm-toolchain`](.agents/skills/wasm-toolchain/SKILL.md) | Upstream Bytecode Alliance utilities (`wkg`, `wasm-tools`) and a curated component catalog. |
| [`wasmtime`](.agents/skills/wasmtime/SKILL.md) | Run / debug / profile components and core modules with the `wasmtime` runtime. |
| [`wasm-build`](.agents/skills/wasm-build/SKILL.md) | Build components from Rust, Python, JavaScript/TypeScript, or Go. |
| [`just`](.agents/skills/just/SKILL.md) | `just` command runner and Justfile recipes. |
| [`hyperlight-sandbox`](.agents/skills/hyperlight-sandbox/SKILL.md) | Hyperlight micro-VM Python SDK for hardware-isolated guest code. |

For the routing policy that picks among them when more than one might
fit a request, see [AGENTS.md](AGENTS.md) and the overlap matrix in
[`docs/skill-routing.md`](docs/skill-routing.md).

## Quick start

```bash
just bootstrap-all     # rustup, uv, Node 22, Go 1.23 (idempotent)
just install-all       # core CLIs + all language component-build tools
just populate-skills   # place tool binaries under .agents/skills/<name>/scripts/
just versions          # show pinned tool versions
```

The `Justfile` is the single source of truth for tool versions.
Run `just --list` to see all recipes.

## Layout

```
.agents/skills/
├── component/         # default WebAssembly lifecycle skill
├── wasm-toolchain/    # wkg + wasm-tools (BA utilities)
├── wasmtime/          # wasmtime runtime
├── wasm-build/        # source → .wasm per language
├── just/              # just runner
└── hyperlight-sandbox/

docs/
├── README.md          # index
├── skill-routing.md   # task × tool overlap matrix
├── allowed-tools.md   # frontmatter allowed-tools per skill
└── components.md      # building WebAssembly components

components/            # example built components (csv-groupby, stock-ticker, ...)
AGENTS.md              # repo-level routing policy + conventions
Justfile               # versions + recipes
```

## Conventions

- Each skill is **standalone**: its `description:` field is purely
  self-describing, with no peer-skill references. Routing lives in
  `AGENTS.md` and `docs/skill-routing.md` so skills are portable.
- Skill-local binaries go under `.agents/skills/<name>/scripts/` and
  are populated by `just populate-skills`.
