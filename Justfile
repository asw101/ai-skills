# Justfile for downloading binaries

# List available recipes
default:
    @just --list

# Install tools locally/globally for macOS using Homebrew (use 'just install-macos force' to reinstall)
install-macos force="":
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Installing tools for macOS using Homebrew..."

    FORCE="{{ force }}"

    # Check if brew is available
    if ! command -v brew &> /dev/null; then
        echo "❌ Homebrew not found. Please install Homebrew first: https://brew.sh"
        exit 1
    fi

    # Install just
    if [ "$FORCE" = "force" ] || ! command -v just &> /dev/null; then
        echo "Installing just..."
        brew install just || brew upgrade just
    else
        echo "✓ just already installed"
    fi

    # Install wasmtime
    if [ "$FORCE" = "force" ] || ! command -v wasmtime &> /dev/null; then
        echo "Installing wasmtime..."
        brew install wasmtime || brew upgrade wasmtime
    else
        echo "✓ wasmtime already installed"
    fi

    # Install wasm-tools
    if [ "$FORCE" = "force" ] || ! command -v wasm-tools &> /dev/null; then
        echo "Installing wasm-tools..."
        brew install wasm-tools || brew upgrade wasm-tools
    else
        echo "✓ wasm-tools already installed"
    fi

    # Install wkg
    # Note: wkg is not available via Homebrew, so we use a separate recipe
    if [ "$FORCE" = "force" ] || ! command -v wkg &> /dev/null; then
        echo "Installing wkg for macOS..."
        just get-wkg-macos
    else
        echo "✓ wkg already installed"
    fi

    echo ""
    echo "✓ Installation complete!"
    echo ""
    echo "Note: Skills will use globally installed binaries if local scripts/ binaries are not present."

# Download just binary for Linux x86_64
get-just:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Downloading just binary for Linux..."
    VERSION="1.40.0"
    URL="https://github.com/casey/just/releases/download/${VERSION}/just-${VERSION}-x86_64-unknown-linux-musl.tar.gz"
    curl -L "$URL" -o /tmp/just.tar.gz
    tar -xzf /tmp/just.tar.gz -C /tmp
    mkdir -p .claude/skills/just/scripts
    mv /tmp/just .claude/skills/just/scripts/just
    chmod +x .claude/skills/just/scripts/just
    rm /tmp/just.tar.gz
    echo "✓ just binary saved to .claude/skills/just/scripts/just"

# Download wasmtime binary for Linux x86_64
get-wasmtime:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Downloading wasmtime binary for Linux..."
    VERSION="v28.0.0"
    URL="https://github.com/bytecodealliance/wasmtime/releases/download/${VERSION}/wasmtime-${VERSION}-x86_64-linux.tar.xz"
    curl -L "$URL" -o /tmp/wasmtime.tar.xz
    tar -xJf /tmp/wasmtime.tar.xz -C /tmp
    mkdir -p .claude/skills/wasmtime/scripts
    mv /tmp/wasmtime-${VERSION}-x86_64-linux/wasmtime .claude/skills/wasmtime/scripts/wasmtime
    chmod +x .claude/skills/wasmtime/scripts/wasmtime
    rm -rf /tmp/wasmtime.tar.xz /tmp/wasmtime-${VERSION}-x86_64-linux
    echo "✓ wasmtime binary saved to .claude/skills/wasmtime/scripts/wasmtime"

# Guard recipe: ensure we're on macOS ARM64
_guard-macos-arm64:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "$(uname)" != "Darwin" ]; then
        echo "❌ Error: This recipe is only for macOS"
        exit 1
    fi
    if [ "$(uname -m)" != "arm64" ]; then
        echo "❌ Error: This recipe is only for Apple Silicon (arm64)"
        echo "   Current architecture: $(uname -m)"
        exit 1
    fi

# Download wkg binary for Linux x86_64 (for packaging skills)
get-wkg:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Downloading wkg binary for Linux..."
    VERSION="0.12.0"
    URL="https://github.com/bytecodealliance/wasm-pkg-tools/releases/download/v${VERSION}/wkg-x86_64-unknown-linux-gnu"
    mkdir -p .claude/skills/awesome-wasm/scripts
    curl -L "$URL" -o .claude/skills/awesome-wasm/scripts/wkg
    chmod +x .claude/skills/awesome-wasm/scripts/wkg
    echo "✓ wkg binary saved to .claude/skills/awesome-wasm/scripts/wkg"

# Download and install wkg binary for macOS ARM64
get-wkg-macos: _guard-macos-arm64
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Downloading wkg binary for macOS ARM64..."
    VERSION="0.12.0"
    URL="https://github.com/bytecodealliance/wasm-pkg-tools/releases/download/v${VERSION}/wkg-aarch64-apple-darwin"
    curl -L "$URL" -o /tmp/wkg
    chmod +x /tmp/wkg
    sudo mv /tmp/wkg /usr/local/bin/wkg
    echo "✓ wkg installed to /usr/local/bin/wkg"

    # Verify installation location
    WKG_PATH=$(which wkg)
    if [ "$WKG_PATH" = "/usr/local/bin/wkg" ]; then
        echo "✓ Verified: using wkg from /usr/local/bin/wkg"
    else
        echo "⚠️  Warning: 'which wkg' points to $WKG_PATH"
        echo "   Expected /usr/local/bin/wkg"
        echo "   You may need to adjust your PATH to prioritize /usr/local/bin"
    fi

# Download wasm-tools binary for Linux x86_64
get-wasm-tools:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Downloading wasm-tools binary for Linux..."
    VERSION="1.240.0"
    URL="https://github.com/bytecodealliance/wasm-tools/releases/download/v${VERSION}/wasm-tools-${VERSION}-x86_64-linux.tar.gz"
    curl -L "$URL" -o /tmp/wasm-tools.tar.gz
    tar -xzf /tmp/wasm-tools.tar.gz -C /tmp
    mkdir -p .claude/skills/awesome-wasm/scripts
    mv /tmp/wasm-tools-${VERSION}-x86_64-linux/wasm-tools .claude/skills/awesome-wasm/scripts/wasm-tools
    chmod +x .claude/skills/awesome-wasm/scripts/wasm-tools
    rm -rf /tmp/wasm-tools.tar.gz /tmp/wasm-tools-${VERSION}-x86_64-linux
    echo "✓ wasm-tools binary saved to .claude/skills/awesome-wasm/scripts/wasm-tools"

# Download all binaries
get-all: get-just get-wasmtime get-wkg get-wasm-tools

# Remove all downloaded binaries from skills scripts/ directories
clean-binaries:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Removing downloaded binaries from skills scripts/ directories..."

    # List of binary paths to remove
    BINARIES=(
        ".claude/skills/just/scripts/just"
        ".claude/skills/wasmtime/scripts/wasmtime"
        ".claude/skills/awesome-wasm/scripts/wkg"
        ".claude/skills/awesome-wasm/scripts/wasm-tools"
    )

    REMOVED=0
    for binary in "${BINARIES[@]}"; do
        if [ -f "$binary" ]; then
            echo "Removing $binary"
            rm "$binary"
            REMOVED=$((REMOVED + 1))
        fi
    done

    if [ $REMOVED -eq 0 ]; then
        echo "✓ No binaries found to remove"
    else
        echo "✓ Removed $REMOVED binary/binaries"
    fi
