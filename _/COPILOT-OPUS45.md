# Stock-Ticker Build Debug Session

## Problem

Building the `stock-ticker` Go/TinyGo component failed with WIT package resolution errors.

## Initial Error

```
error: failed to resolve directory while parsing WIT for path [./wit]

Caused by:
    0: failed to parse package: ./wit
    1: failed to start resolving path: ./wit/world.wit
    2: package identifier `stock:ticker` does not match previous package name of `wasi:cli@0.2.0`
```

The `wit/` directory contained two WIT files with different package declarations:
- `world.wit` - `package stock:ticker;`
- `wasi-cli-environment.wit` - `package wasi:cli@0.2.0;`

TinyGo's `--wit-package` flag expects all WIT files in the directory to belong to the same package.

## Attempts

### Attempt 1: Move WASI to deps subdirectory

Moved `wasi-cli-environment.wit` to `wit/deps/cli/environment.wit`.

**Result:** Failed - WIT resolver couldn't find the package:
```
package 'wasi:cli' not found. known packages: stock:ticker
```

### Attempt 2: Rename deps directory

Tried `wit/deps/wasi-cli/environment.wit`.

**Result:** Same error - TinyGo's WIT resolution doesn't automatically find deps packages this way.

### Attempt 3: Remove WASI import from world.wit

Removed `import wasi:cli/environment;` since the Go code didn't explicitly use it.

**Result:** Failed - TinyGo's wasip2 target always generates WASI imports:
```
module requires an import interface named `wasi:cli/environment@0.2.0`
```

### Attempt 4: Build without --wit-package

Tested basic TinyGo build: `tinygo build -target wasip2 -o test.wasm main.go`

**Result:** Builds successfully but doesn't export the custom `ticker` interface - only exports `wasi:cli/run`.

### Attempt 5: Use wkg wit fetch (Success)

Used `wkg wit fetch` to download full WASI 0.2.0 WIT definitions.

**Result:** Successfully fetched dependencies to `wit/deps/`:
- wasi-cli-0.2.0
- wasi-clocks-0.2.0
- wasi-filesystem-0.2.0
- wasi-io-0.2.0
- wasi-random-0.2.0
- wasi-sockets-0.2.0

## Solution

1. **Deleted** the incomplete `wasi-cli-environment.wit` file
2. **Simplified** `world.wit` to just export the ticker interface (no explicit WASI import needed - wkg handles it)
3. **Ran** `wkg wit fetch` to download complete WASI 0.2.0 WIT definitions

### Final world.wit

```wit
package stock:ticker;

world stock-ticker {
    export ticker;
}

interface ticker {
    enum stock-symbol { msft, aapl, googl, amzn }
    record stock-price { symbol: stock-symbol, price: f64, timestamp: u64 }
    record ticker-config { symbols: list<stock-symbol>, interval-ms: u32, duration-sec: u32 }
    
    get-price: func(symbol: stock-symbol) -> stock-price;
    get-all-prices: func() -> list<stock-price>;
    tick: func(config: ticker-config) -> list<stock-price>;
}
```

## Build Success

```bash
$ just build-stock-ticker
Building stock-ticker component with TinyGo (WASI preview 2 target + embedded WIT)...
Copying component to ../stock-ticker.wasm...
Validating component...
Extracting WIT to verify exports...
  - WIT export OK

✓ Build complete!
-rwxr-xr-x  1 user  staff   417K Jan 19 12:24 ../stock-ticker.wasm
```

## Verification

```bash
$ wasmtime run --invoke 'get-price(msft)' stock-ticker.wasm
{symbol: msft, price: 420.5, timestamp: 43}
```

Component exports `stock:ticker/ticker` with all three functions.

## Additional Change

Added `test-stock-ticker` recipe to `components/Justfile`:

```just
# Test the stock-ticker component with wasmtime
test-stock-ticker:
    #!/usr/bin/env bash
    set -euo pipefail
    wasmtime run --invoke 'get-price(msft)' stock-ticker.wasm
```

## Key Learnings

1. **TinyGo wasip2 + WIT embedding**: When using `--wit-package` and `--wit-world`, all referenced packages must be present in the WIT directory
2. **wkg wit fetch**: The proper way to fetch WASI dependencies - reads `world.wit` and downloads required packages to `deps/`
3. **WASI imports are implicit**: TinyGo's wasip2 target always includes WASI imports; the WIT definitions just need to be available for the component embedding step
4. **Manual WASI WIT files don't work**: A partial `wasi-cli-environment.wit` file causes package conflicts - use `wkg wit fetch` for complete definitions
