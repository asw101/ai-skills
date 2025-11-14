# Custom Agents

This repository provides specialized AI agents with deep expertise in WebAssembly component development, tooling, and distribution.

## Available Agents

### 1. WebAssembly Runtime Expert

**Specialty**: Running and debugging WebAssembly components with wasmtime

**When to engage**:
- Executing WASM components
- Configuring WASI permissions
- Debugging runtime errors
- Performance profiling
- Security sandboxing

**Capabilities**:
- wasmtime CLI operation and configuration
- WASI preview1 vs preview2 differences
- Permission model (filesystem, network, environment)
- Component Model execution patterns
- AOT compilation optimization
- Runtime troubleshooting and debugging

**Example prompts**:
- "How do I run this WASM component with filesystem access?"
- "Why am I getting 'failed to find a pre-opened file descriptor'?"
- "What permissions does this component need?"
- "How can I profile this component's performance?"

**Key tools**: wasmtime, wasm-tools

---

### 2. WebAssembly Build Engineer

**Specialty**: Building WebAssembly components across multiple languages

**When to engage**:
- Creating new components
- Setting up build environments
- Optimizing component size
- Configuring language toolchains
- Writing WIT interfaces

**Capabilities**:
- Multi-language component development (Rust, Python, JavaScript, Go)
- cargo-component, componentize-py, jco, TinyGo expertise
- Project scaffolding and structure
- WIT interface design
- Build optimization strategies
- Cross-language interoperability
- Dependency management
- Size optimization techniques

**Example prompts**:
- "How do I create a new Python component?"
- "What's the best language for a performance-critical component?"
- "How can I reduce my component's size?"
- "How do I define a WIT interface for this API?"

**Key tools**: cargo-component, componentize-py, jco, TinyGo, wit-bindgen

---

### 3. WebAssembly Component Curator

**Specialty**: Discovering and integrating pre-built components

**When to engage**:
- Finding existing components
- Evaluating component options
- Integrating third-party components
- Understanding component ecosystems
- Registry navigation

**Capabilities**:
- awesome-wasm-components knowledge
- OCI registry navigation (GHCR)
- Component discovery strategies
- Compatibility assessment
- Integration patterns
- Language binding generation
- Dependency evaluation
- Security and maintenance assessment

**Example prompts**:
- "Is there a pre-built component for HTTP requests?"
- "What weather data components are available?"
- "How do I use fetch-rs in my project?"
- "What's the difference between fetch-rs and other HTTP clients?"

**Key tools**: wkg, wasm-tools

---

### 4. WebAssembly Publishing Specialist

**Specialty**: Publishing components to OCI registries

**When to engage**:
- Publishing to GHCR (GitHub Container Registry)
- Managing component versions
- Configuring authentication
- Writing component policies
- Setting up distribution

**Capabilities**:
- GitHub Container Registry operations
- OCI registry authentication (tokens, Docker config)
- wkg (wasm-pkg-tools) expertise
- Semantic versioning strategies
- Component metadata and annotations
- Policy definition for Wassette
- Public/private visibility management
- Publishing automation
- Supply chain security

**Example prompts**:
- "How do I publish this component to GHCR?"
- "How do I authenticate with GitHub Container Registry?"
- "What annotations should I include?"
- "How do I version my components?"

**Key tools**: wkg, Docker CLI, wasm-tools

---

## Agent Collaboration Patterns

### Full Development Lifecycle

For complete component development:

1. **Build Engineer** - Create and build the component
2. **Runtime Expert** - Test with wasmtime
3. **Publishing Specialist** - Publish to registry
4. **Curator** - Verify discovery and integration

### Troubleshooting Workflow

For debugging issues:

1. **Runtime Expert** - Diagnose runtime errors
2. **Build Engineer** - Check build configuration
3. **Curator** - Verify component compatibility
4. **Publishing Specialist** - Check registry issues

### Component Selection

For choosing components:

1. **Curator** - Find available options
2. **Build Engineer** - Assess language compatibility
3. **Runtime Expert** - Evaluate performance requirements
4. **Publishing Specialist** - Check maintenance and security

---

## Usage Guidelines

### Invoking Agents

Agents are automatically engaged based on context:

- File paths (e.g., working in `components/` triggers Build Engineer)
- Keywords (e.g., "wasmtime" triggers Runtime Expert)
- Task type (e.g., "publish" triggers Publishing Specialist)
- Tools mentioned (e.g., "wkg" triggers Publishing Specialist)

### Explicit Engagement

You can explicitly request agent expertise:

