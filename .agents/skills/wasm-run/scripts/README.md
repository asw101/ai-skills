# wasmtime binary location

Place a `wasmtime` binary in this directory to use a local version instead of the system-installed one.

## Usage

The wasmtime skill will automatically detect and use a binary located at:
```
.agents/skills/wasm-run/scripts/wasmtime
```

If this file exists and is executable, it will be used instead of the system `wasmtime` binary.

## How to add a local binary

### Option 1: Copy from system
```bash
cp $(which wasmtime) .agents/skills/wasm-run/scripts/wasmtime
chmod +x .agents/skills/wasm-run/scripts/wasmtime
```

### Option 2: Download a specific version
Visit the [wasmtime releases page](https://github.com/bytecodealliance/wasmtime/releases) and download the appropriate binary for your platform, then:

```bash
# Example for macOS ARM64
curl -L https://github.com/bytecodealliance/wasmtime/releases/download/vVERSION/wasmtime-vVERSION-aarch64-macos.tar.xz | tar xJ
mv wasmtime-vVERSION-aarch64-macos/wasmtime .agents/skills/wasm-run/scripts/wasmtime
chmod +x .agents/skills/wasm-run/scripts/wasmtime
rm -rf wasmtime-vVERSION-aarch64-macos
```

### Option 3: Install via wasmtime installer to custom location
```bash
curl https://wasmtime.dev/install.sh -sSf | bash -s -- --no-modify-path
cp ~/.wasmtime/bin/wasmtime .agents/skills/wasm-run/scripts/wasmtime
chmod +x .agents/skills/wasm-run/scripts/wasmtime
```

### Option 4: Build from source
```bash
cargo install wasmtime-cli --root .agents/skills/wasm-run/scripts
mv .agents/skills/wasm-run/scripts/bin/wasmtime .agents/skills/wasm-run/scripts/wasmtime
rmdir .agents/skills/wasm-run/scripts/bin
```

## Why use a local binary?

- Lock to a specific version of wasmtime
- Use a version different from your system installation
- Ensure consistent behavior across team members
- Test against specific wasmtime versions (important for WASI 0.2 vs 0.3 compatibility)
- Portable project setup without requiring system-wide installation
- Test components against different runtime versions

## Version considerations

Different wasmtime versions support different WASI versions:
- **WASI 0.2**: Supported in recent stable versions
- **WASI 0.3**: In-progress, requires newer builds
- Component Model features may vary between versions

Using a local binary ensures your project uses a compatible runtime version.
