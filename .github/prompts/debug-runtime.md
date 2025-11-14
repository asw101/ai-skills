# Debug Component Runtime Issues

This prompt template helps diagnose and fix WebAssembly component runtime problems.

## Issue Report

**Component**: [COMPONENT_NAME]
**Error message**: [ERROR_MESSAGE]
**Command attempted**: [COMMAND]
**Expected behavior**: [EXPECTED]
**Actual behavior**: [ACTUAL]

---

## Step 1: Validate Component

First, ensure the component itself is valid:

```bash
# Check component validity
wasm-tools validate components/[component-name].wasm

# Inspect interface
wasm-tools component wit components/[component-name].wasm

# Check component metadata
wasm-tools component metadata show components/[component-name].wasm
```

**Validation result**: [PASS/FAIL]
**Error details**: [DETAILS]

---

## Step 2: Check wasmtime Version

Ensure wasmtime supports the component's requirements:

```bash
wasmtime --version
```

**Required**: v14.0.0+ for WASI preview2
**Your version**: [VERSION]
**Upgrade needed**: [YES/NO]

---

## Step 3: Identify Error Category

### Permission Errors

**Symptoms**:
- "failed to find a pre-opened file descriptor"
- "permission denied"
- "access denied"

**Diagnosis**: Component needs explicit permission grants.

**Solution**: Add permission flags:
```bash
# Filesystem access
wasmtime run --dir /path/to/dir components/[component-name].wasm

# Environment variables
wasmtime run --env KEY=value components/[component-name].wasm

# Multiple permissions
wasmtime run --dir ./data --env API_KEY=xxx components/[component-name].wasm
```

### Import Errors

**Symptoms**:
- "unknown import"
- "import not found"
- "failed to instantiate"

**Diagnosis**: Component imports WASI interfaces not available.

**Solution**:
```bash
# Check what component imports
wasm-tools component wit components/[component-name].wasm | grep import

# Ensure wasmtime supports these imports
wasmtime run --wasi preview2 components/[component-name].wasm
```

### Invocation Errors

**Symptoms**:
- "function not found"
- "no function to invoke"
- "invalid argument"

**Diagnosis**: Incorrect function invocation.

**Solution**:
```bash
# List available exports
wasm-tools component wit components/[component-name].wasm | grep export

# Invoke specific function
wasmtime run --invoke 'function-name()' components/[component-name].wasm

# With arguments
wasmtime run --invoke 'process("test input")' components/[component-name].wasm
```

### Type Errors

**Symptoms**:
- "type mismatch"
- "invalid type"
- "argument type error"

**Diagnosis**: Function called with wrong argument types.

**Solution**: Check function signature in WIT and match types exactly.

### Memory Errors

**Symptoms**:
- "out of memory"
- "memory access out of bounds"
- Segmentation fault

**Diagnosis**: Component exceeding memory limits or accessing invalid memory.

**Solution**:
```bash
# Increase memory limit (in pages, 64KB each)
wasmtime run --max-memory-size 134217728 components/[component-name].wasm

# Profile memory usage
wasmtime run --profile components/[component-name].wasm
```

---

## Step 4: Detailed Investigation

### Check Component Size
```bash
ls -lh components/[component-name].wasm
```

**Size**: [SIZE]
**Expected range**: 
- Rust: 100-300KB
- Python: 5-10MB
- JavaScript: 500KB-2MB
- Go: 200KB-1MB

**Concern**: [YES/NO]

### Inspect Imports
```bash
wasm-tools component wit components/[component-name].wasm | grep "import" -A 5
```

**Imports found**:
```
[IMPORT_LIST]
```

**WASI version**: [preview1/preview2]
**Compatibility**: [OK/ISSUE]

### Check Exports
```bash
wasm-tools component wit components/[component-name].wasm | grep "export" -A 5
```

**Exports found**:
```
[EXPORT_LIST]
```

**Expected interface**: [MATCHES/DIFFERS]

---

## Step 5: Test with Minimal Permissions

Start with no permissions and add incrementally:

```bash
# Step 1: Minimal execution
wasmtime run components/[component-name].wasm

# Step 2: Add stdout (if needed)
wasmtime run --wasi preview2 components/[component-name].wasm

# Step 3: Add filesystem (if needed)
wasmtime run --dir . components/[component-name].wasm

# Step 4: Add specific directory
wasmtime run --dir ./data components/[component-name].wasm

# Step 5: Add environment
wasmtime run --dir ./data --env KEY=value components/[component-name].wasm
```

**Working configuration**: [COMMAND]

---

## Step 6: Compare with Working Component

If you have a similar working component:

