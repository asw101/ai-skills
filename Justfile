# Justfile — WebAssembly component build toolchain
#
# Quick start:
#   just install              # Install core CLI tools to /usr/local/bin (auto-detects OS)
#   just install-all          # Core + all language toolchains
#   just populate-skills      # Place tool binaries under .agents/skills/<skill>/scripts/
#   just check-versions       # Compare pinned versions with latest upstream
#
# Per-tool installers are cross-platform. Each accepts an optional `dest`:
#   just install-wasmtime                              # → /usr/local/bin/wasmtime
#   just install-wasmtime .agents/skills/wasmtime/scripts   # → skill-local
#
# Language toolchains:
#   just install-rust-tools | install-py-tools | install-js-tools
#   just install-go-tools   | install-tinygo

# === Versions (single source of truth) ===
# Core CLI tools
just_version             := "1.50.0"
wasmtime_version         := "44.0.0"  # 43+ required for WASIp3 (0.3.0-rc-2026-03-15)
wkg_version              := "0.15.0"
wasm_tools_version       := "1.248.0"
component_version    := "latest"   # always fetch latest from yoshuawuyts/component-registry
wac_version              := "0.10.0"

# Language toolchains
wit_bindgen_version      := "0.57.1"  # macro & CLI; supports stream<>/future<>/async fn
componentize_py_version  := "0.23.0"  # ships cli-p3 / http-p3 / tcp-p3 examples
jco_version              := "1.19.0"
componentize_js_version  := "0.20.0"
tinygo_version           := "0.41.1"
wit_bindgen_go_version   := "0.7.0"

# === Default ===

# List available recipes
default:
    @just --list

# === Aggregates ===

# Install core CLI tools (just, wasmtime, wasm-tools, wkg) to /usr/local/bin
install: install-just install-wasmtime install-wasm-tools install-wkg
    @echo ""
    @echo "✓ Core toolchain installed."

# Install everything: core CLI + all language toolchains
install-all: install install-rust-tools install-py-tools install-js-tools install-go-tools install-tinygo
    @echo ""
    @echo "✓ Full component build toolchain installed."

# Populate skill-local binaries under .agents/skills/<skill>/scripts/
populate-skills: \
    (install-just ".agents/skills/just/scripts") \
    (install-wasmtime ".agents/skills/wasmtime/scripts") \
    (install-wasm-tools ".agents/skills/wasm-toolchain/scripts") \
    (install-wkg ".agents/skills/wasm-toolchain/scripts") \
    (install-component ".agents/skills/component/scripts")
    @echo ""
    @echo "✓ Skill-local binaries populated."

# Remove all skill-local binaries
clean-skills:
    #!/usr/bin/env bash
    set -euo pipefail
    BINARIES=(
        ".agents/skills/just/scripts/just"
        ".agents/skills/wasmtime/scripts/wasmtime"
        ".agents/skills/wasm-toolchain/scripts/wkg"
        ".agents/skills/wasm-toolchain/scripts/wasm-tools"
        ".agents/skills/component/scripts/component"
    )
    REMOVED=0
    for b in "${BINARIES[@]}"; do
        [ -f "$b" ] && { echo "Removing $b"; rm "$b"; REMOVED=$((REMOVED + 1)); }
    done
    [ $REMOVED -eq 0 ] && echo "✓ No binaries to remove" || echo "✓ Removed $REMOVED binary/binaries"

# === Diagnostics ===

