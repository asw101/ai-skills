---
name: hyperlight-sandbox
description: Use this skill when running untrusted code in hardware-isolated sandboxes, registering host tools for guest code, working with Hyperlight micro-VMs, or using the hyperlight-sandbox Python SDK. Covers sandbox creation, code execution, tool dispatch, file I/O, network allowlisting, and snapshot/restore.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# hyperlight-sandbox skill

You are a specialized assistant for working with **Hyperlight Sandbox**, a multi-backend sandboxing framework for running untrusted code with controlled host capabilities inside hardware-isolated micro virtual machines.

## About Hyperlight Sandbox

Hyperlight Sandbox provides a unified API across multiple isolation backends. It enables secure code execution inside lightweight VMs (KVM, MSHV, Hyper-V) with a capability-based security model — host tools, file access, and network traffic are all explicitly granted.

**Repository**: https://github.com/hyperlight-dev/hyperlight-sandbox
**Built on**: [Hyperlight](https://github.com/hyperlight-dev/hyperlight) (CNCF sandbox project)
**SDKs**: Python and Rust
**Version**: 0.3.0

## Your capabilities

When this skill is invoked, you should help users:

1. **Create sandboxes**: Set up isolated execution environments with the appropriate backend and guest
2. **Execute code**: Run Python or JavaScript code inside sandboxes
3. **Register host tools**: Define callable functions that guest code can invoke by name
4. **Manage file I/O**: Configure read-only input directories and writable output directories
5. **Control network access**: Allowlist specific domains and HTTP methods
6. **Snapshot and restore**: Capture and rewind sandbox runtime state
7. **Build from source**: Compile Rust backends, Wasm guests, and the Python SDK
8. **Integrate with agents**: Use `CodeExecutionTool` for agent framework integration

## Sandbox backends

| Backend | Guest Languages | Key Feature | Module |
|---------|----------------|-------------|--------|
| **Wasm** (default) | Python, JavaScript | Full capability surface via WIT bindings | `hyperlight-wasm` |
| **HyperlightJS** | JavaScript only | Smaller footprint, direct JS execution | `hyperlight-js` |
| **Nanvix** | JavaScript, Python | Microkernel-based, basic execution only | Experimental |

## Python SDK quick start

### Installation

```bash
# Install with Wasm backend and Python guest
uv pip install "hyperlight-sandbox[wasm,python_guest]"

# Or with JavaScript guest
uv pip install "hyperlight-sandbox[wasm,javascript_guest]"

# Or with HyperlightJS backend
uv pip install "hyperlight-sandbox[hyperlight_js]"
```

### Basic usage

```python
from hyperlight_sandbox import Sandbox

# Create a sandbox with the Wasm backend and Python guest
sandbox = Sandbox(backend="wasm", module="python_guest.path")

# Register host tools before the first run()
sandbox.register_tool("add", lambda a=0, b=0: a + b)

# Execute code inside the sandbox
result = sandbox.run('''
total = call_tool('add', a=3, b=4)
print(f"3 + 4 = {total}")
''')
print(result.stdout)   # "3 + 4 = 7\n"
print(result.success)  # True
```

### Tool dispatch

```python
import asyncio

sandbox = Sandbox(backend="wasm", module="python_guest.path")

# Sync tool
sandbox.register_tool("multiply", lambda a=0, b=0: a * b)

# Async tools work too — no wrapping needed
async def fetch_data(url: str = ""):
    await asyncio.sleep(0.1)
    return {"status": 200, "url": url}

sandbox.register_tool("fetch_data", fetch_data)

result = sandbox.run("""
product = call_tool('multiply', a=6, b=7)
data = call_tool('fetch_data', url='https://example.com')
print(f"6 * 7 = {product}")
print(f"fetch status: {data['status']}")
""")
```

### Network allowlisting

```python
sandbox = Sandbox(backend="wasm", module="python_guest.path")

# Network is OFF by default — explicitly allow domains
sandbox.allow_domain("https://httpbin.org")
sandbox.allow_domain("https://api.example.com", methods=["GET", "POST"])

result = sandbox.run("""
resp = http_get('https://httpbin.org/get')
print(f"HTTP status: {resp['status']}")
""")
```

### File I/O

```python
sandbox = Sandbox(
    backend="wasm",
    module="python_guest.path",
    input_dir="./data",       # Read-only /input inside sandbox
    output_dir="./results",   # Writable /output inside sandbox
)

result = sandbox.run("""
# Read from /input (host's ./data directory)
content = read_file('/input/data.csv')
# Write to /output (host's ./results directory)
write_file('/output/summary.txt', 'processed')
""")

# List files written by guest
output_files = sandbox.get_output_files()
host_output_path = sandbox.output_path()
```

### Snapshot and restore

```python
sandbox = Sandbox(backend="wasm", module="python_guest.path")
sandbox.run("x = 42; print(f'x = {x}')")

# Capture state
snap = sandbox.snapshot()

sandbox.run("x = 100")

# Rewind to captured state
sandbox.restore(snap)
sandbox.run("print(f'x = {x}')")  # x = 42 again
```

### JavaScript guest (Wasm backend)

```python
sandbox = Sandbox(backend="wasm", module="javascript_guest.path")
sandbox.register_tool("add", lambda a=0, b=0: a + b)

result = sandbox.run("""
const sum = call_tool('add', { a: 10, b: 20 });
console.log('10 + 20 = ' + sum);
""")
```

### HyperlightJS backend

```python
sandbox = Sandbox(backend="hyperlight-js")
sandbox.register_tool("add", lambda a=0, b=0: a + b)

result = sandbox.run("""
const sum = call_tool('add', { a: 10, b: 20 });
console.log('10 + 20 = ' + sum);
""")
```

## Rust SDK

### Wasm backend

```rust
use hyperlight_sandbox::{Sandbox, ToolRegistry};
use hyperlight_wasm_sandbox::Wasm;
use serde::Deserialize;

#[derive(Deserialize)]
struct MathArgs { a: f64, b: f64 }

fn main() {
    let mut tools = ToolRegistry::new();
    tools.register_typed::<MathArgs, _>("add", |args| {
        Ok(serde_json::json!(args.a + args.b))
    });

    let mut sandbox = Sandbox::builder()
        .guest(Wasm)
        .module_path("guests/python/python-sandbox.aot")
        .with_tools(tools)
        .build()
        .expect("failed to create sandbox");

    let result = sandbox.run(r#"
result = call_tool('add', a=3, b=4)
print(f"3 + 4 = {result}")
"#).unwrap();
    print!("{}", result.stdout);
}
```

### HyperlightJS backend

```rust
use hyperlight_javascript_sandbox::HyperlightJs;
use hyperlight_sandbox::{Sandbox, ToolRegistry};
use serde::Deserialize;

#[derive(Deserialize)]
struct MathArgs { a: f64, b: f64 }

fn main() {
    let mut tools = ToolRegistry::new();
    tools.register_typed::<MathArgs, _>("add", |args| {
        Ok(serde_json::json!(args.a + args.b))
    });

    let mut sandbox = Sandbox::builder()
        .guest(HyperlightJs)
        .with_tools(tools)
        .build()
        .expect("failed to create sandbox");

    let result = sandbox.run(r#"
const sum = call_tool('add', { a: 10, b: 20 });
console.log('10 + 20 = ' + sum);
"#).unwrap();
    print!("{}", result.stdout);
}
```

## Agent framework integration

### CodeExecutionTool

```python
from hyperlight_sandbox import CodeExecutionTool, SandboxEnvironment

tool = CodeExecutionTool(
    environment=SandboxEnvironment(
        backend="wasm",
        module="python_guest.path",
        input_dir="./data",
        temp_output=True,
    ),
    tools=[lambda a=0, b=0: a + b],  # callable tools
)

result = tool.run("print('hello from agent')")
```

## Sandbox configuration options

| Parameter | Default | Description |
|-----------|---------|-------------|
| `backend` | `"wasm"` | Backend to use: `"wasm"` or `"hyperlight-js"` |
| `module` | `"python_guest.path"` | Guest module reference (Wasm backend only) |
| `module_path` | `None` | Direct path to `.aot` guest binary |
| `input_dir` | `None` | Host directory mounted read-only as `/input` |
| `output_dir` | `None` | Host directory mounted writable as `/output` |
| `temp_output` | `False` | Auto-create a temporary output directory |
| `heap_size` | `"25Mi"` (Linux) / `"400Mi"` (Windows) | Guest heap size |
| `stack_size` | `"35Mi"` (Linux) / `"200Mi"` (Windows) | Guest stack size |

## Security model

- **Hardware isolation**: Code runs inside micro-VMs (KVM/MSHV/Hyper-V)
- **No network by default**: All network access is denied unless explicitly allowed with `allow_domain()`
- **Capability-based file access**: Read-only `/input`, writable `/output`, strict path isolation
- **Tool dispatch**: Guest code can only call tools explicitly registered by the host
- **Code size limit**: 10 MiB maximum per `run()` call
- **Output files are ephemeral**: `/output` is cleared before each `run()`

## Building from source

### Prerequisites

- `just` (command runner)
- `uv` (Python package manager)
- `npm`
- Rust toolchain (edition 2024, Rust 1.89+)
- KVM, MSHV, or Hyper-V for VM isolation

### Build commands

```bash
# Build everything (Rust backends, Wasm guests, Python SDK)
just build

# Run full test suite (Rust + Python)
just test

# Lint Rust and Python code
just lint

# Format all code
just fmt

# Run examples
just examples

# Build Python distribution packages
just python-dist
```

## Key concepts

### Micro virtual machines
Hyperlight creates lightweight VMs for each sandbox, providing hardware-level isolation without the overhead of traditional VMs. Startup times are measured in milliseconds.

### Guest modules
Packaged `.aot` (ahead-of-time compiled) Wasm components that provide the language runtime inside the sandbox. The Python guest embeds CPython; the JavaScript guest embeds a JS engine.

### Tool dispatch
Host-registered callables are exposed to guest code via `call_tool(name, **kwargs)`. Arguments are schema-validated JSON. Both sync and async host functions are supported.

### WIT interface
The Wasm backend uses a WIT (WebAssembly Interface Types) contract defined in `src/wasm_sandbox/wit/hyperlight-sandbox.wit`. Custom guests can be built against this interface.

### Snapshot/restore
Captures the full guest runtime state (memory, globals, interpreter state) plus sandbox-managed files. Restoring rewinds to the exact captured point. Useful for sandbox reuse across independent executions.

## Common patterns

### Process files and return results

```python
sandbox = Sandbox(
    backend="wasm",
    module="python_guest.path",
    input_dir="./uploads",
    temp_output=True,
)

result = sandbox.run("""
import json
data = read_file('/input/report.json')
parsed = json.loads(data)
summary = f"Records: {len(parsed)}"
write_file('/output/summary.txt', summary)
print(summary)
""")

output_files = sandbox.get_output_files()
```

### Code mode (reduce token usage)

```python
sandbox = Sandbox(backend="wasm", module="python_guest.path")
sandbox.register_tool("fetch_data", my_fetch_function)
sandbox.register_tool("compute", my_compute_function)

# Agent writes a script that calls tools directly
result = sandbox.run(agent_generated_code)
```

### Reusable sandbox with snapshot

```python
sandbox = Sandbox(backend="wasm", module="python_guest.path")
sandbox.register_tool("add", lambda a=0, b=0: a + b)

# Warm up and snapshot the clean state
sandbox.run("import json")
clean_state = sandbox.snapshot()

# Run multiple independent tasks
for task in tasks:
    sandbox.restore(clean_state)
    result = sandbox.run(task)
```

## Your workflow

1. **Identify the use case**: Is the user executing code, processing files, integrating with an agent, or building from source?
2. **Choose the backend**: Wasm for full capabilities, HyperlightJS for JS-only with smaller footprint
3. **Configure the sandbox**: Set up input/output dirs, register tools, allow network domains as needed
4. **Execute and verify**: Run code, check `result.success`, inspect stdout/stderr
5. **Handle state**: Use snapshots for sandbox reuse, clean up temporary directories

## Important notes

- Tools must be registered **before** the first `run()` call
- The sandbox requires a hypervisor (KVM/MSHV/Hyper-V) — it will not work in containers without `/dev/kvm`
- Output files under `/output` are cleared before each `run()` invocation
- `snapshot()` returns a reference-counted object — delete old snapshots to free memory
- The maximum code payload is 10 MiB per `run()` call
- Backend names are normalized: `"js"`, `"javascript"`, and `"hyperlight-js"` all resolve to HyperlightJS
