# tech-ticker

A lightweight WebAssembly component providing utility functions, built with Rust and the WASI Component Model.

## Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| `ping` | `() -> string` | Health check that returns `"tech-ticker ready"` |
| `random-string` | `(length: u32) -> string` | Generate a random alphanumeric string of specified length |

## Usage

```bash
# Health check
wasmtime run --invoke 'ping()' components/bin/tech-ticker.wasm
# Output: "tech-ticker ready"

# Generate random string (10 characters)
wasmtime run --invoke 'random-string(10)' components/bin/tech-ticker.wasm
# Output: "qOT3pquZuN"

# Generate random string (32 characters)
wasmtime run --invoke 'random-string(32)' components/bin/tech-ticker.wasm
# Output: "rFh2uPAgOXaD7nYmCfOXwzZziQLgUClU"
```

## WIT Interface

```wit
package component:tech-ticker;

world tech-ticker {
    export ticker;
}

interface ticker {
    ping: func() -> string;
    random-string: func(length: u32) -> string;
}
```

## Building

The repo's top-level recipe handles everything:

```bash
cd components
just build-tech-ticker   # → bin/tech-ticker.wasm
```

Or to do it manually:

```bash
rustup target add wasm32-wasip2
cd components/tech-ticker
cargo build --release --target wasm32-wasip2
mkdir -p ../bin
cp target/wasm32-wasip2/release/tech_ticker.wasm ../bin/tech-ticker.wasm
```

The `wasm32-wasip2` target produces a Component directly; bindings are
generated inline by the `wit_bindgen::generate!` macro in `src/lib.rs`.

## Size

~47KB compiled (optimized with LTO and stripping)

## License

See repository root for license information.