# Compare pinned versions with latest upstream
check-versions:
    #!/usr/bin/env bash
    set -euo pipefail
    gh()   { curl -fsSL "https://api.github.com/repos/$1/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/'; }
    pypi() { curl -fsSL "https://pypi.org/pypi/$1/json"        | python3 -c "import sys,json;print(json.load(sys.stdin)['info']['version'])"; }
    npm()  { curl -fsSL "https://registry.npmjs.org/$1/latest" | python3 -c "import sys,json;print(json.load(sys.stdin)['version'])"; }
    row()  { printf "  %-22s pinned=%-12s latest=%s\n" "$1" "$2" "$3"; }

    echo "Core CLI tools:"
    row "just"            "{{ just_version }}"            "$(gh casey/just)"
    row "wasmtime"        "{{ wasmtime_version }}"        "$(gh bytecodealliance/wasmtime)"
    row "wasm-tools"      "{{ wasm_tools_version }}"      "$(gh bytecodealliance/wasm-tools)"
    row "wkg"             "{{ wkg_version }}"             "$(gh bytecodealliance/wasm-pkg-tools)"
    row "wac"             "{{ wac_version }}"             "$(gh bytecodealliance/wac)"
    row "component"       "{{ component_version }}"        "$(gh yoshuawuyts/component-registry)"

    echo
    echo "Language toolchains:"
    row "wit-bindgen"     "{{ wit_bindgen_version }}"     "$(gh bytecodealliance/wit-bindgen)"
    row "componentize-py" "{{ componentize_py_version }}" "$(pypi componentize-py)"
    row "jco"             "{{ jco_version }}"             "$(npm @bytecodealliance/jco)"
    row "componentize-js" "{{ componentize_js_version }}" "$(npm @bytecodealliance/componentize-js)"
    row "tinygo"          "{{ tinygo_version }}"          "$(gh tinygo-org/tinygo)"
    row "wit-bindgen-go"  "{{ wit_bindgen_go_version }}"  "$(gh bytecodealliance/go-modules)"

    echo
    echo "Update versions at the top of the Justfile if any are stale."

# === Per-tool CLI installers ===
#
# Each `install-<tool>` recipe:
#   * Detects OS/arch and downloads the matching artifact.
#   * Defaults dest to /usr/local/bin (system-wide install).
#   * Writes to a custom dest (e.g. skill-local) when the dest argument is supplied.
#   * On macOS, prefers Homebrew for system-wide installs where a formula exists.
#   * Skips if the tool is already on PATH for system installs (use `force=1` env to override).

install-just dest="/usr/local/bin":
    #!/usr/bin/env bash
    set -euo pipefail
    DEST="{{ dest }}"
    SYS_INSTALL=$([ "$DEST" = "/usr/local/bin" ] && echo 1 || echo 0)
    if [ "$SYS_INSTALL" = "1" ] && command -v just &>/dev/null && [ -z "${force:-}" ]; then
        echo "✓ just $(just --version) already on PATH ($(command -v just))"; exit 0
    fi
    if [ "$SYS_INSTALL" = "1" ] && [ "{{ os() }}" = "macos" ] && command -v brew &>/dev/null; then
        echo "Installing just via Homebrew..."
        brew list just &>/dev/null && brew upgrade just || brew install just
        exit 0
    fi
    case "{{ os() }}-{{ arch() }}" in
        linux-x86_64)  target="x86_64-unknown-linux-musl" ;;
        linux-aarch64) target="aarch64-unknown-linux-musl" ;;
        macos-x86_64)  target="x86_64-apple-darwin" ;;
        macos-aarch64) target="aarch64-apple-darwin" ;;
        *) echo "❌ Unsupported: {{ os() }}-{{ arch() }}"; exit 1 ;;
    esac
    URL="https://github.com/casey/just/releases/download/{{ just_version }}/just-{{ just_version }}-${target}.tar.gz"
    just _dl-tarball "$URL" "just" "$DEST" "just"

install-wasmtime dest="/usr/local/bin":
    #!/usr/bin/env bash
    set -euo pipefail
    DEST="{{ dest }}"
    SYS_INSTALL=$([ "$DEST" = "/usr/local/bin" ] && echo 1 || echo 0)
    if [ "$SYS_INSTALL" = "1" ] && command -v wasmtime &>/dev/null && [ -z "${force:-}" ]; then
        echo "✓ wasmtime $(wasmtime --version) already on PATH ($(command -v wasmtime))"; exit 0
    fi
    if [ "$SYS_INSTALL" = "1" ] && [ "{{ os() }}" = "macos" ] && command -v brew &>/dev/null; then
        echo "Installing wasmtime via Homebrew..."
        brew list wasmtime &>/dev/null && brew upgrade wasmtime || brew install wasmtime
        exit 0
    fi
    case "{{ os() }}-{{ arch() }}" in
        linux-x86_64)  triple="x86_64-linux"   ext="tar.xz" ;;
        linux-aarch64) triple="aarch64-linux"  ext="tar.xz" ;;
        macos-x86_64)  triple="x86_64-macos"   ext="tar.xz" ;;
        macos-aarch64) triple="aarch64-macos"  ext="tar.xz" ;;
        *) echo "❌ Unsupported: {{ os() }}-{{ arch() }}"; exit 1 ;;
    esac
    base="wasmtime-v{{ wasmtime_version }}-${triple}"
    URL="https://github.com/bytecodealliance/wasmtime/releases/download/v{{ wasmtime_version }}/${base}.${ext}"
    just _dl-tarball "$URL" "wasmtime" "$DEST" "${base}/wasmtime"

