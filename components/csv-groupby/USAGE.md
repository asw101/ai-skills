# CSV GroupBy Component - Usage Guide

A generic WebAssembly component for performing SQL-like GROUP BY operations on CSV data with support for multiple aggregation functions.

## Quick Start

```bash
wasmtime run --invoke 'execute-group-by({
  csv-data: "region,sales\nNorth,1000\nSouth,2000\nNorth,1500",
  group-columns: ["region"],
  aggregations: [{column: "sales", operation: sum, alias: some("total")}],
  has-header: true
})' csv-groupby/target/wasm32-wasip1/release/csv_groupby.wasm
```

**Result:**
```
ok({headers: ["region", "total"], rows: [
  {group-values: ["North"], aggregated-values: ["2500"]},
  {group-values: ["South"], aggregated-values: ["2000"]}
]})
```

## Component Details

- **Location**: `csv-groupby/target/wasm32-wasip1/release/csv_groupby.wasm`
- **Size**: 167KB
- **Format**: WebAssembly Component Model
- **Interface**: `csv:groupby/groupby`
- **Runtime**: wasmtime 38.0.4+

## Features

### Aggregation Functions

- **COUNT** - Count rows in each group
- **SUM** - Sum numeric values
- **AVG** - Calculate average
- **MIN** - Find minimum value
- **MAX** - Find maximum value

### Column Selection

- **By name**: `"region"`, `"sales"`, `"product"`
- **By index**: `"0"`, `"1"`, `"2"` (zero-based)
- **Mixed**: Can mix names and indices in same query

### GROUP BY Options

- **Single column**: `group-columns: ["region"]`
- **Multiple columns**: `group-columns: ["region", "product"]`
- **Custom aliases**: `alias: some("total_sales")` or `alias: none`

## WAVE Format Syntax

