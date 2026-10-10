# Property transaction data warehouse

This dbt project transforms
`ringed-griffin-509403-b4.propery_trans1.raw_property_trans` into BigQuery
dimension and fact tables in the same dataset:

- `dim_date`: calendar attributes for sale dates.
- `dim_location`: deduplicated address and planning-area attributes.
- `dim_project`: deduplicated project, property, tenure, and completion attributes.
- `fact_transaction`: one row per raw transaction, with typed measures and dimension keys.

The staging model trims and standardizes text, converts comma-formatted numeric
values safely, parses sale dates, and treats `-` and blank values as null.
Unparseable numeric values become null instead of failing the warehouse run.
Transactions are retained at source-row grain; identical-looking source rows
are not removed because the source has no verified transaction identifier.

## Run the pipeline

From this directory:

```shell
gcloud auth application-default login
uv sync
DBT_PROFILES_DIR=. uv run dbt debug
DBT_PROFILES_DIR=. uv run dbt build
```

`dbt build` creates or replaces the modeled tables in `propery_trans1`.
The Google Cloud account needs permission to run BigQuery jobs and create or
replace tables in that dataset.

Override the project or dataset without editing the project files:

```shell
BIGQUERY_PROJECT=your-gcp-project \
BIGQUERY_DATASET=your_bigquery_dataset \
DBT_PROFILES_DIR=. uv run dbt build
```
