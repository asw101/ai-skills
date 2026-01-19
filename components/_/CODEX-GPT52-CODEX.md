# Stock Ticker Build Troubleshooting Summary

## Goal
Fix `just build-stock-ticker` (TinyGo WASI preview2 + embedded WIT) failing on missing `wasi:cli/environment`.

## Attempts and Outcomes
1. Added `import wasi:cli/environment;` to `components/stock-ticker/wit/world.wit` so the component encoder could resolve the import.
   - Result: WIT resolver reported `package 'wasi:cli' not found`.

2. Added a minimal WIT definition for `wasi:cli@0.2.0`:
   - Created `components/stock-ticker/wit/deps/wasi-cli@0.2.0/environment.wit` with:
     - `package wasi:cli@0.2.0;`
     - `interface environment { get-environment: func() -> list<tuple<string,string>>; }`
   - Result: Still `package 'wasi:cli' not found`.

3. Tried alternate deps layout:
   - Moved to `components/stock-ticker/wit/deps/wasi-cli/environment.wit`.
   - Added `components/stock-ticker/wit/deps.toml` with:
     - `[dependencies]` and `"wasi:cli@0.2.0" = { path = "deps/wasi-cli" }`
   - Result: Still `package 'wasi:cli' not found`.

4. Simplified to local WIT package without deps:
   - Moved the WIT file to `components/stock-ticker/wit/wasi-cli-environment.wit`.
   - Removed `components/stock-ticker/wit/deps/` and `components/stock-ticker/wit/deps.toml`.
   - Result: Pending re-test; suggested retry outside sandbox.

## Current State
- `components/stock-ticker/wit/world.wit` imports `wasi:cli/environment`.
- `components/stock-ticker/wit/wasi-cli-environment.wit` defines `package wasi:cli@0.2.0` and the `environment` interface.
- Build still failing with `package 'wasi:cli' not found` as of last user run.

## Next Ideas (Not Yet Applied)
- Switch build flow back to wasip1 module + `wasm-tools component new`, which may avoid `wasi:cli` import requirements.
- Confirm TinyGo WASI preview2 support and any additional `wasi:cli` interfaces required (e.g., args/stdio).
- Use a known WASI WIT package layout from tooling (if available) instead of the minimal local definition.

# Tech Ticker Build + Test Setup

## Goal
Fix `just build-tech-ticker` failing due to missing WIT package/world, then add a wasmtime test recipe.

## Changes Applied
- Added WIT world + interface for `tech-ticker` at `components/tech-ticker/wit/world.wit` with `package component:tech-ticker` and `ticker.ping`.
- Implemented Rust export in `components/tech-ticker/src/lib.rs` using `wit-bindgen` and `Guest::ping`.
- Updated `components/tech-ticker/Cargo.toml` to build a `cdylib` and include `wit-bindgen`.
- Added `just test-tech-ticker` recipe to `components/Justfile` that invokes `component:tech-ticker/ticker#ping` via wasmtime.

## Build/Test Status
- `just build-tech-ticker` succeeds after adding WIT and bindings.
- `just test-tech-ticker` runs the `ping` export.

## Repo Hygiene
- Added root `.gitignore` to exclude `tech-ticker/Cargo.lock`, `tech-ticker/src/bindings.rs`, and `tech-ticker/target/`.