The component uses [WAVE format](https://github.com/bytecodealliance/wasm-tools/tree/main/crates/wasm-wave#readme) for arguments:

### Request Structure

```
execute-group-by({
  csv-data: "<CSV content as string>",
  group-columns: ["<column1>", "<column2>", ...],
  aggregations: [
    {
      column: "<column-name-or-index>",
      operation: <count|sum|avg|min|max>,
      alias: some("<result-column-name>") | none
    },
    ...
  ],
  has-header: true | false
})
```

### Result Structure

```
ok({
  headers: ["<header1>", "<header2>", ...],
  rows: [
    {
      group-values: ["<value1>", "<value2>", ...],
      aggregated-values: ["<result1>", "<result2>", ...]
    },
    ...
  ]
})
```

## Usage Examples

### Example 1: GROUP BY with SUM and COUNT

**Query:** Total sales and count by region

```bash
wasmtime run --invoke 'execute-group-by({
  csv-data: "region,product,sales,quantity,month
North,Widget,1000,10,January
North,Gadget,1500,15,January
South,Widget,2000,20,January
South,Gadget,2500,25,January
North,Widget,1200,12,February
East,Gadget,1800,18,February
West,Widget,800,8,February
East,Widget,2200,22,March
West,Gadget,1900,19,March
North,Gadget,1600,16,March",
  group-columns: ["region"],
  aggregations: [
    {column: "sales", operation: sum, alias: some("total_sales")},
    {column: "sales", operation: count, alias: some("count")}
  ],
  has-header: true
})' csv-groupby/target/wasm32-wasip1/release/csv_groupby.wasm
```

**Result:**
```
ok({headers: ["region", "total_sales", "count"], rows: [
  {group-values: ["East"], aggregated-values: ["4000", "2"]},
  {group-values: ["North"], aggregated-values: ["5300", "4"]},
  {group-values: ["South"], aggregated-values: ["4500", "2"]},
  {group-values: ["West"], aggregated-values: ["2700", "2"]}
]})
```

### Example 2: GROUP BY with AVG, MIN, MAX

**Query:** Average sales, min/max quantity by product

```bash
wasmtime run --invoke 'execute-group-by({
  csv-data: "region,product,sales,quantity,month
North,Widget,1000,10,January
North,Gadget,1500,15,January
South,Widget,2000,20,January
South,Gadget,2500,25,January
North,Widget,1200,12,February
East,Gadget,1800,18,February
West,Widget,800,8,February
East,Widget,2200,22,March
West,Gadget,1900,19,March
North,Gadget,1600,16,March",
  group-columns: ["product"],
  aggregations: [
    {column: "sales", operation: avg, alias: some("avg_sales")},
    {column: "quantity", operation: min, alias: some("min_qty")},
    {column: "quantity", operation: max, alias: some("max_qty")}
  ],
  has-header: true
})' csv-groupby/target/wasm32-wasip1/release/csv_groupby.wasm
```

**Result:**
```
ok({headers: ["product", "avg_sales", "min_qty", "max_qty"], rows: [
  {group-values: ["Gadget"], aggregated-values: ["1860", "15", "25"]},
  {group-values: ["Widget"], aggregated-values: ["1440", "8", "22"]}
]})
```

### Example 3: Multi-Column GROUP BY

**Query:** Total sales by region AND product

```bash
wasmtime run --invoke 'execute-group-by({
  csv-data: "region,product,sales,quantity,month
North,Widget,1000,10,January
North,Gadget,1500,15,January
South,Widget,2000,20,January
South,Gadget,2500,25,January
North,Widget,1200,12,February",
  group-columns: ["region", "product"],
  aggregations: [{column: "sales", operation: sum, alias: none}],
  has-header: true
})' csv-groupby/target/wasm32-wasip1/release/csv_groupby.wasm
```

**Result:**
```
ok({headers: ["region", "product", "AggOperation::Sum(sales)"], rows: [
  {group-values: ["North", "Gadget"], aggregated-values: ["1500"]},
  {group-values: ["North", "Widget"], aggregated-values: ["2200"]},
  {group-values: ["South", "Gadget"], aggregated-values: ["2500"]},
  {group-values: ["South", "Widget"], aggregated-values: ["2000"]}
]})
```

### Example 4: Using Column Indices

**Query:** GROUP BY first column (index 0), sum third column (index 2)

```bash
wasmtime run --invoke 'execute-group-by({
  csv-data: "region,product,sales,quantity,month
North,Widget,1000,10,January
North,Gadget,1500,15,January
South,Widget,2000,20,January
South,Gadget,2500,25,January",
  group-columns: ["0"],
  aggregations: [
    {column: "2", operation: sum, alias: some("total")},
    {column: "3", operation: avg, alias: some("avg_qty")}
  ],
  has-header: true
})' csv-groupby/target/wasm32-wasip1/release/csv_groupby.wasm
```

**Result:**
```
ok({headers: ["region", "total", "avg_qty"], rows: [
  {group-values: ["North"], aggregated-values: ["2500", "12.5"]},
  {group-values: ["South"], aggregated-values: ["4500", "22.5"]}
]})
```

### Example 5: Employee Salary Analysis

**Query:** Salary statistics by department

```bash
wasmtime run --invoke 'execute-group-by({
  csv-data: "department,name,salary,years_experience
Engineering,Alice,95000,5
Engineering,Bob,105000,8
Engineering,Charlie,85000,3
Sales,Diana,75000,6
Sales,Eve,82000,7
Marketing,Frank,68000,4
Marketing,Grace,72000,5
Engineering,Henry,110000,10
Sales,Isabel,88000,9
Marketing,Jack,65000,2",
  group-columns: ["department"],
  aggregations: [
    {column: "salary", operation: avg, alias: some("avg_salary")},
    {column: "salary", operation: min, alias: some("min_salary")},
    {column: "salary", operation: max, alias: some("max_salary")},
    {column: "name", operation: count, alias: some("headcount")}
  ],
  has-header: true
})' csv-groupby/target/wasm32-wasip1/release/csv_groupby.wasm
```

**Result:**
```
ok({headers: ["department", "avg_salary", "min_salary", "max_salary", "headcount"], rows: [
  {group-values: ["Engineering"], aggregated-values: ["98750", "85000", "110000", "4"]},
  {group-values: ["Marketing"], aggregated-values: ["68333.33333333333", "65000", "72000", "3"]},
  {group-values: ["Sales"], aggregated-values: ["81666.66666666667", "75000", "88000", "3"]}
]})
```

## Sample Data

Sample CSV files are provided in `csv-groupby/examples/`:
- `sales.csv` - Regional sales data
- `employees.csv` - Employee salary data
- `test-cases.sh` - Shell script with all test examples

## Building from Source

```bash
cd csv-groupby
cargo component build --release
```

Output: `target/wasm32-wasip1/release/csv_groupby.wasm`

## WIT Interface

```wit
package csv:groupby;

interface groupby {
    enum agg-operation {
        count, sum, avg, min, max
    }

    record aggregation {
        column: string,
        operation: agg-operation,
        alias: option<string>,
    }

    record group-by-request {
        csv-data: string,
        group-columns: list<string>,
        aggregations: list<aggregation>,
        has-header: bool,
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

## Error Handling

The component returns descriptive errors:

- **Invalid CSV**: `"Failed to read headers: ..."`
- **Column not found**: `"Column 'xyz' not found"`
- **Type mismatch**: `"Failed to parse 'abc' as number"`
- **Out of range**: `"Column index 5 out of range"`

## Performance Notes

- Component size: 167KB (optimized with LTO)
- No external dependencies at runtime
- Sorts results by group values for consistent output
- Efficient HashMap-based grouping

## Composability

As a WebAssembly Component, this can be:
- Imported by other WASM components
- Composed using `wasm-tools compose`
- Published to OCI registries
- Called from any language with Component Model bindings

## License

MIT - See csv-groupby/README.md for details
