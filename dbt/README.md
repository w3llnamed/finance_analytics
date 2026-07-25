# dbt Project

This directory contains the dbt project for the Finance Analytics Platform.

dbt is responsible for transforming raw Money Flow transactions loaded into PostgreSQL into normalized staging models, canonical core entities, analytical marts and observability tables.


## Layered Architecture

The project follows a layered DWH structure:

- `00_sources` — dbt source definitions for raw and infra tables
- `01_stg` — technically normalized source data from the latest successful ingestion batch
- `02_core` — canonical business entities with unified transaction logic, transfer expansion and dimensional enrichment
- `03_dm` — analytics-ready marts for financial dashboards
- `04_dm_demo` — public demo data marts containing anonymized and transformed data.
- `90_infra` — observability and platform monitoring models


## Materialization Strategy

Materializations are configured in `dbt_project.yml`:

- `stg` models are materialized as views
- `core` models are materialized as tables
- `dm` models are materialized as tables
- `dm_demo` models are materialized as tables
- `infra` models are materialized as tables

This keeps staging lightweight while persisting business and analytical layers for dashboard performance.


## Seeds

The project uses dbt seeds for small static reference datasets.

Public seeds included in the repository:

- `dim_accounts_demo.csv` — synthetic account data used by the anonymized demo mart;
- `regular_expense_tag.csv` — tags used to identify regular expenses;
- `reserve_expense_tag.csv` — tags used to identify reserve-related expenses.

The following required seeds contain mappings derived from personal financial
data and are therefore excluded from version control:

- `dim_accounts.csv` — account reference data used by the core transaction model;
- `category_mapping.csv` — mapping between real and anonymized demo categories, including amount masking coefficients.

Templates for both files are available in:

`dbt/seeds/private/`

Create the real local files from the templates before running a full dbt build.

Seeds are loaded into the `seed` schema.


## Tests

The project uses both schema tests and custom data tests.

Test severity is configured by layer:

- `stg` — warning
- `core` — error
- `dm` — warning
- `dm_demo` — warning
- `infra` — warning

The `core` layer has stricter validation because it represents the canonical business layer used by downstream marts.


## Macros

Custom macros are used for schema generation and observability logging:

- `macro__generate_schema_name.sql` — custom schema naming logic
- `macro__log_test_results_to_infra.sql` — writes dbt test results into infra tables
- `macro__log_model_runs_to_infra.sql` — writes dbt model run metadata into infra tables


## Observability

The project logs dbt execution metadata into the `infra` schema using `on-run-end` hooks:

```yaml
on-run-end:
  - "{{ log_test_results_to_infra() }}"
  - "{{ log_model_runs_to_infra() }}"
```

This makes dbt runs and test results available for monitoring in Superset dashboards.


## Running dbt

Install dbt dependencies:

```bash
dbt deps
```

Run transformations and tests:

```bash
dbt build
```

Run only models:

```bash
dbt run
```

Run only tests:

```bash
dbt test
```

Generate dbt documentation:

```bash
dbt docs generate
dbt docs serve
```