install-wasm-tools dest="/usr/local/bin":
    #!/usr/bin/env bash
    set -euo pipefail
    DEST="{{ dest }}"
    SYS_INSTALL=$([ "$DEST" = "/usr/local/bin" ] && echo 1 || echo 0)
    if [ "$SYS_INSTALL" = "1" ] && command -v wasm-tools &>/dev/null && [ -z "${force:-}" ]; then
        echo "✓ wasm-tools $(wasm-tools --version) already on PATH"; exit 0
    fi
    if [ "$SYS_INSTALL" = "1" ] && [ "{{ os() }}" = "macos" ] && command -v brew &>/dev/null; then
        echo "Installing wasm-tools via Homebrew..."
        brew list wasm-tools &>/dev/null && brew upgrade wasm-tools || brew install wasm-tools
        exit 0
    fi
    case "{{ os() }}-{{ arch() }}" in
        linux-x86_64)  triple="x86_64-linux" ;;
        linux-aarch64) triple="aarch64-linux" ;;
        macos-x86_64)  triple="x86_64-macos" ;;
        macos-aarch64) triple="aarch64-macos" ;;
        *) echo "❌ Unsupported: {{ os() }}-{{ arch() }}"; exit 1 ;;
    esac
    base="wasm-tools-{{ wasm_tools_version }}-${triple}"
    URL="https://github.com/bytecodealliance/wasm-tools/releases/download/v{{ wasm_tools_version }}/${base}.tar.gz"
    just _dl-tarball "$URL" "wasm-tools" "$DEST" "${base}/wasm-tools"

install-wkg dest="/usr/local/bin":
    #!/usr/bin/env bash
    set -euo pipefail
    DEST="{{ dest }}"
    SYS_INSTALL=$([ "$DEST" = "/usr/local/bin" ] && echo 1 || echo 0)
    if [ "$SYS_INSTALL" = "1" ] && command -v wkg &>/dev/null && [ -z "${force:-}" ]; then
        echo "✓ wkg $(wkg --version 2>/dev/null || echo installed) already on PATH"; exit 0
    fi
    case "{{ os() }}-{{ arch() }}" in
        linux-x86_64)  asset="wkg-x86_64-unknown-linux-gnu" ;;
        linux-aarch64) asset="wkg-aarch64-unknown-linux-gnu" ;;
        macos-x86_64)  asset="wkg-x86_64-apple-darwin" ;;
        macos-aarch64) asset="wkg-aarch64-apple-darwin" ;;
        *) echo "❌ Unsupported: {{ os() }}-{{ arch() }}"; exit 1 ;;
    esac
    URL="https://github.com/bytecodealliance/wasm-pkg-tools/releases/download/v{{ wkg_version }}/${asset}"
    just _dl-raw "$URL" "wkg" "$DEST"

install-component dest="/usr/local/bin":
    #!/usr/bin/env bash
    set -euo pipefail
    DEST="{{ dest }}"
    SYS_INSTALL=$([ "$DEST" = "/usr/local/bin" ] && echo 1 || echo 0)
    if [ "$SYS_INSTALL" = "1" ] && command -v component &>/dev/null && [ -z "${force:-}" ]; then
        echo "✓ component $(component --version 2>/dev/null || echo installed) already on PATH"; exit 0
    fi
    # Prefer cargo (works on all platforms); fall back to pre-built tarball
    if command -v cargo &>/dev/null; then
        echo "Building component from source..."
        cargo install --git https://github.com/yoshuawuyts/component-registry component
        mkdir -p "$DEST"
        cp "$HOME/.cargo/bin/component" "$DEST/component"
        chmod +x "$DEST/component"
        echo "✓ component installed to $DEST/component"
        exit 0
    fi
    echo "cargo not found; trying pre-built release..."
    case "{{ os() }}-{{ arch() }}" in
        linux-x86_64)  asset="component-x86_64-unknown-linux-gnu.tar.gz" ;;
        macos-x86_64)  asset="component-x86_64-apple-darwin.tar.gz" ;;
        macos-aarch64) asset="component-aarch64-apple-darwin.tar.gz" ;;
        *)
            echo "❌ No pre-built binary for {{ os() }}-{{ arch() }} and cargo not found."
            echo "   Install Rust (https://rustup.rs), then: cargo install --git https://github.com/yoshuawuyts/component-registry component"
            exit 1
            ;;
    esac
    URL="https://github.com/yoshuawuyts/component-registry/releases/latest/download/${asset}"
    just _dl-tarball "$URL" "component" "$DEST" "component"

