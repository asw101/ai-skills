use csv_groupby::exports::csv::groupby::groupby::*;

fn main() {
    // Sample CSV data
    let csv_data = r#"region,product,sales,quantity
North,Widget,1000,10
North,Gadget,1500,15
South,Widget,2000,20
South,Gadget,2500,25
North,Widget,1200,12
East,Gadget,1800,18"#;

    println!("Testing CSV GROUP BY Component");
    println!("================================\n");

    // Test 1: Group by region, compute SUM of sales and COUNT
    println!("Test 1: GROUP BY region with SUM(sales) and COUNT");
    let request = GroupByRequest {
        csv_data: csv_data.to_string(),
        group_columns: vec!["region".to_string()],
        aggregations: vec![
            Aggregation {
                column: "sales".to_string(),
                operation: AggOperation::Sum,
                alias: Some("total_sales".to_string()),
            },
            Aggregation {
                column: "sales".to_string(),
                operation: AggOperation::Count,
                alias: Some("num_sales".to_string()),
            },
        ],
        has_header: true,
    };

    match csv_groupby::Component::execute_group_by(request) {
        Ok(result) => {
            println!("Headers: {:?}", result.headers);
            for row in result.rows {
                println!("  {:?} => {:?}", row.group_values, row.aggregated_values);
            }
        }
        Err(e) => println!("Error: {}", e),
    }

    println!("\nTest 2: GROUP BY product with AVG(sales), MIN(quantity), MAX(quantity)");
    let request = GroupByRequest {
        csv_data: csv_data.to_string(),
        group_columns: vec!["product".to_string()],
        aggregations: vec![
            Aggregation {
                column: "sales".to_string(),
                operation: AggOperation::Avg,
                alias: Some("avg_sales".to_string()),
            },
            Aggregation {
                column: "quantity".to_string(),
                operation: AggOperation::Min,
                alias: Some("min_qty".to_string()),
            },
            Aggregation {
                column: "quantity".to_string(),
                operation: AggOperation::Max,
                alias: Some("max_qty".to_string()),
            },
        ],
        has_header: true,
    };

    match csv_groupby::Component::execute_group_by(request) {
        Ok(result) => {
            println!("Headers: {:?}", result.headers);
            for row in result.rows {
                println!("  {:?} => {:?}", row.group_values, row.aggregated_values);
            }
        }
        Err(e) => println!("Error: {}", e),
    }

    println!("\nTest 3: GROUP BY region AND product with SUM(sales)");
    let request = GroupByRequest {
        csv_data: csv_data.to_string(),
        group_columns: vec!["region".to_string(), "product".to_string()],
        aggregations: vec![
            Aggregation {
                column: "sales".to_string(),
                operation: AggOperation::Sum,
                alias: None,
            },
        ],
        has_header: true,
    };

    match csv_groupby::Component::execute_group_by(request) {
        Ok(result) => {
            println!("Headers: {:?}", result.headers);
            for row in result.rows {
                println!("  {:?} => {:?}", row.group_values, row.aggregated_values);
            }
        }
        Err(e) => println!("Error: {}", e),
    }

    println!("\nTest 4: Using column indices instead of names");
    let request = GroupByRequest {
        csv_data: csv_data.to_string(),
        group_columns: vec!["0".to_string()], // Group by first column (region)
        aggregations: vec![
            Aggregation {
                column: "2".to_string(), // Sum third column (sales)
                operation: AggOperation::Sum,
                alias: Some("total".to_string()),
            },
        ],
        has_header: true,
    };

    match csv_groupby::Component::execute_group_by(request) {
        Ok(result) => {
            println!("Headers: {:?}", result.headers);
            for row in result.rows {
                println!("  {:?} => {:?}", row.group_values, row.aggregated_values);
            }
        }
        Err(e) => println!("Error: {}", e),
    }

    println!("\nAll tests completed!");
}
