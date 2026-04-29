# Stock Ticker WebAssembly Component

A WebAssembly component written in Go that simulates a stock ticker streaming service for tech stocks (MSFT, AAPL, GOOGL, AMZN).

## Features

- **Real-time Price Simulation**: Simulates realistic stock price movements with random fluctuations
- **Multiple Stock Support**: Tracks Microsoft, Apple, Google/Alphabet, and Amazon stocks
- **Component Model**: Built using the WebAssembly Component Model for maximum portability
- **No WASI Dependencies**: Self-contained with no external runtime dependencies
- **Compact Size**: Only 281KB built with TinyGo

## Building

### Prerequisites

- Go 1.21+ (for dependencies)
- TinyGo 0.32+ (for WebAssembly compilation)
- `wasm-tools` (for validation)

### Build Instructions

```bash
./build.sh
```

The component will be built to `stock-ticker.wasm` and copied to `../bin/stock-ticker.wasm`.

## WIT Interface

```wit
package stock:ticker;

interface ticker {
    enum stock-symbol {
        msft,   // Microsoft
        aapl,   // Apple
        googl,  // Google/Alphabet
        amzn,   // Amazon
    }

    record stock-price {
        symbol: stock-symbol,
        price: f64,
        timestamp: u64,
    }

    record ticker-config {
        symbols: list<stock-symbol>,
        interval-ms: u32,
        duration-sec: u32,
    }

    // Get current price for a specific stock
    get-price: func(symbol: stock-symbol) -> stock-price;

    // Get current prices for all tracked stocks
    get-all-prices: func() -> list<stock-price>;

    // Simulate price updates and return a batch
    tick: func(config: ticker-config) -> list<stock-price>;
}
```

## Usage

### Running with Wasmtime

Get all current stock prices:
```bash
wasmtime run components/bin/stock-ticker.wasm --invoke='stock:ticker/ticker#get-all-prices'
```

Get price for a specific stock (MSFT = 0, AAPL = 1, GOOGL = 2, AMZN = 3):
```bash
wasmtime run components/bin/stock-ticker.wasm --invoke='stock:ticker/ticker#get-price' -- 0
```

### Using with Wassette Server

Load the component in the Wassette MCP server:
```bash
wassette serve --sse --plugin-dir components
```

Then use it via the MCP tools in Claude Code or other MCP clients.

## Exported Functions

1. **`stock:ticker/ticker#get-price`**
   - Takes a stock symbol (0-3)
   - Returns the current price for that stock

2. **`stock:ticker/ticker#get-all-prices`**
   - Takes no arguments
   - Returns prices for all 4 stocks

3. **`stock:ticker/ticker#tick`**
   - Takes a configuration with:
     - `symbols`: list of stock symbols to track
     - `interval-ms`: update interval (informational)
     - `duration-sec`: how long to run (informational)
   - Updates prices and returns new values

## Price Simulation

The component simulates realistic stock price movements:
- **Starting prices**:
  - MSFT: $420.50
  - AAPL: $185.75
  - GOOGL: $142.30
  - AMZN: $175.80
- **Price fluctuation**: ±2% per tick
- **Price bounds**: 50%-150% of base price
- **Random generator**: Custom LCG (Linear Congruential Generator) for determinism

## Implementation Details

- **Language**: Go
- **Compiler**: TinyGo 0.39.0
- **Target**: WASI preview 1 (wasip1)
- **Bindings**: Generated with `wit-bindgen-go` v0.6.2
- **Size**: ~281KB (optimized with `-opt=2`)
- **No stdlib time/rand**: Uses custom implementations to avoid WASI dependencies

## File Structure

```
stock-ticker/
├── main.go           # Component implementation
├── go.mod            # Go module definition
├── build.sh          # Build script
├── wit/
│   └── world.wit     # WIT interface definition
└── gen/              # Generated bindings (from wit-bindgen-go)
```

## Notes

- Timestamps are simulated using a counter (not real Unix time) to avoid WASI clock dependencies
- Price randomness uses a simple LCG algorithm for reproducibility
- The component maintains state between calls - prices evolve over time
- Each call to `tick()` updates the internal prices before returning

## License

MIT License - Example component for demonstrating WebAssembly Component Model with Go
