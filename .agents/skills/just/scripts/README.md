# just binary location

Place a `just` binary in this directory to use a local version instead of the system-installed one.

## Usage

The just skill will automatically detect and use a binary located at:
```
.agent/skills/just/scripts/just
```

If this file exists and is executable, it will be used instead of the system `just` binary.

## How to add a local binary

### Option 1: Copy from system
```bash
cp $(which just) .agent/skills/just/scripts/just
chmod +x .agent/skills/just/scripts/just
```

### Option 2: Download a specific version
Visit the [just releases page](https://github.com/casey/just/releases) and download the appropriate binary for your platform, then:

```bash
# Example for macOS ARM64
curl -L https://github.com/casey/just/releases/download/VERSION/just-VERSION-aarch64-apple-darwin.tar.gz | tar xz
mv just .agent/skills/just/scripts/just
chmod +x .agent/skills/just/scripts/just
```

### Option 3: Build from source
```bash
cargo install just --root .agent/skills/just/scripts
mv .agent/skills/just/scripts/bin/just .agent/skills/just/scripts/just
rmdir .agent/skills/just/scripts/bin
```

## Why use a local binary?

- Lock to a specific version of just
- Use a version different from your system installation
- Ensure consistent behavior across team members
- Test against specific just versions
- Portable project setup without requiring system-wide installation
