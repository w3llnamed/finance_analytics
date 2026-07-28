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

The project uses dbt seeds for small static reference datasets and user-specific configuration.

Public seeds included in the repository:

- `regular_expense_tag.csv` — tags used to identify regular expenses;
- `reserve_expense_tag.csv` — tags used to identify reserve-related expenses;
- `dim_accounts_demo.csv` — anonymized account names used by the optional demo mart.

The following private seed is required for a standard project deployment:

- `dim_accounts.csv` — user-specific account metadata and opening balances used by the canonical transaction models and balance calculations.

The optional demo environment additionally requires:

- `category_mapping_demo.csv` — mappings from real transaction categories to anonymized demo categories, including category-level amount masking coefficients.

Both `dim_accounts.csv` and `category_mapping_demo.csv` are excluded from version control because they contain mappings derived from personal financial data.

Public templates for the private seed files are available in:

```
dbt/seeds/private/dim_accounts.csv.example
dbt/seeds/private/category_mapping_demo.csv.example
```

Create the required private account seed before running a standard dbt build:

```
cp dbt/seeds/private/dim_accounts.csv.example \
   dbt/seeds/private/dim_accounts.csv
```

To reproduce the optional demo environment, also create the private demo category mapping:
```
cp dbt/seeds/private/category_mapping_demo.csv.example \
   dbt/seeds/private/category_mapping_demo.csv
```

Then replace the example rows in both files with the required local values.

The public `dim_accounts_demo.csv` seed is included in version control and normally does not need to be modified. However, its account_id values must remain consistent with the account identifiers defined in the local private `dim_accounts.csv` seed.

Seeds are loaded into the seed schema.


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

The project is designed to execute dbt inside the running `prefect-worker`
container.

The container already includes:

- Python;
- dbt;
- all project dependencies;
- the mounted project source code.

The working directory must be set to the dbt project directory because
`dbt_project.yml` is located in:

```
/opt/finance_analytics/dbt
```

### Install dbt Packages

Install package dependencies defined in `packages.yml`:

```
docker exec -it \
  -w /opt/finance_analytics/dbt \
  prefect-worker \
  dbt deps
```

### Build the Entire Project

Run models, seeds, snapshots (if configured) and tests:

```
docker exec -it \
  -w /opt/finance_analytics/dbt \
  prefect-worker \
  dbt build
```

### Run Models Only

```
docker exec -it \
  -w /opt/finance_analytics/dbt \
  prefect-worker \
  dbt run
```

### Run Tests Only

```
docker exec -it \
  -w /opt/finance_analytics/dbt \
  prefect-worker \
  dbt test
```

### Generate Documentation

Generate the documentation artifacts:

```
docker exec -it \
  -w /opt/finance_analytics/dbt \
  prefect-worker \
  dbt docs generate
```

The generated documentation is written to:

```
dbt/target/
```

Open the generated documentation in a web browser:

```
dbt/target/index.html
```

A separate Python installation or virtual environment on the Docker host is
not required when dbt is executed inside the Prefect Worker container.
