# CSV GroupBy WebAssembly Component

A generic, reusable WebAssembly component for performing GROUP BY operations on CSV files with support for multiple aggregation functions.

## Features

- **Generic GROUP BY**: Group CSV data by one or multiple columns
- **Multiple Aggregations**: COUNT, SUM, AVG, MIN, MAX
- **Flexible Column Selection**: Specify columns by name or index
- **Custom Aliases**: Name your aggregation result columns
- **Component Model**: Built using WebAssembly Component Model for maximum portability

## Building

```bash
just build-csv-groupby   # → ../bin/csv-groupby.wasm
```

The recipe runs `cargo build --release --target wasm32-wasip2`; the
top-level `components/Justfile` then copies
`target/wasm32-wasip2/release/csv_groupby.wasm` to
`../bin/csv-groupby.wasm` and validates it.

## WIT Interface

```wit
interface groupby {
    enum agg-operation {
        count, sum, avg, min, max
    }

    record aggregation {
        column: string,          // Column name or index (as string)
        operation: agg-operation,
        alias: option<string>,   // Optional alias for result column
    }

    record group-by-request {
        csv-data: string,                // The CSV content
        group-columns: list<string>,     // Columns to group by
        aggregations: list<aggregation>, // Aggregations to compute
        has-header: bool,                // Whether CSV has header row
    }

    record grouped-row {
        group-values: list<string>,
        aggregated-values: list<string>,
    }

    record group-by-result {
        headers: list<string>,
        rows: list<grouped-row>,
    }

    execute-group-by: func(request: group-by-request)
        -> result<group-by-result, string>;
}
```

## Usage Examples

### Example 1: Group by Region with SUM

Given this CSV:
```csv
region,product,sales,quantity
North,Widget,1000,10
North,Gadget,1500,15
South,Widget,2000,20
South,Gadget,2500,25
North,Widget,1200,12
```

Request:
```
group-columns: ["region"]
aggregations: [
  { column: "sales", operation: sum, alias: "total_sales" }
]
```

Result:
```
Headers: ["region", "total_sales"]
Rows:
  ["East"] => ["1800"]
  ["North"] => ["3700"]
  ["South"] => ["4500"]
```

### Example 2: Multiple Aggregations

Request:
```
group-columns: ["product"]
aggregations: [
  { column: "sales", operation: avg, alias: "avg_sales" },
  { column: "quantity", operation: min, alias: "min_qty" },
  { column: "quantity", operation: max, alias: "max_qty" }
]
```

### Example 3: Multiple GROUP BY Columns

Request:
```
group-columns: ["region", "product"]
aggregations: [
  { column: "sales", operation: sum, alias: null }
]
```

### Example 4: Using Column Indices

Request:
```
group-columns: ["0"]  // First column (region)
aggregations: [
  { column: "2", operation: sum, alias: "total" }  // Third column (sales)
]
```

## Composability

As a WebAssembly Component, this can be:
- Composed with other components
- Called from any language with Component Model bindings
- Deployed to WASI-compatible runtimes
- Published to OCI registries

## Implementation Details

- **Language**: Rust
- **CSV Parsing**: Using the `csv` crate
- **Bindings**: `wit-bindgen` 0.35.0
- **Size**: ~167KB (release build with LTO)
- **Target**: `wasm32-wasip2`

## Error Handling

The component returns descriptive errors for:
- Invalid CSV format
- Column not found (by name or index)
- Type mismatches (non-numeric values for SUM/AVG/MIN/MAX)
- Out of range column indices

## License

This component demonstrates generic CSV GROUP BY operations using WebAssembly Component Model.
