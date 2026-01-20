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
wasmtime run --invoke 'ping()' components/tech-ticker.wasm
# Output: "tech-ticker ready"

# Generate random string (10 characters)
wasmtime run --invoke 'random-string(10)' components/tech-ticker.wasm
# Output: "qOT3pquZuN"

# Generate random string (32 characters)
wasmtime run --invoke 'random-string(32)' components/tech-ticker.wasm
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

Requires Rust with `cargo-component`:

```bash
# Install prerequisites
rustup target add wasm32-wasip1
cargo install cargo-component

# Build
cd components/tech-ticker
cargo component build --release

# Copy to components directory
cp target/wasm32-wasip1/release/tech_ticker.wasm ../tech-ticker.wasm
```

## Size

~47KB compiled (optimized with LTO and stripping)

## License

See repository root for license information.
