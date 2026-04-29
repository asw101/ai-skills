# Allowed Tools Configuration

Skills declare which Claude Code / agent tools they may use via the
`allowed-tools` frontmatter in `SKILL.md`. This document just mirrors
that frontmatter for quick reference.

## Current Configuration

| Skill | Allowed Tools |
|-------|---------------|
| `component` | Bash, Read, Write, Edit, Glob, Grep |
| `wasm-toolchain` | Bash, Read, Write, Edit, Glob, Grep, WebFetch |
| `wasmtime` | Bash, Read, Write, Edit, Glob, Grep |
| `wasm-build` | Bash, Read, Write, Edit, Glob, Grep, WebFetch |
| `just` | Bash, Read, Write, Edit, Glob, Grep |
| `hyperlight-sandbox` | Bash, Read, Write, Edit, Glob, Grep |

`WebFetch` is granted only to skills that need to pull live upstream
docs (catalog scrapes, SDK examples, recipe references).

## Security Notes

- Skills with `Bash` can execute any command. Behaviour is constrained
  by the instructions in `SKILL.md`, not by technical enforcement.
- Skills prefer skill-local binaries under `scripts/` when present
  (resolved with `[ -x "$TOOL" ] || TOOL="<tool>"`), falling back to
  the system-installed binary on `$PATH`.

## Local-binary preference pattern

Each skill that wraps a CLI uses this resolution snippet at the top of
its scripts:

```bash
SKILL_DIR=".agents/skills/<skill-name>"
TOOL="$SKILL_DIR/scripts/<tool>"
[ -x "$TOOL" ] || TOOL="<tool>"

"$TOOL" "$@"
```

To populate skill-local binaries, run `just populate-skills`.

---

**Last Updated:** 2026-04-29
