# Singapore Private Residential Property Transactions — Data Pipeline

NTU SCTP Module 2 group project (Group 5).

A five-stage batch pipeline that takes 19 raw CSV extracts of Singapore private
residential property transactions, loads them into BigQuery, models them as a
star schema with dbt, validates them with two independent test layers, and
answers four analytical questions in a Jupyter notebook.

---

## Pipeline

```
  Data/Raw_data/*.csv            19 files, 170,224 rows, 32 MB
         │
         │  1a  ingestion — pandas + DuckDB
         │      read as TEXT, normalise column names to snake_case
         ▼
  Output/property_trans.db       DuckDB, 170,224 rows × 21 columns, 12 MB
         │
         │  1b  extraction/load — Meltano
         │      tap-duckdb ──> target-bigquery   (denormalized, overwrite)
         ▼
  BigQuery  propery_trans1.raw_property_trans    all columns STRING
         │
         │  2+3  transform — dbt
         │       stage ──> dimensions ──> fact
         ▼
  BigQuery star schema           4 models, 20 data tests
         │
         ├── 4  data quality — Great Expectations, 15 expectations
         │
         └── 5  analysis — pandas + matplotlib, 4 questions
```

Each stage writes a persisted artefact, so any stage can be re-run on its own
without re-running the ones before it.

---

## Repository layout

| Path | Stage | Contents |
|---|---|---|
| `Data/Raw_data/` | source | 19 `ResidentialTransaction*.csv` extracts |
| `1a_data_ingestion/notebook/pipeline.ipynb` | 1a | CSV → DuckDB ingestion |
| `Output/property_trans.db` | 1a output | DuckDB database |
| `1b_data_extraction/` | 1b | Meltano project (`tap-duckdb` → `target-bigquery`) |
| `2n3_data_transform/` | 2+3 | dbt project (`property_transaction_warehouse`) |
| `4_data_quality_test_GX/GX_data_test.ipynb` | 4 | Great Expectations suite |
| `5_data_analysis_pathon/data_analysis.ipynb` | 5 | Analysis and charts |
| `Module 2 Assignment Project.pdf` | — | Assignment brief |

---

## Stage 1a — Ingestion (CSV → DuckDB)

`1a_data_ingestion/notebook/pipeline.ipynb`

Concatenates the 19 CSVs into a single `property_transactions` table in
`Output/property_trans.db`.

Two decisions worth noting:

- **Every column is read as text.** Postal codes, postal districts and postal
  sectors have leading zeroes that any numeric type would silently destroy.
  Typing happens later, in SQL, where it is visible and testable.
- **Encoding is detected per file.** Each file is decoded as UTF-8, falling back
  to `cp1252` when that fails, rather than assuming one encoding for all 19.

Column names are normalised to BigQuery-safe `snake_case`
(`Unit Price ($ PSF)` → `unit_price_psf`). No row values are modified.

The notebook re-opens the database read-only at the end and asserts the
persisted row count equals the ingested row count, so a partial write fails
loudly rather than passing silently.

## Stage 1b — Extraction / load (DuckDB → BigQuery)

`1b_data_extraction/`

A Meltano project moving the DuckDB table into BigQuery:

```
tap-duckdb (meltanolabs)  ──>  target-bigquery (z3z1ma)
  path: ../Output/property_trans.db   project: ringed-griffin-509403-b4
                                      dataset: propery_trans1
                                      table:   raw_property_trans
```

Loader configuration, from `meltano.yml`:

- `denormalized: true` — each source field becomes its own BigQuery column,
  rather than a single JSON blob.
- `overwrite: true` — the destination is replaced on every run. Without this,
  a second run appends and silently doubles the data.

```bash
cd 1b_data_extraction
gcloud auth application-default login
uv sync
uv run meltano install
uv run meltano run tap-duckdb target-bigquery
```

## Stages 2 and 3 — Transform (dbt star schema)

`2n3_data_transform/` — dbt project `property_transaction_warehouse`,
all models materialised as tables.

```
                 raw_property_trans          (source, all columns STRING)
                          │
                          ▼
              stg_property_transactions      staging: trim, upper, SAFE_CAST,
                          │                  SAFE.PARSE_DATE, '-' and '' → NULL
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
    dim_project     dim_location     fact_transaction
    project_key     location_key     transaction_key, project_key, location_key,
                                     sale_date and the measures
```

**Staging (`stg_property_transactions`)** does all the cleaning in one place:
`TRIM` and `UPPER` on text, whitespace collapsed inside names and addresses,
`SAFE_CAST` for numerics after stripping thousands separators,
`SAFE.PARSE_DATE('%d %b %Y', ...)` for the sale date. A value that cannot be
parsed becomes `NULL` rather than failing the run — the `not_null` tests then
report how much failed, instead of the pipeline stopping at the first bad row.

**Dimensions** are `SELECT DISTINCT` over their attributes with a
`FARM_FINGERPRINT(TO_JSON_STRING(STRUCT(...)))` surrogate key:

| Model | Grain | Key built from |
|---|---|---|
| `dim_project` | one row per distinct project | `project_name`, `property_type`, `tenure`, `completion_date` |
| `dim_location` | one row per distinct location | `address`, `postal_code`, `postal_district`, `postal_sector`, `planning_region`, `planning_area` |