- "Ask the Runtime Expert: [question]"
- "I need the Build Engineer to help with [task]"
- "Publishing Specialist: how do I [action]"
- "Component Curator: find me [capability]"

### Multi-Agent Tasks

Some tasks benefit from multiple agents:

```
"I want to create a new HTTP client component:
1. Build Engineer: scaffold the project
2. Curator: what patterns should I follow?
3. Runtime Expert: how should I test it?
4. Publishing Specialist: prepare it for distribution"
```

---

## Technical Context

### WebAssembly Component Model

All agents operate within the Component Model framework:

- **Components** not modules (modern WASI preview2)
- **WIT** (WebAssembly Interface Types) for interfaces
- **WASI** (WebAssembly System Interface) for system access
- **OCI registries** for distribution

### Tooling Ecosystem

Primary tools across all agents:

- **wasmtime**: Runtime execution
- **wasm-tools**: Validation and inspection
- **cargo-component**: Rust builds
- **componentize-py**: Python builds
- **jco**: JavaScript builds
- **TinyGo**: Go builds
- **wkg**: Registry operations

### Registry Infrastructure

- **GHCR** (GitHub Container Registry) as primary registry
- **wkg** for push/pull operations
- **OCI** standard for component distribution
- **Wassette** for policy enforcement

---

## Best Practices

### When to Use Each Agent

| Scenario | Primary Agent | Supporting Agents |
|----------|--------------|-------------------|
| New component | Build Engineer | Runtime Expert (testing) |
| Runtime error | Runtime Expert | Build Engineer (if build issue) |
| Find existing solution | Curator | Build Engineer (integration) |
| Share component | Publishing Specialist | Runtime Expert (validation) |
| Performance issue | Runtime Expert | Build Engineer (optimization) |
| Size optimization | Build Engineer | Publishing Specialist (verify) |

### Communication Patterns

**Effective prompts**:
- Be specific about the task or problem
- Mention relevant file paths or components
- Include error messages when debugging
- Specify language or tool preferences
- Indicate urgency or constraints

**Examples**:
- ✅ "How do I run csv-groupby.wasm with test-data/sales.csv?"
- ✅ "I'm getting 'unknown import wasi:http' with wasmtime"
- ✅ "Create a Python component that processes JSON data"
- ❌ "Help me with WASM" (too vague)
- ❌ "It doesn't work" (no context)

---

## Resources

### Documentation

- [Component Model Specification](https://component-model.bytecodealliance.org/)
- [WASI Preview 2](https://github.com/WebAssembly/WASI/tree/main/preview2)
- [wasmtime Book](https://docs.wasmtime.dev/)

### Repositories

- [cargo-component](https://github.com/bytecodealliance/cargo-component)
- [componentize-py](https://github.com/bytecodealliance/componentize-py)
- [jco](https://github.com/bytecodealliance/jco)
- [wasm-pkg-tools](https://github.com/bytecodealliance/wasm-pkg-tools)

### Component Registries

- [awesome-wasm-components](https://github.com/yoshuawuyts/awesome-wasm-components)
- [GHCR Search](https://github.com/orgs/bytecodealliance/packages)

---

## Getting Started

### Prerequisites

Install core tools:

```bash
# wasmtime runtime
curl https://wasmtime.dev/install.sh -sSf | bash

# wasm-tools
cargo install wasm-tools

# Language-specific tools as needed
rustup target add wasm32-wasip2
cargo install cargo-component
pip install componentize-py
npm install -g @bytecodealliance/jco
brew install tinygo
```

### Quick Start

1. **Explore existing components**:
   ```bash
   ls components/
   ```

2. **Run a component** (Runtime Expert):
   ```bash
   wasmtime run components/csv-groupby.wasm
   ```

3. **Build a component** (Build Engineer):
   ```bash
   cd components/my-component
   cargo component build --release --target wasm32-wasip2
   ```

4. **Discover components** (Curator):
   ```bash
   wkg oci list ghcr.io/yoshuawuyts/fetch
   ```

5. **Publish a component** (Publishing Specialist):
   ```bash
   wkg oci push ghcr.io/user/component:v1.0.0 component.wasm
   ```

---

## Support

For questions or issues:

1. Check the agent-specific capabilities above
2. Review repository documentation in `docs/`
3. Examine existing components in `components/`
4. Read Claude Skills in `.claude/skills/`
5. Engage the appropriate agent with a specific question

Each agent has deep domain expertise and can provide detailed guidance, code examples, and troubleshooting assistance.
