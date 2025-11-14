# CSV GroupBy Examples

This directory contains sample data and test scripts for the CSV GroupBy component.

## Sample Data Files

### sales.csv
Regional sales data with columns:
- `region` - Geographic region (North, South, East, West)
- `product` - Product name (Widget, Gadget)
- `sales` - Sales amount
- `quantity` - Number of items sold
- `month` - Month of sale

**Use cases:**
- Aggregate sales by region
- Analyze product performance
- Calculate regional statistics

### employees.csv
Employee salary data with columns:
- `department` - Department name (Engineering, Sales, Marketing)
- `name` - Employee name
- `salary` - Annual salary
- `years_experience` - Years of experience

**Use cases:**
- Calculate average salary by department
- Find salary ranges
- Count headcount per department

## Running Tests

### Run all test cases:
```bash
bash csv-groupby/examples/test-cases.sh
```

### Run individual tests:

**Example 1: Total sales by region**
```bash
wasmtime run --invoke 'execute-group-by({
  csv-data: "region,sales\nNorth,1000\nSouth,2000\nNorth,1500",
  group-columns: ["region"],
  aggregations: [{column: "sales", operation: sum, alias: some("total")}],
  has-header: true
})' csv-groupby/target/wasm32-wasip1/release/csv_groupby.wasm
```

**Example 2: Department salary statistics**
```bash
wasmtime run --invoke 'execute-group-by({
  csv-data: "dept,salary\nEng,95000\nEng,105000\nSales,75000",
  group-columns: ["dept"],
  aggregations: [
    {column: "salary", operation: avg, alias: some("avg")},
    {column: "salary", operation: count, alias: some("count")}
  ],
  has-header: true
})' csv-groupby/target/wasm32-wasip1/release/csv_groupby.wasm
```

## Test Results

All test cases validate:
- ✅ COUNT, SUM, AVG, MIN, MAX aggregations
- ✅ Single and multi-column GROUP BY
- ✅ Column selection by name and index
- ✅ Custom result aliases
- ✅ Correct numeric calculations
- ✅ Sorted output

See [USAGE.md](../USAGE.md) for complete documentation.