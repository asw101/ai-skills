use std::collections::HashMap;

// Generate bindings from WIT
wit_bindgen::generate!("csv-groupby");

use exports::csv::groupby::groupby::*;

// Export the WIT-defined interface
export!(Component);

struct Component;

impl Guest for Component {
    fn execute_group_by(
        request: GroupByRequest,
    ) -> Result<GroupByResult, String> {
        // Parse CSV
        let mut reader = csv::ReaderBuilder::new()
            .has_headers(request.has_header)
            .from_reader(request.csv_data.as_bytes());

        let headers: Vec<String> = if request.has_header {
            reader
                .headers()
                .map_err(|e| format!("Failed to read headers: {}", e))?
                .iter()
                .map(String::from)
                .collect()
        } else {
            vec![]
        };

        // Parse all records
        let mut records: Vec<Vec<String>> = Vec::new();
        for result in reader.records() {
            let record = result.map_err(|e| format!("Failed to read record: {}", e))?;
            records.push(record.iter().map(String::from).collect());
        }

        if records.is_empty() {
            return Ok(GroupByResult {
                headers: vec![],
                rows: vec![],
            });
        }

        // Resolve group column indices
        let group_indices = resolve_column_indices(&request.group_columns, &headers, &records)?;

        // Resolve aggregation column indices
        let agg_specs: Vec<(usize, AggOperation, String)> =
            request
                .aggregations
                .iter()
                .map(|agg| {
                    let idx = resolve_column_index(&agg.column, &headers, &records)?;
                    let alias = agg.alias.clone().unwrap_or_else(|| {
                        format!(
                            "{:?}({})",
                            agg.operation,
                            if !headers.is_empty() && idx < headers.len() {
                                &headers[idx]
                            } else {
                                &agg.column
                            }
                        )
                    });
                    Ok((idx, agg.operation.clone(), alias))
                })
                .collect::<Result<Vec<_>, String>>()?;

        // Group records
        let mut groups: HashMap<Vec<String>, Vec<Vec<String>>> = HashMap::new();
        for record in records {
            let key: Vec<String> = group_indices.iter().map(|&i| record[i].clone()).collect();
            groups.entry(key).or_insert_with(Vec::new).push(record);
        }

        // Build result headers
        let mut result_headers = Vec::new();
        for &idx in &group_indices {
            if !headers.is_empty() && idx < headers.len() {
                result_headers.push(headers[idx].clone());
            } else {
                result_headers.push(format!("column_{}", idx));
            }
        }
        for (_, _, alias) in &agg_specs {
            result_headers.push(alias.clone());
        }

        // Compute aggregations for each group
        let mut result_rows = Vec::new();
        for (group_values, group_records) in groups {
            let mut aggregated_values = Vec::new();

            for (col_idx, operation, _) in &agg_specs {
                let agg_result = match operation {
                    AggOperation::Count => {
                        group_records.len().to_string()
                    }
                    AggOperation::Sum => {
                        compute_sum(&group_records, *col_idx)?
                    }
                    AggOperation::Avg => {
                        compute_avg(&group_records, *col_idx)?
                    }
                    AggOperation::Min => {
                        compute_min(&group_records, *col_idx)?
                    }
                    AggOperation::Max => {
                        compute_max(&group_records, *col_idx)?
                    }
                };
                aggregated_values.push(agg_result);
            }

            result_rows.push(GroupedRow {
                group_values,
                aggregated_values,
            });
        }

        // Sort results by group values for consistent output
        result_rows.sort_by(|a, b| a.group_values.cmp(&b.group_values));

        Ok(GroupByResult {
            headers: result_headers,
            rows: result_rows,
        })
    }
}

// Helper functions

fn resolve_column_indices(
    columns: &[String],
    headers: &[String],
    records: &[Vec<String>],
) -> Result<Vec<usize>, String> {
    columns
        .iter()
        .map(|col| resolve_column_index(col, headers, records))
        .collect()
}

fn resolve_column_index(
    column: &str,
    headers: &[String],
    records: &[Vec<String>],
) -> Result<usize, String> {
    // Try parsing as index first
    if let Ok(idx) = column.parse::<usize>() {
        let max_cols = records.first().map(|r| r.len()).unwrap_or(0);
        if idx < max_cols {
            return Ok(idx);
        }
        return Err(format!("Column index {} out of range", idx));
    }

    // Try finding by name in headers
    if !headers.is_empty() {
        if let Some(pos) = headers.iter().position(|h| h == column) {
            return Ok(pos);
        }
    }

    Err(format!("Column '{}' not found", column))
}

fn parse_numeric_values(records: &[Vec<String>], col_idx: usize) -> Result<Vec<f64>, String> {
    records
        .iter()
        .map(|record| {
            record
                .get(col_idx)
                .ok_or_else(|| format!("Column index {} out of range", col_idx))?
                .parse::<f64>()
                .map_err(|_| {
                    format!(
                        "Failed to parse '{}' as number",
                        record.get(col_idx).unwrap()
                    )
                })
        })
        .collect()
}

fn compute_sum(records: &[Vec<String>], col_idx: usize) -> Result<String, String> {
    let values = parse_numeric_values(records, col_idx)?;
    Ok(values.iter().sum::<f64>().to_string())
}

fn compute_avg(records: &[Vec<String>], col_idx: usize) -> Result<String, String> {
    let values = parse_numeric_values(records, col_idx)?;
    if values.is_empty() {
        return Ok("0".to_string());
    }
    let avg = values.iter().sum::<f64>() / values.len() as f64;
    Ok(avg.to_string())
}

fn compute_min(records: &[Vec<String>], col_idx: usize) -> Result<String, String> {
    let values = parse_numeric_values(records, col_idx)?;
    values
        .iter()
        .min_by(|a, b| a.partial_cmp(b).unwrap())
        .map(|v| v.to_string())
        .ok_or_else(|| "No values to compute MIN".to_string())
}

fn compute_max(records: &[Vec<String>], col_idx: usize) -> Result<String, String> {
    let values = parse_numeric_values(records, col_idx)?;
    values
        .iter()
        .max_by(|a, b| a.partial_cmp(b).unwrap())
        .map(|v| v.to_string())
        .ok_or_else(|| "No values to compute MAX".to_string())
}
