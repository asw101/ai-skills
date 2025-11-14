---
applyTo:
  - .claude/skills/**
  - docs/**/*.md
  - "*.md"
  - .github/**/*.md
---

# WebAssembly Tooling Documentation Instructions

When working with documentation files, skill definitions, or repository-level markdown, use these guidelines to maintain consistency with WebAssembly tooling practices.

## Tooling Reference Standards

### wasmtime Runtime

**Version considerations**:
- WASI preview2 requires wasmtime v14.0.0+
- Document version requirements explicitly
- Include upgrade path for legacy components

**Command patterns**:
```bash
# Basic execution
wasmtime run component.wasm

# With permissions
wasmtime run --dir /path --env KEY=value component.wasm

# Function invocation
wasmtime run --invoke 'function(args)' component.wasm

# AOT compilation
wasmtime compile component.wasm -o component.cwasm
wasmtime run component.cwasm
```

**Permission model**:
- Document required `--dir` flags
- Specify environment variables needed
- Note network permission requirements
- Follow principle of least privilege

### Build Tool Commands

**Rust (cargo-component)**:
```bash
cargo component new component-name --lib
cargo component build --release --target wasm32-wasip2
```

**Python (componentize-py)**:
```bash
componentize-py bindings .
componentize-py componentize app -o output.wasm
```

**JavaScript (jco)**:
```bash
jco componentize src/index.js -w wit -o output.wasm
jco types wit/world.wit -o types.d.ts
```

**Go (TinyGo)**:
```bash
go generate  # wit-bindgen-go
tinygo build -target=wasip2 -o output.wasm .
```

### Registry Operations

**wkg (wasm-pkg-tools)**:
```bash
# Pull component
wkg oci pull ghcr.io/user/component:tag -o output.wasm

# Push component
wkg oci push ghcr.io/user/component:tag input.wasm

# List versions
wkg oci list ghcr.io/user/component
```

**Authentication patterns**:
```bash
# Docker config method
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Environment variables
export WKG_OCI_USERNAME="username"
export WKG_OCI_PASSWORD="token"
```

### Component Inspection

**wasm-tools**:
```bash
# Validate component
wasm-tools validate component.wasm

# Extract WIT
wasm-tools component wit component.wasm

# Show metadata
wasm-tools component metadata show component.wasm
```

## Documentation Structure Standards

### README.md Pattern

```markdown
# Project/Component Name

Brief overview paragraph.

## Purpose

What problem does this solve?

## Prerequisites

- Tool version requirements
- System dependencies
- Installation commands

## Quick Start

Minimal working example.

## Usage

Detailed usage with examples.

## Building

Build instructions for all supported languages.

## Examples

Reference to test data and example usage.

## Troubleshooting

Common issues and solutions.

## Resources

Links to official documentation.
```

### USAGE.md Pattern

```markdown
# Usage Examples

## Basic Usage
\`\`\`bash
# Command with output
wasmtime run component.wasm
\`\`\`

## Advanced Usage
\`\`\`bash
# With options explained
wasmtime run --dir ./data component.wasm
\`\`\`

## Example Scenarios

### Scenario 1: Description
Commands and expected output.

### Scenario 2: Description
Commands and expected output.

## Common Patterns

Reusable command patterns.

## Testing

How to verify functionality.
```

## Code Block Standards

### Command Examples

Use bash syntax highlighting and include comments:

```bash
# Step 1: Setup environment
export VAR=value

# Step 2: Build component
cargo component build --release --target wasm32-wasip2

# Step 3: Test execution
wasmtime run output.wasm
```

### Multi-Language Examples

Group by language with clear headers:

**Rust**:
```rust
// Code example
```

**Python**:
```python
# Code example
```

**JavaScript**:
```javascript
// Code example
```

**Go**:
```go
// Code example
```

### Configuration Files

Use appropriate syntax highlighting:

**Cargo.toml**:
```toml
[package]
name = "component"
```

**package.json**:
```json
{
  "name": "component"
}
```

**WIT**:
```wit
package namespace:component;
```

## Technical Accuracy Requirements

### Component Model Terminology

- "WebAssembly Component Model" (not "WASM component model")
- "Component" (not "module" when referring to Component Model)
- "WIT" or "WebAssembly Interface Types" (full term on first use)
- "WASI preview2" (not "WASI 0.2.0" in prose)

### Build Target Naming

- `wasm32-wasip1` - Legacy WASI preview1
- `wasm32-wasip2` - Modern WASI preview2
- `wasm32-unknown-unknown` - Core WebAssembly (no WASI)

Use `wasm32-wasip2` as the default recommendation.

### Registry URL Format

- **Correct**: `ghcr.io/user/component:tag`
- **Incorrect**: `oci://ghcr.io/user/component:tag` (only for Wassette)

Document when `oci://` prefix is needed.

### File Extensions

- `.wasm` - WebAssembly binary (component or module)
- `.wit` - WebAssembly Interface Types definition
- `.cwasm` - Compiled (AOT) WebAssembly

