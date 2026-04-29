# Agent Skills

This repository uses **Agent Skills** — an open standard for extending AI coding assistants with specialized capabilities.

## What are Agent Skills?

Agent Skills are folders containing instructions, scripts, and resources that AI agents load when relevant. They work across multiple platforms:

- **VS Code Copilot** — Enable `chat.useAgentSkills` setting
- **Claude Code** — Skills auto-activate based on keywords
- **GitHub Copilot CLI** — Accessible in terminal workflows
- **GitHub Copilot coding agent** — Used in automated coding tasks

## Skill Location

Skills are stored in `.agents/skills/` (cross-platform) or `.github/skills/` (GitHub standard).

```
.agents/skills/
├── skill-name/
│   ├── SKILL.md          # Required: metadata + instructions
│   └── scripts/          # Optional: binaries, helpers
```

## SKILL.md Format

```markdown
---
name: skill-name
description: When to use this skill and what it does
---

# Skill Instructions

Detailed instructions, commands, examples...
```

## Available Skills

| Skill | Description |
|-------|-------------|
| `wasm-run` | Run and debug WebAssembly components with wasmtime |
| `wasm-build` | Build components from Rust, Python, JavaScript, Go |
| `wasm-search` | Discover components from awesome-wasm-components |
| `wasm-registry` | Publish components to OCI registries (GHCR) |
| `just` | Work with just command runner and Justfiles |

## How It Works

1. **Discovery** — Agent reads skill names and descriptions
2. **Loading** — When your request matches, full instructions load
3. **Resources** — Scripts and examples load on-demand

Skills activate automatically based on your prompt — no manual selection needed.

## Learn More

- [Agent Skills Standard](https://agentskills.io/)
- [VS Code Agent Skills](https://code.visualstudio.com/docs/copilot/customization/agent-skills)
- [Skill Details](skills-overview.md)
