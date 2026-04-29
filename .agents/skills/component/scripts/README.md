# component binary location

Place a `component` binary in this directory to use a local version instead of the system-installed one.

## Usage

The component skill will automatically detect and use a binary located at:
```
.agents/skills/component/scripts/component
```

If this file exists and is executable, it will be used instead of the system `component` binary.

## How to add a local binary

### Option 1: Copy from system
```bash
cp $(which component) .agents/skills/component/scripts/component
chmod +x .agents/skills/component/scripts/component
```

### Option 2: Build from source (requires Rust toolchain)
```bash
cargo install --git https://github.com/yoshuawuyts/component-registry component
cp "$HOME/.cargo/bin/component" .agents/skills/component/scripts/component
```

**Note**: `cargo install component` (from crates.io) does NOT work — the `component` crate on crates.io is an unrelated package. You must install from the git repository.

## Why use a local binary?

- Lock to a specific version of the `component` CLI
- Use a version different from your system installation
- Ensure consistent behavior across team members
- Test against specific `component` CLI versions
- Portable project setup without requiring system-wide installation