**Fact (`fact_transaction`)** keeps the source-row grain — one fact row per raw
transaction. Source rows are *not* deduplicated, because the dataset has no
transaction identifier and two genuinely identical transactions cannot be
distinguished from an accidental duplicate. To keep `transaction_key` unique
anyway, the hash includes a `ROW_NUMBER()`, so identical rows still receive
distinct keys.

Measures use a `valid_*` pattern: a non-positive price or area becomes `NULL`
rather than being dropped, so the row survives and the bad measure is visible
to the tests.

Two derived columns act as a built-in reconciliation check:

```
new_trans_price       = area_sqft × unit_price_psf
percentage_difference = (new_trans_price − transacted_price) / transacted_price
```

If the dataset is internally consistent, `percentage_difference` should sit near
zero. Great Expectations asserts it stays within ±2.5%.

```bash
cd 2n3_data_transform
gcloud auth application-default login
uv sync
DBT_PROFILES_DIR=. uv run dbt debug
DBT_PROFILES_DIR=. uv run dbt build
```

Project and dataset can be overridden without editing any file:

```bash
BIGQUERY_PROJECT=your-gcp-project \
BIGQUERY_DATASET=your_dataset \
DBT_PROFILES_DIR=. uv run dbt build
```

## Stage 4 — Data quality (Great Expectations)

`4_data_quality_test_GX/GX_data_test.ipynb`

A second, independent validation layer reading `fact_transaction` into pandas.
It exists because the dbt tests and the models share assumptions; a separate
tool with separately written rules can catch what both of those miss.

The suite holds **15 expectations**:

| Expectation | Columns |
|---|---|
| `ExpectColumnToExist` | `transaction_key` |
| `ExpectColumnValuesToNotBeNull` | `transaction_key`, `sale_date` |
| `ExpectColumnValuesToBeUnique` | `transaction_key` |
| `ExpectColumnValuesToBeBetween` (> 0) | `transacted_price`, `nett_price`, `area_sqft`, `area_sqm`, `unit_price_psf`, `unit_price_psm`, `new_trans_price`, `number_of_units` |
| `ExpectColumnValuesToBeBetween` (0 – 75,000,000) | `transacted_price` |
| `ExpectColumnValuesToBeBetween` (−0.025 – 0.025) | `percentage_difference` |
| `ExpectColumnValuesToBeBetween` (1 – 1) | `number_of_units` |

## Stage 5 — Analysis

`5_data_analysis_pathon/data_analysis.ipynb`

Reads the fact and dimension tables and answers four questions:

1. Unit price and transaction volume over time (monthly **median** `unit_price_psf`)
2. Top 10 projects by transaction count
3. Median unit price by planning region
4. Purchaser group buying differences (HDB vs private address indicator)

Median rather than mean throughout: property prices are heavily right-skewed,
and a handful of very high-value transactions pull a mean away from what a
typical transaction looks like.

---

## Data quality strategy

Two layers, deliberately written against different assumptions:

| | dbt tests | Great Expectations |
|---|---|---|
| Count | 20 data tests | 15 expectations |
| Runs | inside `dbt build`, against BigQuery | separately, on a pandas dataframe |
| Tests | schema integrity, keys, referential integrity, accepted values | value ranges, business plausibility, reconciliation |
| Blocks the build | yes | no — reports |

dbt covers structure: `unique` and `not_null` on every surrogate key,
`relationships` from the fact to each dimension, and `accepted_values` on the
four categorical columns (`type_of_sale`, `property_type`, `planning_region`,
`purchaser_address_indicator`). A singular test,
`tests/fact_transaction_valid_measures.sql`, asserts no measure is ≤ 0.

Great Expectations covers plausibility: a transacted price above S$75 m, a
negative area, or a `percentage_difference` beyond ±2.5% is structurally valid
SQL but almost certainly wrong data.

---

## Verified figures

Every number in this README was produced by a command run against this
repository, not estimated:

| Figure | Value | How it was obtained |
|---|---|---|
| Raw CSV files | 19 | `ls Data/Raw_data/*.csv \| wc -l` |
| Raw data rows | 170,224 | Python `csv` parser, headers excluded |
| Raw data size | 32 MB | `du -sh Data/Raw_data/` |
| DuckDB rows | 170,224 | `SELECT COUNT(*) FROM property_transactions` |
| DuckDB columns | 21 | `DESCRIBE property_transactions` |
| dbt models | 4 | `dbt ls` |
| dbt data tests | 20 | `dbt ls --resource-type test` |
| GX expectations | 15 | suite constructed and `len(suite.expectations)` |

The raw CSV count and the DuckDB count match exactly, which confirms stage 1a
loses no rows.

---

## Credentials

No credentials are stored in this repository. BigQuery access uses Application
Default Credentials (`profiles.yml` sets `method: oauth`), so each team member
authenticates with their own Google account:

```bash
gcloud auth application-default login
```

`1b_data_extraction/.gitignore` excludes `.env`, `.meltano/`, `meltano.db`,
`logs/` and `run/`.

---

## Team

| Contributor | GitHub |
|---|---|
| Jen Ho | `Jenho88` |
| Winnie | `yummywhitebread-beep` |

Development history: 10 commits between 10 and 15 October 2026, developed on the
`JenHo` branch and merged to `main` via pull request #1.
