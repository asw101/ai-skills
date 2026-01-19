# Allowed Tools Configuration

Skills define which Claude Code tools they can use via the `allowed-tools` frontmatter in SKILL.md.

## Current Configuration

| Skill | Allowed Tools |
|-------|---------------|
| wasmtime | Bash, Read, Write, Edit, Glob, Grep |
| wasm-build | Bash, Read, Write, Edit, Glob, Grep |
| awesome-wasm | Bash, Read, Write, Edit, Glob, Grep, WebFetch |
| wasm-oci | Bash, Read, Write, Edit, Glob, Grep, WebFetch |
| just | Bash, Read, Write, Edit, Glob, Grep |

## Security Notes

- Skills with `Bash` can execute any command
- Behavior is controlled by instructions in SKILL.md, not technical enforcement
- Skills prefer local binaries in `scripts/` directories when available
- `wasm-oci` uses a wrapper script (`scripts/run-wkg.sh`) for consistent `wkg` invocation

## Wrapper Scripts

To add controlled execution for a skill:

```bash
# .claude/skills/<skill>/scripts/run-<tool>.sh
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY="$SCRIPT_DIR/<tool>"

if [ -x "$BINARY" ]; then
    exec "$BINARY" "$@"
elif command -v <tool> &> /dev/null; then
    exec <tool> "$@"
else
    echo "Error: <tool> not found" >&2
    exit 1
fi
```

This provides local binary preference and fallback to system installation.

---

**Last Updated:** 2026-01-19