# === Base toolchain bootstrap ===
#
# Install the underlying language toolchains (rustup, Node, Go, uv) so that the
# language-specific install-X recipes below can do their work. These are
# idempotent — they no-op if a working version is already on PATH.
#
# Network and write-permission requirements:
#   - bootstrap-rust   downloads from https://sh.rustup.rs to ~/.cargo (no sudo)
#   - bootstrap-node   uses NodeSource on Linux (sudo apt) or Homebrew on macOS
#   - bootstrap-go     downloads go.dev tarball to /usr/local/go (sudo on Linux)
#   - bootstrap-uv     downloads from https://astral.sh/uv to ~/.local/bin (no sudo)

# Pinned versions for bootstrap installers
node_major_version  := "22"      # Node 22 LTS; jco 1.19+ requires Node 20+
go_version          := "1.23.4"  # Go 1.23+ keeps wit-bindgen-go's go.mod happy

# Install all base toolchains needed by install-rust-tools / install-py-tools /
# install-js-tools / install-go-tools.
bootstrap-all: bootstrap-rust bootstrap-uv bootstrap-node bootstrap-go
    @echo ""
    @echo "✓ Base toolchains bootstrapped. Next: 'just install-all' to add the"
    @echo "  language-specific component build tools."

# Install rustup + the stable Rust toolchain (minimal profile) into ~/.cargo
bootstrap-rust:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v rustup &>/dev/null || [ -x "$HOME/.cargo/bin/rustup" ]; then
        rustup_bin=$(command -v rustup || echo "$HOME/.cargo/bin/rustup")
        echo "✓ rustup already installed at $rustup_bin"
        if ! command -v rustup &>/dev/null; then
            echo "  Not on PATH — add for current shell:  . \$HOME/.cargo/env"
        fi
        exit 0
    fi
    echo "Installing rustup (stable toolchain, minimal profile) to \$HOME/.cargo..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- \
        -y --profile minimal --default-toolchain stable --no-modify-path
    echo ""
    echo "✓ rustup installed. Add to PATH for current shell:"
    echo "    . \$HOME/.cargo/env"

# Install uv (fast Python package manager) to ~/.local/bin
bootstrap-uv:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v uv &>/dev/null || [ -x "$HOME/.local/bin/uv" ]; then
        uv_bin=$(command -v uv || echo "$HOME/.local/bin/uv")
        echo "✓ uv already installed at $uv_bin"
        if ! command -v uv &>/dev/null; then
            echo "  Not on PATH — add for current shell:  export PATH=\"\$HOME/.local/bin:\$PATH\""
        fi
        exit 0
    fi
    echo "Installing uv to \$HOME/.local/bin..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    echo ""
    echo "✓ uv installed. Add to PATH for current shell:"
    echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""

