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

### Option 2: Download a specific version
Visit the [wasm-cli releases page](https://github.com/yoshuawuyts/wasm-cli/releases) and download the appropriate binary for your platform, then:

```bash
# Example for Linux x86_64
curl --proto '=https' --tlsv1.2 -LsSf https://github.com/yoshuawuyts/wasm-cli/releases/download/VERSION/wasm-cli-x86_64-unknown-linux-gnu.tar.gz | tar xz
mv wasm-cli .agent/skills/wasm-cli/scripts/wasm
chmod +x .agent/skills/wasm-cli/scripts/wasm
```

### Option 3: Install via installer script to custom location
```bash
curl --proto '=https' --tlsv1.2 -LsSf https://github.com/yoshuawuyts/wasm-cli/releases/latest/download/install.sh | sh
cp ~/.cargo/bin/wasm .agent/skills/wasm-cli/scripts/wasm
chmod +x .agent/skills/wasm-cli/scripts/wasm
```

### Option 4: Build from source
```bash
cargo install wasm --root .agent/skills/wasm-cli/scripts
mv .agent/skills/wasm-cli/scripts/bin/wasm .agent/skills/wasm-cli/scripts/wasm
rmdir .agent/skills/wasm-cli/scripts/bin
```

## Why use a local binary?

- Lock to a specific version of wasm-cli
- Use a version different from your system installation
- Ensure consistent behavior across team members
- Test against specific wasm-cli versions
- Portable project setup without requiring system-wide installation
