---
applyTo:
  - Justfile
  - "*.sh"
  - components/**/build.sh
  - .github/workflows/**
---

# Build Automation and Scripting Instructions

When working with build scripts, Justfiles, or automation workflows, follow these patterns for WebAssembly component build systems.

## Justfile Patterns

### Recipe Structure

```make
# Recipe description
recipe-name param="default":
    @echo "Starting task..."
    command1
    command2
```

### Common WebAssembly Recipes

```make
# Build all components
build-all:
    @echo "Building all components..."
    just build-rust
    just build-python
    just build-js
    just build-go

# Build Rust components
build-rust:
    #!/usr/bin/env bash
    set -euo pipefail
    for dir in components/*/Cargo.toml; do
        component=$(dirname "$dir")
        name=$(basename "$component")
        echo "Building $name (Rust)..."
        cd "$component"
        cargo component build --release --target wasm32-wasip2
        cp target/wasm32-wasip2/release/*.wasm "../$name.wasm"
        cd ../..
    done

# Build Python components
build-python:
    #!/usr/bin/env bash
    set -euo pipefail
    for dir in components/*/pyproject.toml; do
        component=$(dirname "$dir")
        name=$(basename "$component")
        echo "Building $name (Python)..."
        cd "$component"
        componentize-py bindings .
        componentize-py componentize app -o "../$name.wasm"
        cd ../..
    done

