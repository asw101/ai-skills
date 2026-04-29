# wasm binary location

Place a `wasm` binary in this directory to use a local version instead of the system-installed one.

## Usage

The component-cli skill will automatically detect and use a binary located at:
```
.agents/skills/component-cli/scripts/wasm
```

If this file exists and is executable, it will be used instead of the system `wasm` binary.

## How to add a local binary

### Option 1: Copy from system
```bash
cp $(which wasm) .agents/skills/component-cli/scripts/wasm
chmod +x .agents/skills/component-cli/scripts/wasm
```

### Option 2: Download a pre-built release
Visit the [component-cli releases page](https://github.com/asw101/component-cli/releases) and download the appropriate binary for your platform, then:

```bash
# Example for Linux x86_64
curl -fL "https://github.com/asw101/component-cli/releases/download/v0.3.0/component-cli-x86_64-unknown-linux-gnu.tar.gz" -o /tmp/component-cli.tar.gz
tar -xzf /tmp/component-cli.tar.gz -C /tmp
mv /tmp/component-cli .agents/skills/component-cli/scripts/wasm
chmod +x .agents/skills/component-cli/scripts/wasm
```

### Option 3: Build from source (requires Rust toolchain)
```bash
cargo install --git https://github.com/asw101/component-cli wasm
cp "$HOME/.cargo/bin/wasm" .agents/skills/component-cli/scripts/wasm
```

**Note**: `cargo install wasm` (from crates.io) does NOT work — the `wasm` crate on crates.io is a different, empty library. You must install from the git repository.

## Why use a local binary?

- Lock to a specific version of component-cli
- Use a version different from your system installation
- Ensure consistent behavior across team members
- Test against specific component-cli versions
- Portable project setup without requiring system-wide installation
