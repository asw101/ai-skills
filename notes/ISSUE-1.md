# ISSUE-1: Investigate wasmtime --invoke behavior with ambiguous function names

## Status
Open

## Description
When a WebAssembly component exports multiple interfaces that contain functions with the same name, it's unclear how `wasmtime run --invoke` resolves the ambiguity.

## Background
We discovered that wasmtime's WAVE parser does not support WIT-style namespaced paths:

```bash
# This fails with "unexpected token: Colon at 5..6"
wasmtime run --invoke 'local:time-server/time#get-current-time()' time-server.wasm

# This works - wasmtime auto-resolves when unambiguous
wasmtime run --invoke 'get-current-time()' time-server.wasm
```

## Open Questions
1. What happens if two exported interfaces both define a function with the same name?
2. Does wasmtime error, pick the first match, or provide a way to disambiguate?
3. Is there an alternative syntax for specifying the full interface path?

## To Investigate
- [ ] Create a test component that exports two interfaces with identically-named functions
- [ ] Test wasmtime's behavior and document the error message or resolution
- [ ] Check wasmtime source code or issues for disambiguation support
- [ ] Update wasm-run skill with findings

## References
- wasmtime CLI docs: https://docs.wasmtime.dev/cli-options.html
- WAVE syntax: https://github.com/bytecodealliance/wasm-tools/tree/main/crates/wasm-wave

## Date Created
2026-01-19