# Install Node {{ node_major_version }} via NodeSource (Linux) or Homebrew (macOS)
bootstrap-node:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v node &>/dev/null; then
        current=$(node --version | sed 's/v//' | cut -d. -f1)
        if [ "$current" -ge "{{ node_major_version }}" ]; then
            echo "✓ Node v$(node --version | sed 's/v//') already installed (>= v{{ node_major_version }})"
            exit 0
        fi
        echo "⚠ Node v$(node --version | sed 's/v//') found but jco requires Node {{ node_major_version }}+"
    fi
    case "{{ os() }}" in
        linux)
            echo "Installing Node {{ node_major_version }}.x via NodeSource..."
            SUDO=""; [ "$EUID" -ne 0 ] && SUDO="sudo"
            curl -fsSL "https://deb.nodesource.com/setup_{{ node_major_version }}.x" | $SUDO -E bash -
            $SUDO apt-get install -y nodejs
            ;;
        macos)
            if ! command -v brew &>/dev/null; then
                echo "❌ Homebrew not found. Install from https://brew.sh, then re-run."; exit 1
            fi
            echo "Installing node@{{ node_major_version }} via Homebrew..."
            brew install "node@{{ node_major_version }}"
            brew link --overwrite --force "node@{{ node_major_version }}"
            ;;
        *) echo "❌ Unsupported OS: {{ os() }}. Install Node {{ node_major_version }}+ from https://nodejs.org"; exit 1 ;;
    esac
    echo ""
    echo "✓ Node $(node --version) and npm $(npm --version) installed"

# Install Go {{ go_version }} from the upstream tarball (Linux) or Homebrew (macOS)
bootstrap-go:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v go &>/dev/null; then
        current=$(go version | awk '{print $3}' | sed 's/go//')
        major=$(echo "$current" | cut -d. -f1)
        minor=$(echo "$current" | cut -d. -f2)
        target_minor=$(echo "{{ go_version }}" | cut -d. -f2)
        if [ "$major" -ge 1 ] && [ "$minor" -ge "$target_minor" ]; then
            echo "✓ Go $current already installed (>= {{ go_version }})"
            exit 0
        fi
        echo "⚠ Go $current found but {{ go_version }}+ recommended for wit-bindgen-go"
    fi
    case "{{ os() }}-{{ arch() }}" in
        linux-x86_64)  pkg="go{{ go_version }}.linux-amd64.tar.gz" ;;
        linux-aarch64) pkg="go{{ go_version }}.linux-arm64.tar.gz" ;;
        macos-x86_64|macos-aarch64)
            if ! command -v brew &>/dev/null; then
                echo "❌ Homebrew not found. Install from https://brew.sh, then re-run."; exit 1
            fi
            echo "Installing go via Homebrew..."
            brew install go
            echo "✓ Go $(go version | awk '{print $3}') installed"
            exit 0 ;;
        *) echo "❌ Unsupported: {{ os() }}-{{ arch() }}"; exit 1 ;;
    esac
    URL="https://go.dev/dl/${pkg}"
    PREFIX="/usr/local"
    SUDO=""; [ "$EUID" -ne 0 ] && SUDO="sudo"
    echo "Downloading Go {{ go_version }} from $URL..."
    rm -rf /tmp/go-dl && mkdir -p /tmp/go-dl
    curl -fL "$URL" -o /tmp/go-dl/dl.tar.gz
    $SUDO rm -rf "$PREFIX/go"
    $SUDO tar -xzf /tmp/go-dl/dl.tar.gz -C "$PREFIX"
    $SUDO ln -sf "$PREFIX/go/bin/go" "$PREFIX/bin/go"
    $SUDO ln -sf "$PREFIX/go/bin/gofmt" "$PREFIX/bin/gofmt"
    rm -rf /tmp/go-dl
    echo ""
    echo "✓ Go installed → $PREFIX/go (symlinked at $PREFIX/bin/go)"
    go version

# === Language toolchain installers ===

# Rust component-build tooling: rustup targets + wit-bindgen CLI + wasm-tools
install-rust-tools:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v rustup &>/dev/null; then
        echo "❌ rustup not found. Run 'just bootstrap-rust' (or install from https://rustup.rs)"; exit 1
    fi
    echo "Adding wasm32-wasip1 and wasm32-wasip2 targets..."
    rustup target add wasm32-wasip1 wasm32-wasip2

    echo "Installing wasm-tools {{ wasm_tools_version }}..."
    cargo install --locked "wasm-tools@{{ wasm_tools_version }}"

    echo "Installing wit-bindgen-cli {{ wit_bindgen_version }}..."
    cargo install --locked "wit-bindgen-cli@{{ wit_bindgen_version }}"

    echo ""
    echo "✓ Rust component tooling installed."
    echo "  WASI 0.2 → cargo build --release --target wasm32-wasip2"
    echo "  WASI 0.3 RC → cargo build --release --target wasm32-wasip1 + 'wasm-tools component new --adapt ...'"
    echo "  Each component pins its own 'wit-bindgen' version in Cargo.toml."