# Validate all components
validate:
    #!/usr/bin/env bash
    set -euo pipefail
    for wasm in components/*.wasm; do
        echo "Validating $wasm..."
        wasm-tools validate "$wasm"
        wasm-tools component wit "$wasm" > /dev/null
    done

# Clean build artifacts
clean:
    find components -type d -name target -exec rm -rf {} + || true
    find components -type d -name node_modules -exec rm -rf {} + || true
    find components -type d -name __pycache__ -exec rm -rf {} + || true
    rm -f components/*.wasm

# Install prerequisites
setup:
    rustup target add wasm32-wasip2
    cargo install cargo-component wasm-tools
    pip install componentize-py
    npm install -g @bytecodealliance/jco wasm-opt
```

### Test Recipes

```make
# Test component with wasmtime
test component:
    wasmtime run components/{{component}}.wasm

# Test with permissions
test-with-dir component dir:
    wasmtime run --dir {{dir}} components/{{component}}.wasm

# Run all tests
test-all:
    #!/usr/bin/env bash
    set -euo pipefail
    for wasm in components/*.wasm; do
        echo "Testing $wasm..."
        wasmtime run "$wasm" || echo "  Test failed: $wasm"
    done
```

### Publishing Recipes

```make
# Publish component to registry
publish component tag:
    wkg oci push ghcr.io/${GITHUB_USER}/{{component}}:{{tag}} components/{{component}}.wasm \
        --annotation org.opencontainers.image.source="${GITHUB_REPO}" \
        --annotation org.opencontainers.image.version="{{tag}}"

# Publish all components
publish-all tag:
    #!/usr/bin/env bash
    set -euo pipefail
    for wasm in components/*.wasm; do
        name=$(basename "$wasm" .wasm)
        echo "Publishing $name:{{tag}}..."
        just publish "$name" "{{tag}}"
    done
```

### Utility Recipes

```make
# Show component interface
inspect component:
    wasm-tools component wit components/{{component}}.wasm

# Check component size
size component:
    ls -lh components/{{component}}.wasm

# Optimize component
optimize component:
    wasm-opt -Os components/{{component}}.wasm -o components/{{component}}.opt.wasm
    mv components/{{component}}.opt.wasm components/{{component}}.wasm

# List all recipes
default:
    @just --list
```

## Shell Script Patterns

### Build Script Template

```bash
#!/usr/bin/env bash
set -euo pipefail

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly COMPONENT_NAME="$(basename "$SCRIPT_DIR")"
readonly OUTPUT_DIR="${SCRIPT_DIR}/.."

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Main build function
main() {
    log_info "Building ${COMPONENT_NAME}..."
    
    cd "$SCRIPT_DIR"
    
    # Language-specific build logic
    if [[ -f Cargo.toml ]]; then
        build_rust
    elif [[ -f pyproject.toml ]]; then
        build_python
    elif [[ -f package.json ]]; then
        build_javascript
    elif [[ -f go.mod ]]; then
        build_go
    else
        log_error "Unknown component type"
        exit 1
    fi
    
    # Validate output
    if [[ -f "${OUTPUT_DIR}/${COMPONENT_NAME}.wasm" ]]; then
        log_info "Validating component..."
        wasm-tools validate "${OUTPUT_DIR}/${COMPONENT_NAME}.wasm"
        
        local size=$(du -h "${OUTPUT_DIR}/${COMPONENT_NAME}.wasm" | cut -f1)
        log_info "Build complete: ${COMPONENT_NAME}.wasm (${size})"
    else
        log_error "Build failed: output file not found"
        exit 1
    fi
}

build_rust() {
    log_info "Building Rust component..."
    cargo component build --release --target wasm32-wasip2
    cp "target/wasm32-wasip2/release/${COMPONENT_NAME}.wasm" \
       "${OUTPUT_DIR}/${COMPONENT_NAME}.wasm"
}

build_python() {
    log_info "Building Python component..."
    componentize-py bindings .
    componentize-py componentize app -o "${OUTPUT_DIR}/${COMPONENT_NAME}.wasm"
}

build_javascript() {
    log_info "Building JavaScript component..."
    npm install
    npm run build
}

build_go() {
    log_info "Building Go component..."
    go generate
    tinygo build -target=wasip2 -o "${OUTPUT_DIR}/${COMPONENT_NAME}.wasm" .
}

main "$@"
```

### Test Script Template

```bash
#!/usr/bin/env bash
set -euo pipefail

readonly COMPONENT="$1"
readonly TEST_DATA="${2:-examples}"

run_test() {
    local description="$1"
    local command="$2"
    
    echo "Testing: $description"
    if eval "$command"; then
        echo "  ✓ Passed"
        return 0
    else
        echo "  ✗ Failed"
        return 1
    fi
}

main() {
    if [[ ! -f "components/${COMPONENT}.wasm" ]]; then
        echo "Error: Component not found: ${COMPONENT}"
        exit 1
    fi
    
    local failed=0
    
    run_test "Basic execution" \
        "wasmtime run components/${COMPONENT}.wasm" || ((failed++))
    
    if [[ -d "$TEST_DATA" ]]; then
        run_test "With test data" \
            "wasmtime run --dir $TEST_DATA components/${COMPONENT}.wasm" || ((failed++))
    fi
    
    run_test "Validation" \
        "wasm-tools validate components/${COMPONENT}.wasm" || ((failed++))
    
    if [[ $failed -eq 0 ]]; then
        echo "All tests passed!"
        exit 0
    else
        echo "$failed test(s) failed"
        exit 1
    fi
}

main "$@"
```

## CI/CD Patterns

### GitHub Actions Workflow

```yaml
name: Build and Test WebAssembly Components

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Rust
        uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
          target: wasm32-wasip2
      
      - name: Install cargo-component
        run: cargo install cargo-component
      
      - name: Install wasm-tools
        run: cargo install wasm-tools
      
      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      
      - name: Install componentize-py
        run: pip install componentize-py
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
      
      - name: Install jco
        run: npm install -g @bytecodealliance/jco
      
      - name: Setup TinyGo
        uses: acifani/setup-tinygo@v2
        with:
          tinygo-version: '0.33.0'
      
      - name: Install just
        uses: extractions/setup-just@v1
      
      - name: Build all components
        run: just build-all
      
      - name: Validate components
        run: just validate
      
      - name: Test components
        run: just test-all
      
      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: wasm-components
          path: components/*.wasm
```

### Publish Workflow

```yaml
name: Publish Components

on:
  release:
    types: [published]

jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      packages: write
      contents: read
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup tools
        run: |
          cargo install wasm-tools
          # Install wkg from releases
      
      - name: Build components
        run: just build-all
      
      - name: Login to GHCR
        run: |
          echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io \
            -u ${{ github.actor }} --password-stdin
      
      - name: Publish components
        env:
          GITHUB_USER: ${{ github.repository_owner }}
          GITHUB_REPO: ${{ github.repository }}
        run: just publish-all ${{ github.ref_name }}
```

## Error Handling

### Bash Best Practices

```bash
# Always use strict mode
set -euo pipefail

# Check command availability
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "Required command not found: $1"
        exit 1
    fi
}

# Handle cleanup on exit
cleanup() {
    local exit_code=$?
    # Cleanup temporary files
    rm -rf "$TEMP_DIR"
    exit $exit_code
}
trap cleanup EXIT INT TERM

# Validate prerequisites
validate_environment() {
    check_command wasmtime
    check_command wasm-tools
    
    if [[ ! -d components ]]; then
        log_error "components/ directory not found"
        exit 1
    fi
}
```

### Error Messages

Provide actionable error messages:

```bash
if [[ ! -f Cargo.toml ]]; then
    log_error "Cargo.toml not found in current directory"
    log_info "Run this script from a Rust component directory"
    log_info "Example: cd components/my-component && ./build.sh"
    exit 1
fi

if ! cargo component build --release --target wasm32-wasip2; then
    log_error "Build failed"
    log_info "Check that wasm32-wasip2 target is installed:"
    log_info "  rustup target add wasm32-wasip2"
    exit 1
fi
```

## Performance Optimization

### Parallel Builds

```make
# Build components in parallel
build-parallel:
    #!/usr/bin/env bash
    set -euo pipefail
    find components -name Cargo.toml -type f -print0 | \
        xargs -0 -P $(nproc) -I {} \
        bash -c 'cd $(dirname {}) && cargo component build --release --target wasm32-wasip2'
```

### Caching

```bash
# Cache build artifacts
readonly CACHE_DIR="${HOME}/.cache/wasm-components"

cache_component() {
    local name="$1"
    local hash=$(git log -1 --format=%H -- "components/${name}")
    local cache_path="${CACHE_DIR}/${name}/${hash}.wasm"
    
    if [[ -f "$cache_path" ]]; then
        log_info "Using cached build for ${name}"
        cp "$cache_path" "components/${name}.wasm"
        return 0
    fi
    
    return 1
}

save_to_cache() {
    local name="$1"
    local hash=$(git log -1 --format=%H -- "components/${name}")
    local cache_path="${CACHE_DIR}/${name}/${hash}.wasm"
    
    mkdir -p "$(dirname "$cache_path")"
    cp "components/${name}.wasm" "$cache_path"
}
```

## Documentation

### Recipe Documentation

```make
# Build a specific component by name
# Usage: just build <component-name>
# Example: just build csv-groupby
build component:
    @echo "Building {{component}}..."
    cd components/{{component}} && ./build.sh

# Run component with test data
# Usage: just run <component> [test-file]
# Example: just run csv-groupby examples/sales.csv
run component *args:
    wasmtime run components/{{component}}.wasm {{args}}
```

### Script Help

```bash
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] COMPONENT

Build a WebAssembly component.

OPTIONS:
    -h, --help          Show this help message
    -o, --optimize      Optimize with wasm-opt after build
    -v, --validate      Validate component after build
    -t, --test          Run tests after build

EXAMPLES:
    $(basename "$0") csv-groupby
    $(basename "$0") --optimize csv-groupby
    $(basename "$0") -ovt csv-groupby

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -o|--optimize)
            OPTIMIZE=true
            shift
            ;;
        *)
            COMPONENT="$1"
            shift
            ;;
    esac
done
```

## Quality Checklist

When writing build automation:

- [ ] Use `set -euo pipefail` in bash scripts
- [ ] Validate prerequisites before building
- [ ] Provide clear error messages with solutions
- [ ] Clean up temporary files on exit
- [ ] Support both local and CI environments
- [ ] Cache build artifacts when possible
- [ ] Validate output with wasm-tools
- [ ] Document recipe/function parameters
- [ ] Use consistent naming conventions
- [ ] Include help/usage information
