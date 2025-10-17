# Allowed Tools Configuration for Skills

This document proposes more restrictive `allowed-tools` configurations for the skills to ensure only approved binaries are executed automatically.

## Current Configuration

Currently, all skills allow the `Bash` tool, which permits execution of any command. This is flexible but potentially allows unintended command execution.

## Proposed Changes

### Problem

With `allowed-tools: Bash, Read, Write, Edit, Glob, Grep`, skills can execute any binary via the Bash tool. This means:
- Skills might accidentally use system-installed binaries instead of our controlled versions
- No guarantee that only our vetted binaries are executed
- Less control over what commands are actually run

### Solution

Since Claude Code's `allowed-tools` doesn't support restricting specific Bash commands, we have a few options:

## Option 1: Keep Bash but add explicit instructions (Current Approach)

**Pros:**
- Most flexible
- Skills work out of the box
- Can adapt to different environments

**Cons:**
- Relies on skill prompt adherence
- No technical enforcement
- Can accidentally execute wrong binaries

**Implementation:** Already done in SKILL.md files with binary detection logic.

## Option 2: Remove Bash, use wrapper scripts

**Proposed Structure:**
```
.claude/skills/just/
├── SKILL.md
└── scripts/
    ├── just              # The actual binary (gitignored)
    └── run-just.sh       # Wrapper script (committed)

.claude/skills/wasmtime/
├── SKILL.md
└── scripts/
    ├── wasmtime          # The actual binary (gitignored)
    └── run-wasmtime.sh   # Wrapper script (committed)

.claude/skills/awesome-wasm/
├── SKILL.md
├── components.json
└── scripts/
    ├── wkg               # Binary (gitignored)
    ├── wasm-tools        # Binary (gitignored)
    ├── run-wkg.sh        # Wrapper (committed)
    └── run-wasm-tools.sh # Wrapper (committed)
```

**Wrapper Script Example (run-just.sh):**
```bash
#!/bin/bash
# Wrapper for just binary
# This ensures we use the correct binary with proper fallback

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JUST_BINARY="$SCRIPT_DIR/just"

if [ -x "$JUST_BINARY" ]; then
    exec "$JUST_BINARY" "$@"
elif command -v just &> /dev/null; then
    exec just "$@"
else
    echo "Error: just binary not found in $SCRIPT_DIR and not installed globally" >&2
    exit 1
fi
```

**Updated allowed-tools:**
```yaml
allowed-tools: Read, Write, Edit, Glob, Grep
```

**Pros:**
- No Bash tool access means no arbitrary command execution
- Wrapper scripts provide controlled execution
- Scripts committed to repo, binaries gitignored
- Clear audit trail of what can be executed

**Cons:**
- Less flexible (can't run arbitrary just/wasmtime commands without updating wrapper)
- More complex setup
- Skills would need to be updated to call wrapper scripts
- Might not work well with Claude Code's tool restrictions

## Option 3: Hybrid - Keep Bash but provide safe wrapper scripts

**Structure:** Same as Option 2

**Updated SKILL.md guidance:**
```yaml
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
```

But update the SKILL.md to strongly recommend using wrapper scripts:

```markdown
## Binary execution

**IMPORTANT**: To ensure consistent and safe execution, always use the wrapper scripts:

- Use `./scripts/run-just.sh` instead of directly calling `just`
- Use `./scripts/run-wasmtime.sh` instead of directly calling `wasmtime`

These wrappers ensure:
1. Local binaries are used when available
2. Fallback to system binaries if needed
3. Proper error handling
4. Consistent execution environment
```

**Pros:**
- Maintains flexibility of Bash tool
- Provides safe defaults via wrappers
- Easy to audit what's being executed
- Wrappers can add logging, validation, etc.

**Cons:**
- Still relies on skill prompt adherence
- Can be bypassed by skill if it ignores instructions

## Recommendation

**Short term:** Option 1 (current approach)
- Keep current implementation
- Monitor behavior
- Document expected patterns

**Long term:** Option 3 (hybrid approach)
- Add wrapper scripts for better control
- Easier to audit and debug
- More portable across environments
- Can add features like logging, validation, version checks

## Implementation Steps for Option 3

1. Create wrapper scripts for each skill:
   - `just/scripts/run-just.sh`
   - `wasmtime/scripts/run-wasmtime.sh`
   - `awesome-wasm/scripts/run-wkg.sh`
   - `awesome-wasm/scripts/run-wasm-tools.sh`

2. Update SKILL.md files to use wrappers as the primary execution method

3. Add wrapper scripts to git (keep binaries gitignored)

4. Update documentation to explain wrapper usage

5. Add examples in SKILL.md showing wrapper usage

## Security Considerations

### Current Approach
- Skills can execute any command via Bash
- Relies on prompt engineering to restrict behavior
- No technical enforcement

### With Wrappers
- Clear, auditable execution paths
- Can add validation (e.g., prevent dangerous flags)
- Can add logging for debugging
- Can enforce version checks
- Still allows flexibility when needed

### Best Practices
- Always check wrapper scripts are executable: `chmod +x scripts/*.sh`
- Review wrapper scripts in code reviews
- Document any changes to wrapper behavior
- Consider adding tests for wrapper scripts

## Related Configuration

Update `.gitignore` to ensure wrappers ARE committed:
```gitignore
# Skill binaries - don't commit local tool binaries
.claude/skills/just/scripts/just
.claude/skills/wasmtime/scripts/wasmtime
.claude/skills/awesome-wasm/scripts/wkg
.claude/skills/awesome-wasm/scripts/wasm-tools

# Wrapper scripts SHOULD be committed (not in .gitignore)
# .claude/skills/*/scripts/*.sh
```

## Future Considerations

If Claude Code adds support for:
- Custom tool definitions
- Command allowlists
- Restricted Bash execution

We should revisit this configuration to take advantage of those features.

## Questions for Team Discussion

1. Is the current approach (Option 1) sufficient for our needs?
2. Should we implement wrappers (Option 3) for better control?
3. Do we need logging/audit trails for skill executions?
4. Should we add version checks to ensure compatible binaries?
5. Do we need cross-platform support (Linux/macOS/Windows)?

---

**Document Status:** Proposal
**Last Updated:** 2025-10-17
**Requires Decision:** Yes