# Python component-build tooling: componentize-py via pip / pip3 / uv
install-py-tools:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v uv &>/dev/null; then
        echo "Installing componentize-py {{ componentize_py_version }} via uv..."
        uv tool install --force "componentize-py=={{ componentize_py_version }}"
    elif command -v pip3 &>/dev/null; then
        echo "Installing componentize-py {{ componentize_py_version }} via pip3..."
        pip3 install --upgrade "componentize-py=={{ componentize_py_version }}"
    elif command -v pip &>/dev/null; then
        echo "Installing componentize-py {{ componentize_py_version }} via pip..."
        pip install --upgrade "componentize-py=={{ componentize_py_version }}"
    else
        echo "❌ No Python package manager found (pip / pip3 / uv)."
        echo "   Install Python 3.10+ from https://www.python.org/downloads/"
        exit 1
    fi
    echo ""
    echo "✓ Python component tooling installed."
    echo "  Build: componentize-py -d <wit-path> -w <world> componentize <module> -o out.wasm"
    echo "  WASI 0.3 RC examples: https://github.com/bytecodealliance/componentize-py/tree/main/examples"

# JavaScript component-build tooling: jco + componentize-js (npm global)
install-js-tools:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v npm &>/dev/null; then
        echo "❌ npm not found. Run 'just bootstrap-node' (or install Node {{ node_major_version }}+ from https://nodejs.org)"; exit 1
    fi
    node_major=$(node --version | sed 's/v//' | cut -d. -f1)
    if [ "$node_major" -lt 20 ]; then
        echo "❌ Node v$(node --version | sed 's/v//') found but jco {{ jco_version }} requires Node 20+ (will install but fail at runtime with ERR_MODULE_NOT_FOUND)."
        echo "   Run 'just bootstrap-node' to install Node {{ node_major_version }} LTS."
        exit 1
    fi
    echo "Installing jco {{ jco_version }} and componentize-js {{ componentize_js_version }} globally..."
    npm install -g \
        "@bytecodealliance/jco@{{ jco_version }}" \
        "@bytecodealliance/componentize-js@{{ componentize_js_version }}"
    echo ""
    echo "✓ JS component tooling installed."
    echo "  Build: jco componentize src/index.js --wit wit -o out.wasm"

# Go component-build tooling: wit-bindgen-go via 'go install'
install-go-tools:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v go &>/dev/null; then
        echo "❌ go not found. Run 'just bootstrap-go' (or install Go {{ go_version }}+ from https://go.dev/dl/)"; exit 1
    fi
    echo "Installing wit-bindgen-go v{{ wit_bindgen_go_version }}..."
    go install "go.bytecodealliance.org/cmd/wit-bindgen-go@v{{ wit_bindgen_go_version }}"
    echo ""
    echo "✓ Go component tooling installed."
    echo "  TinyGo flow:    just install-tinygo  (native wasip2; also needs wasm-tools — run 'just install-wasm-tools' or 'just install-rust-tools')"
    echo "  Standard Go:    GOOS=wasip1 GOARCH=wasm go build + 'wasm-tools component new --adapt ...'"

