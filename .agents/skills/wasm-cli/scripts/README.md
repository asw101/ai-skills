# wasm binary location

Place a `wasm` binary in this directory to use a local version instead of the system-installed one.

## Usage

The wasm-cli skill will automatically detect and use a binary located at:
```
.agent/skills/wasm-cli/scripts/wasm
```

If this file exists and is executable, it will be used instead of the system `wasm` binary.

## How to add a local binary

### Option 1: Copy from system
```bash
cp $(which wasm) .agent/skills/wasm-cli/scripts/wasm
chmod +x .agent/skills/wasm-cli/scripts/wasm
```

### Option 2: Download a pre-built release
Visit the [wasm-cli releases page](https://github.com/asw101/wasm-cli/releases) and download the appropriate binary for your platform, then:

```bash
# Example for Linux x86_64
curl -fL "https://github.com/asw101/wasm-cli/releases/download/v0.3.0/wasm-cli-x86_64-unknown-linux-gnu.tar.gz" -o /tmp/wasm-cli.tar.gz
tar -xzf /tmp/wasm-cli.tar.gz -C /tmp
mv /tmp/wasm-cli .agent/skills/wasm-cli/scripts/wasm
chmod +x .agent/skills/wasm-cli/scripts/wasm
```

### Option 3: Build from source (requires Rust toolchain)
```bash
cargo install --git https://github.com/asw101/wasm-cli wasm
cp "$HOME/.cargo/bin/wasm" .agent/skills/wasm-cli/scripts/wasm
```

**Note**: `cargo install wasm` (from crates.io) does NOT work — the `wasm` crate on crates.io is a different, empty library. You must install from the git repository.

## Why use a local binary?

- Lock to a specific version of wasm-cli
- Use a version different from your system installation
- Ensure consistent behavior across team members
- Test against specific wasm-cli versions
- Portable project setup without requiring system-wide installation