```bash
# Compare interfaces
diff <(wasm-tools component wit working.wasm) \
     <(wasm-tools component wit broken.wasm)

# Compare sizes
ls -lh working.wasm broken.wasm

# Compare metadata
diff <(wasm-tools component metadata show working.wasm) \
     <(wasm-tools component metadata show broken.wasm)
```

**Differences found**: [DIFFERENCES]

---

## Step 7: Language-Specific Checks

### Rust
```bash
# Verify target
rustc --print target-list | grep wasm32-wasip2

# Check Cargo.toml
cat Cargo.toml | grep -A 3 "\[lib\]"
cat Cargo.toml | grep -A 5 "\[profile.release\]"

# Rebuild clean
cargo clean
cargo component build --release --target wasm32-wasip2
```

### Python
```bash
# Regenerate bindings
cd components/[component-name]
componentize-py bindings .

# Rebuild
componentize-py componentize app -o ../[component-name].wasm

# Check dependencies
python -c "import sys; print(sys.modules.keys())"
```

### JavaScript
```bash
# Check package.json
cat package.json | grep "type"

# Verify jco version
jco --version

# Rebuild
rm -rf node_modules
npm install
npm run build
```

### Go
```bash
# Verify TinyGo
tinygo version

# Regenerate bindings
go generate

# Rebuild
rm -f [component-name].wasm
tinygo build -target=wasip2 -o [component-name].wasm .
```

---

## Step 8: Enable Verbose Logging

Get detailed runtime information:

```bash
# Maximum verbosity
WASMTIME_BACKTRACE_DETAILS=1 wasmtime run -D cache=n -D cranelift-debug components/[component-name].wasm

# With profiling
wasmtime run --profile components/[component-name].wasm
```

**Debug output**:
```
[DEBUG_OUTPUT]
```

---

## Step 9: Test Component in Isolation

Create a minimal test harness:

```bash
# Create test script
cat > test-component.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "Testing component: $1"

echo "1. Validating..."
wasm-tools validate "$1" || exit 1

echo "2. Checking interface..."
wasm-tools component wit "$1"

echo "3. Basic execution..."
wasmtime run "$1"

echo "✓ All tests passed"
EOF

chmod +x test-component.sh
./test-component.sh components/[component-name].wasm
```

**Test result**: [PASS/FAIL]

---

## Step 10: Rebuild from Scratch

If all else fails, rebuild the component:

```bash
# Clean all artifacts
cd components/[component-name]
rm -rf target/ node_modules/ __pycache__/ gen/

# For Rust
cargo clean
cargo component build --release --target wasm32-wasip2

# For Python
rm -rf *.py[cod] __pycache__
componentize-py bindings .
componentize-py componentize app -o ../[component-name].wasm

# For JavaScript
rm -rf node_modules/ dist/
npm install
npm run build

# For Go
rm -rf gen/
go clean
go generate
tinygo build -target=wasip2 -o ../[component-name].wasm .
```

**Rebuild successful**: [YES/NO]

---

## Solution Summary

**Root cause**: [IDENTIFIED_CAUSE]

**Fix applied**:
```bash
[WORKING_COMMAND]
```

**Explanation**: [WHY_THIS_WORKS]

**Prevention**: [HOW_TO_AVOID_IN_FUTURE]

---

## Common Solutions Quick Reference

| Error | Cause | Solution |
|-------|-------|----------|
| "failed to find a pre-opened file descriptor" | Missing filesystem permission | Add `--dir` flag |
| "unknown import wasi:http" | Old wasmtime version | Upgrade to v14.0.0+ |
| "function not found" | Wrong invoke syntax | Check WIT exports |
| "permission denied" | Insufficient permissions | Add `--env` or `--dir` |
| "type mismatch" | Wrong argument type | Match WIT signature |
| "out of memory" | Memory limit too low | Increase with `--max-memory-size` |
| "module not found" (Python) | Bindings out of sync | Regenerate with `componentize-py bindings .` |
| "module resolution" (JS) | Wrong package.json type | Set `"type": "module"` |

---

## Escalation

If issue persists:

1. **Check wasmtime issues**: https://github.com/bytecodealliance/wasmtime/issues
2. **Component Model issues**: https://github.com/WebAssembly/component-model/issues
3. **Language-specific**:
   - cargo-component: https://github.com/bytecodealliance/cargo-component/issues
   - componentize-py: https://github.com/bytecodealliance/componentize-py/issues
   - jco: https://github.com/bytecodealliance/jco/issues
   - TinyGo: https://github.com/tinygo-org/tinygo/issues

**Issue to file**:
- Component: [NAME]
- wasmtime version: [VERSION]
- OS: [OS]
- Error: [ERROR]
- Reproduction: [MINIMAL_REPRODUCTION]