# TinyGo binary release (cross-platform; symlinks tinygo into /usr/local/bin)
# NOTE: TinyGo's wasip2 build target requires wasm-tools on PATH — install via
# 'just install-wasm-tools' (binary download) or 'just install-rust-tools'
# (cargo-built). This recipe warns if wasm-tools is missing but does not block.
install-tinygo:
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{ os() }}-{{ arch() }}" in
        linux-x86_64)  pkg="tinygo{{ tinygo_version }}.linux-amd64.tar.gz" ;;
        linux-aarch64) pkg="tinygo{{ tinygo_version }}.linux-arm64.tar.gz" ;;
        macos-x86_64)  pkg="tinygo{{ tinygo_version }}.darwin-amd64.tar.gz" ;;
        macos-aarch64) pkg="tinygo{{ tinygo_version }}.darwin-arm64.tar.gz" ;;
        *) echo "❌ Unsupported: {{ os() }}-{{ arch() }}"; exit 1 ;;
    esac
    URL="https://github.com/tinygo-org/tinygo/releases/download/v{{ tinygo_version }}/${pkg}"
    PREFIX="/usr/local"
    SUDO=""; [ "$EUID" -ne 0 ] && SUDO="sudo"

    rm -rf /tmp/tinygo-dl && mkdir -p /tmp/tinygo-dl
    echo "Downloading TinyGo {{ tinygo_version }}..."
    curl -fL "$URL" -o /tmp/tinygo-dl/dl.tar.gz
    tar -xzf /tmp/tinygo-dl/dl.tar.gz -C /tmp/tinygo-dl
    $SUDO rm -rf "$PREFIX/tinygo"
    $SUDO mv /tmp/tinygo-dl/tinygo "$PREFIX/tinygo"
    $SUDO ln -sf "$PREFIX/tinygo/bin/tinygo" "$PREFIX/bin/tinygo"
    rm -rf /tmp/tinygo-dl
    echo ""
    echo "✓ TinyGo installed → $PREFIX/tinygo (symlinked at $PREFIX/bin/tinygo)"
    tinygo version
    if ! command -v wasm-tools &>/dev/null; then
        echo ""
        echo "⚠ wasm-tools not on PATH. TinyGo's 'tinygo build -target=wasip2' will"
        echo "  fail with: \\\`wasm-tools component embed\\\` failed: executable file not"
        echo "  found in \$PATH. Run 'just install-wasm-tools' or 'just install-rust-tools'."
    fi

# === Internal helpers ===
#
# These are used by the per-tool installers above. They're not "private" in
# just's sense (since recipes that depend on `just _dl-...` need to invoke them)
# but they aren't expected to be called directly by users.

# Download a tarball and extract one inner binary to dest_dir/dest_name.
# Args: url, dest_name, dest_dir, inner_path
_dl-tarball url dest_name dest_dir inner_path:
    #!/usr/bin/env bash
    set -euo pipefail
    URL="{{ url }}"
    DEST_NAME="{{ dest_name }}"
    DEST_DIR="{{ dest_dir }}"
    INNER="{{ inner_path }}"

    SUDO=""
    { [ "${DEST_DIR#/usr}" != "$DEST_DIR" ] || [ "${DEST_DIR#/opt}" != "$DEST_DIR" ]; } && [ "$EUID" -ne 0 ] && SUDO="sudo"

    case "$URL" in
        *.tar.xz) flag="-xJf" ;;
        *.tar.gz|*.tgz) flag="-xzf" ;;
        *) echo "❌ Unknown archive type: $URL"; exit 1 ;;
    esac

    TMP="$(mktemp -d -t dl-XXXX)"
    trap 'rm -rf "$TMP"' EXIT
    echo "Downloading $DEST_NAME..."
    curl -fL "$URL" -o "$TMP/dl"
    tar $flag "$TMP/dl" -C "$TMP"
    $SUDO mkdir -p "$DEST_DIR"
    $SUDO mv "$TMP/$INNER" "$DEST_DIR/$DEST_NAME"
    $SUDO chmod +x "$DEST_DIR/$DEST_NAME"
    echo "✓ $DEST_NAME → $DEST_DIR/$DEST_NAME"

# Download a raw binary directly to dest_dir/dest_name.
# Args: url, dest_name, dest_dir
_dl-raw url dest_name dest_dir:
    #!/usr/bin/env bash
    set -euo pipefail
    URL="{{ url }}"
    DEST_NAME="{{ dest_name }}"
    DEST_DIR="{{ dest_dir }}"

    SUDO=""
    { [ "${DEST_DIR#/usr}" != "$DEST_DIR" ] || [ "${DEST_DIR#/opt}" != "$DEST_DIR" ]; } && [ "$EUID" -ne 0 ] && SUDO="sudo"

    TMP="$(mktemp -d -t dl-XXXX)"
    trap 'rm -rf "$TMP"' EXIT
    echo "Downloading $DEST_NAME..."
    curl -fL "$URL" -o "$TMP/dl"
    $SUDO mkdir -p "$DEST_DIR"
    $SUDO mv "$TMP/dl" "$DEST_DIR/$DEST_NAME"
    $SUDO chmod +x "$DEST_DIR/$DEST_NAME"
    echo "✓ $DEST_NAME → $DEST_DIR/$DEST_NAME"