## Version Documentation

### Tool Versions

When documenting tool requirements:

```markdown
## Prerequisites

- wasmtime v14.0.0+ (WASI preview2 support)
- cargo-component v0.13.0+
- wkg v0.5.0+
```

### API Versions

When documenting WASI APIs:

```wit
import wasi:cli/environment@0.2.0;
import wasi:filesystem/types@0.2.0;
```

Always include version specifiers in WIT examples.

## Error Documentation

### Troubleshooting Sections

Structure as symptom → solution:

```markdown
### "failed to find a pre-opened file descriptor"

**Cause**: Component trying to access filesystem without permission.

**Solution**: Add `--dir` flag to grant access:
\`\`\`bash
wasmtime run --dir /path/to/data component.wasm
\`\`\`
```

### Common Error Patterns

Document these consistently across all files:

**Runtime Errors**:
- Permission denied (missing `--dir` or `--env`)
- Unknown import (WASI version mismatch)
- Component validation failed (corrupted binary)

**Build Errors**:
- Missing target (rustup/toolchain issue)
- Binding generation failed (WIT syntax error)
- Dependency incompatibility (WASI compatibility)

**Registry Errors**:
- Authentication required (token permissions)
- Manifest invalid (not a component)
- Reference not found (URL format)

## Link Standards

### Internal Links

Use relative paths from repository root:

```markdown
See [Component README](components/component-name/README.md)
See [Build Instructions](.claude/skills/wasm-build/SKILL.md)
```

### External Links

Use descriptive text with full URLs:

```markdown
- [wasmtime Documentation](https://docs.wasmtime.dev/)
- [Component Model Specification](https://component-model.bytecodealliance.org/)
- [WASI Preview 2](https://github.com/WebAssembly/WASI/tree/main/preview2)
```

### Tool Documentation

Provide authoritative sources:

```markdown
## Resources

- **wasmtime**: https://docs.wasmtime.dev/
- **cargo-component**: https://github.com/bytecodealliance/cargo-component
- **componentize-py**: https://github.com/bytecodealliance/componentize-py
- **jco**: https://github.com/bytecodealliance/jco
- **TinyGo**: https://tinygo.org/docs/
- **wkg**: https://github.com/bytecodealliance/wasm-pkg-tools
```

## Tables and Comparisons

### Language Comparison Format

```markdown
| Language | Component Size | Build Time | Performance | Best For |
|----------|---------------|------------|-------------|----------|
| **Rust** | Small | Slow | Excellent | Performance |
| **Python** | Large | Fast | Good | Rapid development |
| **JavaScript** | Medium | Fast | Good | Web integration |
| **Go** | Small | Fast | Excellent | Systems programming |
```

### Command Option Tables

```markdown
| Option | Description | Example |
|--------|-------------|---------|
| `--dir DIR` | Grant directory access | `--dir /tmp` |
| `--env KEY=VAL` | Set environment variable | `--env DEBUG=1` |
| `--invoke FUNC` | Call specific function | `--invoke 'run()'` |
```

## Skill Definition Standards

When documenting Claude Skills or capabilities:

### Description Format

```yaml
description: |
  Concise one-line summary of capability.
  
  Detailed explanation of when this skill applies and what expertise it provides.
  
  Technical scope and limitations.
```

### Activation Patterns

Document trigger keywords that indicate skill relevance:

```markdown
## When to Use This Skill

- User mentions "wasmtime" or "run wasm"
- Discussion involves WASI permissions
- Questions about Component Model execution
- Debugging runtime errors
```

### Progressive Disclosure

Structure content in three levels:

1. **Quick Reference** (always loaded)
2. **Detailed Procedures** (loaded when needed)
3. **Deep Technical Context** (loaded for complex scenarios)

## Maintenance Notes

### Deprecation Warnings

```markdown
> **Note**: WASI preview1 is deprecated. Use preview2 for new components.
> See [migration guide](link) for upgrade instructions.
```

### Experimental Features

```markdown
> **Experimental**: This feature requires wasmtime v19.0.0+ and may change.
```

### Security Considerations

```markdown
> **Security**: Always grant minimal permissions with `--dir` and `--env`.
> WebAssembly sandboxing only protects with explicit permission grants.
```

## Formatting Conventions

- Use `**bold**` for tool names on first mention
- Use `backticks` for commands, file paths, and code identifiers
- Use `>` blockquotes for warnings and important notes
- Use numbered lists for sequential procedures
- Use bulleted lists for options or features
- Use horizontal rules (`---`) to separate major sections

## Quality Checklist

When reviewing documentation:

- [ ] All commands tested and produce described output
- [ ] Version requirements explicitly stated
- [ ] Error messages include actionable solutions
- [ ] Code examples use consistent formatting
- [ ] Links point to current documentation
- [ ] Terminology matches official specifications
- [ ] Examples work across all supported platforms
- [ ] Security implications documented
