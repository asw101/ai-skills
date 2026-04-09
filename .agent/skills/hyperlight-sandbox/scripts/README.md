# hyperlight-sandbox scripts

This directory is reserved for local scripts, binaries, or helpers used by the hyperlight-sandbox skill.

## Building from source

Hyperlight Sandbox is a Rust + Python project. To build and install locally:

### Python SDK (recommended for most users)

```bash
# Install pre-built wheels with Wasm backend and Python guest
uv pip install "hyperlight-sandbox[wasm,python_guest]"
```

### From source

```bash
# Clone the repository
git clone https://github.com/hyperlight-dev/hyperlight-sandbox.git
cd hyperlight-sandbox

# Build everything (requires just, uv, npm, Rust 1.89+)
just build

# Or build only the Python SDK
just python build
```

### Prerequisites

- **Hypervisor**: KVM (Linux), MSHV (Linux), or Hyper-V (Windows)
- **Rust**: Edition 2024, version 1.89+
- **Python**: 3.10+
- **Tools**: `just`, `uv`, `npm`

## Why build from source?

- Access to the latest features before they are published as wheels
- Develop custom Wasm guest modules using the WIT interface
- Contribute to the project or run the full test suite
- Build for platforms without pre-built wheels
