# Property transaction Meltano pipeline

This Meltano project reads every discovered table in `../Output/property_trans.db`
with `tap-duckdb`. The current database contains the `property_transactions`
table, which is loaded into
`ringed-griffin-509403-b4.propery_trans1.raw_property_trans`.
The BigQuery table is denormalized so each source field is a separate column.
The ingestion notebook normalizes source column names to BigQuery-safe
snake_case while preserving all row values.
The load replaces the destination on each run, avoiding duplicate rows.

Authenticate with Google Cloud Application Default Credentials, then install
the Meltano plugins and run the transfer from this directory:

```shell
gcloud auth application-default login
uv sync
uv run meltano install
uv run meltano run tap-duckdb target-bigquery
```

The loader uses a denormalized schema and replaces the destination table
contents on each successful run, including replacing an older fixed-JSON
schema.

The Google Cloud identity used must have permission to create the BigQuery
dataset and table and to load data.
