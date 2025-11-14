#!/bin/bash
# CSV GroupBy Component - Test Cases
# Run with: bash csv-groupby/examples/test-cases.sh

set -e

COMPONENT="csv-groupby/target/wasm32-wasip1/release/csv_groupby.wasm"

echo "========================================="
echo "CSV GroupBy Component - Test Suite"
echo "========================================="
echo ""

# Test 1: GROUP BY region with SUM and COUNT
echo "Test 1: GROUP BY region with SUM(sales) and COUNT"
echo "-------------------------------------------------"
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
})' "$COMPONENT"
echo ""
echo ""

# Test 2: GROUP BY product with AVG, MIN, MAX
echo "Test 2: GROUP BY product with AVG, MIN, MAX"
echo "--------------------------------------------"
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
})' "$COMPONENT"
echo ""
echo ""

# Test 3: Multi-column GROUP BY
echo "Test 3: Multi-column GROUP BY (region, product)"
echo "------------------------------------------------"
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
})' "$COMPONENT"
echo ""
echo ""

# Test 4: Using column indices
echo "Test 4: Using column indices (0, 2, 3)"
echo "---------------------------------------"
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
})' "$COMPONENT"
echo ""
echo ""

# Test 5: Employee salary analysis
echo "Test 5: Employee salary analysis by department"
echo "-----------------------------------------------"
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
})' "$COMPONENT"
echo ""
echo ""

echo "========================================="
echo "All tests completed!"
echo "========================================="