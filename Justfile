# Justfile for downloading binaries

# Tool versions (update these when new versions are released)
just_version := "1.46.0"
wasmtime_version := "40.0.2"
wkg_version := "0.13.0"
wasm_tools_version := "1.244.0"

# List available recipes
default:
    @just --list

# Check latest versions of all tools (compare with current)
check-versions:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Checking latest versions..."
    echo ""

    echo "just:"
    echo "  Current: {{ just_version }}"
    LATEST=$(curl -s https://api.github.com/repos/casey/just/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    echo "  Latest:  $LATEST"
    echo ""

    echo "wasmtime:"
    echo "  Current: v{{ wasmtime_version }}"
    LATEST=$(curl -s https://api.github.com/repos/bytecodealliance/wasmtime/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    echo "  Latest:  $LATEST"
    echo ""

    echo "wkg:"
    echo "  Current: v{{ wkg_version }}"
    LATEST=$(curl -s https://api.github.com/repos/bytecodealliance/wasm-pkg-tools/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    echo "  Latest:  $LATEST"
    echo ""

    echo "wasm-tools:"
    echo "  Current: v{{ wasm_tools_version }}"
    LATEST=$(curl -s https://api.github.com/repos/bytecodealliance/wasm-tools/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    echo "  Latest:  $LATEST"
    echo ""

    echo "component-cli:"
    echo "  Upstream has no tagged releases; install tracks https://github.com/yoshuawuyts/component-cli main"
    echo ""

    echo "Update versions at the top of the Justfile if needed."

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
        echo ""
        echo "Intel Mac is not currently supported."
        echo "Consider using Docker or a Linux VM for development."
        exit 1
    fi

# Guard recipe: ensure we're on Linux x86_64
_guard-linux-x86_64:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "$(uname)" != "Linux" ]; then
        echo "❌ Error: This recipe is only for Linux"
        exit 1
    fi
    if [ "$(uname -m)" != "x86_64" ]; then
        echo "❌ Error: This recipe is only for x86_64"
        echo "   Current architecture: $(uname -m)"
        exit 1
    fi

# Install tools globally on macOS using Homebrew (use 'just install-macos force' to reinstall)
install-macos force="": _guard-macos-arm64
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Installing tools for macOS using Homebrew..."

    FORCE="{{ force }}"

    # Check if brew is available
    if ! command -v brew &> /dev/null; then
        echo "❌ Homebrew not found. Please install Homebrew first: https://brew.sh"
        exit 1
    fi

    BREW_PREFIX=$(brew --prefix)

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
    echo "Verifying installation paths..."

    # Verify tools are using Homebrew versions
    for tool in wasmtime wasm-tools just; do
        TOOL_PATH=$(which $tool)
        if [[ "$TOOL_PATH" == "$BREW_PREFIX"* ]]; then
            echo "✓ $tool: using Homebrew version at $TOOL_PATH"
        else
            echo "⚠️  $tool: using $TOOL_PATH (expected $BREW_PREFIX/bin/$tool)"
        fi
    done

    # Verify wkg location
    WKG_PATH=$(which wkg)
    if [ "$WKG_PATH" = "/usr/local/bin/wkg" ]; then
        echo "✓ wkg: installed at /usr/local/bin/wkg"
    else
        echo "⚠️  wkg: using $WKG_PATH (expected /usr/local/bin/wkg)"
    fi

    echo ""
    echo "Note: Skills will use globally installed binaries if local scripts/ binaries are not present."

# Install tools globally on Linux (use 'just install-linux force' to reinstall)
install-linux force="": _guard-linux-x86_64
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Installing tools globally for Linux x86_64..."

    FORCE="{{ force }}"
    INSTALL_DIR="/usr/local/bin"

    # Check for sudo if not root
    if [ "$EUID" -ne 0 ]; then
        SUDO="sudo"
        echo "Note: Will use sudo for installing to $INSTALL_DIR"
    else
        SUDO=""
    fi

    # Install just
    if [ "$FORCE" = "force" ] || ! command -v just &> /dev/null; then
        echo "Installing just {{ just_version }}..."
        curl -L "https://github.com/casey/just/releases/download/{{ just_version }}/just-{{ just_version }}-x86_64-unknown-linux-musl.tar.gz" -o /tmp/just.tar.gz
        tar -xzf /tmp/just.tar.gz -C /tmp
        $SUDO mv /tmp/just "$INSTALL_DIR/just"
        $SUDO chmod +x "$INSTALL_DIR/just"
        rm /tmp/just.tar.gz
        echo "✓ just installed to $INSTALL_DIR/just"
    else
        echo "✓ just already installed"
    fi

    # Install wasmtime
    if [ "$FORCE" = "force" ] || ! command -v wasmtime &> /dev/null; then
        echo "Installing wasmtime v{{ wasmtime_version }}..."
        curl -L "https://github.com/bytecodealliance/wasmtime/releases/download/v{{ wasmtime_version }}/wasmtime-v{{ wasmtime_version }}-x86_64-linux.tar.xz" -o /tmp/wasmtime.tar.xz
        tar -xJf /tmp/wasmtime.tar.xz -C /tmp
        $SUDO mv /tmp/wasmtime-v{{ wasmtime_version }}-x86_64-linux/wasmtime "$INSTALL_DIR/wasmtime"
        $SUDO chmod +x "$INSTALL_DIR/wasmtime"
        rm -rf /tmp/wasmtime.tar.xz /tmp/wasmtime-v{{ wasmtime_version }}-x86_64-linux
        echo "✓ wasmtime installed to $INSTALL_DIR/wasmtime"
    else
        echo "✓ wasmtime already installed"
    fi

    # Install wasm-tools
    if [ "$FORCE" = "force" ] || ! command -v wasm-tools &> /dev/null; then
        echo "Installing wasm-tools v{{ wasm_tools_version }}..."
        curl -L "https://github.com/bytecodealliance/wasm-tools/releases/download/v{{ wasm_tools_version }}/wasm-tools-{{ wasm_tools_version }}-x86_64-linux.tar.gz" -o /tmp/wasm-tools.tar.gz
        tar -xzf /tmp/wasm-tools.tar.gz -C /tmp
        $SUDO mv /tmp/wasm-tools-{{ wasm_tools_version }}-x86_64-linux/wasm-tools "$INSTALL_DIR/wasm-tools"
        $SUDO chmod +x "$INSTALL_DIR/wasm-tools"
        rm -rf /tmp/wasm-tools.tar.gz /tmp/wasm-tools-{{ wasm_tools_version }}-x86_64-linux
        echo "✓ wasm-tools installed to $INSTALL_DIR/wasm-tools"
    else
        echo "✓ wasm-tools already installed"
    fi

    # Install wkg
    if [ "$FORCE" = "force" ] || ! command -v wkg &> /dev/null; then
        echo "Installing wkg v{{ wkg_version }}..."
        curl -L "https://github.com/bytecodealliance/wasm-pkg-tools/releases/download/v{{ wkg_version }}/wkg-x86_64-unknown-linux-gnu" -o /tmp/wkg
        $SUDO mv /tmp/wkg "$INSTALL_DIR/wkg"
        $SUDO chmod +x "$INSTALL_DIR/wkg"
        echo "✓ wkg installed to $INSTALL_DIR/wkg"
    else
        echo "✓ wkg already installed"
    fi

    echo ""
    echo "✓ Installation complete!"
    echo ""
    echo "Installed versions:"
    just --version || true
    wasmtime --version || true
    wasm-tools --version || true
    wkg --version || true

# Download just binary for Linux x86_64 (to skill scripts/)
get-just:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Downloading just {{ just_version }} binary for Linux..."
    URL="https://github.com/casey/just/releases/download/{{ just_version }}/just-{{ just_version }}-x86_64-unknown-linux-musl.tar.gz"
    curl -L "$URL" -o /tmp/just.tar.gz
    tar -xzf /tmp/just.tar.gz -C /tmp
    mkdir -p .agents/skills/just/scripts
    mv /tmp/just .agents/skills/just/scripts/just
    chmod +x .agents/skills/just/scripts/just
    rm /tmp/just.tar.gz
    echo "✓ just binary saved to .agents/skills/just/scripts/just"

# Download wasmtime binary for Linux x86_64 (to skill scripts/)
get-wasmtime:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Downloading wasmtime v{{ wasmtime_version }} binary for Linux..."
    URL="https://github.com/bytecodealliance/wasmtime/releases/download/v{{ wasmtime_version }}/wasmtime-v{{ wasmtime_version }}-x86_64-linux.tar.xz"
    curl -L "$URL" -o /tmp/wasmtime.tar.xz
    tar -xJf /tmp/wasmtime.tar.xz -C /tmp
    mkdir -p .agents/skills/wasm-run/scripts
    mv /tmp/wasmtime-v{{ wasmtime_version }}-x86_64-linux/wasmtime .agents/skills/wasm-run/scripts/wasmtime
    chmod +x .agents/skills/wasm-run/scripts/wasmtime
    rm -rf /tmp/wasmtime.tar.xz /tmp/wasmtime-v{{ wasmtime_version }}-x86_64-linux
    echo "✓ wasmtime binary saved to .agents/skills/wasm-run/scripts/wasmtime"

# Download and install wkg binary for macOS ARM64
get-wkg-macos: _guard-macos-arm64
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Downloading wkg v{{ wkg_version }} binary for macOS ARM64..."
    URL="https://github.com/bytecodealliance/wasm-pkg-tools/releases/download/v{{ wkg_version }}/wkg-aarch64-apple-darwin"
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

# Download wkg binary for Linux x86_64 (to skill scripts/)
get-wkg:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Downloading wkg v{{ wkg_version }} binary for Linux..."
    URL="https://github.com/bytecodealliance/wasm-pkg-tools/releases/download/v{{ wkg_version }}/wkg-x86_64-unknown-linux-gnu"
    mkdir -p .agents/skills/wasm-search/scripts
    curl -L "$URL" -o .agents/skills/wasm-search/scripts/wkg
    chmod +x .agents/skills/wasm-search/scripts/wkg
    echo "✓ wkg binary saved to .agents/skills/wasm-search/scripts/wkg"

# Download wasm-tools binary for Linux x86_64 (to skill scripts/)
get-wasm-tools:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Downloading wasm-tools v{{ wasm_tools_version }} binary for Linux..."
    URL="https://github.com/bytecodealliance/wasm-tools/releases/download/v{{ wasm_tools_version }}/wasm-tools-{{ wasm_tools_version }}-x86_64-linux.tar.gz"
    curl -L "$URL" -o /tmp/wasm-tools.tar.gz
    tar -xzf /tmp/wasm-tools.tar.gz -C /tmp
    mkdir -p .agents/skills/wasm-search/scripts
    mv /tmp/wasm-tools-{{ wasm_tools_version }}-x86_64-linux/wasm-tools .agents/skills/wasm-search/scripts/wasm-tools
    chmod +x .agents/skills/wasm-search/scripts/wasm-tools
    rm -rf /tmp/wasm-tools.tar.gz /tmp/wasm-tools-{{ wasm_tools_version }}-x86_64-linux
    echo "✓ wasm-tools binary saved to .agents/skills/wasm-search/scripts/wasm-tools"

# Build component-cli from yosh's upstream and copy to skill scripts/ (requires Rust toolchain)
get-component-cli:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Building component-cli from https://github.com/yoshuawuyts/component-cli (requires Rust toolchain)..."
    cargo install --git https://github.com/yoshuawuyts/component-cli component
    mkdir -p .agents/skills/component-cli/scripts
    cp "$HOME/.cargo/bin/component" .agents/skills/component-cli/scripts/component
    chmod +x .agents/skills/component-cli/scripts/component
    echo "✓ component-cli built from source and saved to .agents/skills/component-cli/scripts/component"

# Download all Linux binaries (to skill scripts/)
get-all: get-just get-wasmtime get-wkg get-wasm-tools get-component-cli

# Remove all downloaded binaries from skills scripts/ directories
clean-binaries:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Removing downloaded binaries from skills scripts/ directories..."

    # List of binary paths to remove
    BINARIES=(
        ".agents/skills/just/scripts/just"
        ".agents/skills/wasm-run/scripts/wasmtime"
        ".agents/skills/wasm-search/scripts/wkg"
        ".agents/skills/wasm-search/scripts/wasm-tools"
        ".agents/skills/component-cli/scripts/component"
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
