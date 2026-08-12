# dbt Project

This directory contains the dbt project for the Finance Analytics Platform.

dbt is responsible for transforming raw Money Flow transactions loaded into PostgreSQL into normalized staging models, canonical core entities, analytical marts and observability tables.


## Layered Architecture

The project follows a layered DWH structure:

- `00_sources` - dbt source definitions for raw and infra tables
- `01_stg` - technically normalized source data from the latest successful ingestion batch
- `02_core` - canonical business entities with unified transaction logic, transfer expansion and dimensional enrichment
- `03_dm` - analytics-ready marts for financial dashboards
- `04_dm_demo` - optional public demo data marts containing anonymized and transformed data
- `90_infra` - observability and platform monitoring models


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

- `regular_expense_tag.csv` - tags used to identify regular expenses
- `reserve_expense_tag.csv` - tags used to identify reserve-related expenses
- `dim_accounts_demo.csv` - anonymized account names used by the optional demo mart

The `regular_expense_tag.csv` and `reserve_expense_tag.csv` seeds define the source transaction tags used to classify expenses as regular or reserve-related.

Transactions are assigned to the corresponding analytical groups only when their Money Flow tags match a value from the relevant seed.

If these tags are not assigned to transactions in the source application, the corresponding dashboard filters cannot identify those transactions as
regular or reserve-related expenses.

The following private seed is required for a standard project deployment:

- `dim_accounts.csv` - user-specific account metadata and opening balances used by the canonical transaction models and balance calculations.

The optional demo environment additionally requires:

- `category_mapping_demo.csv` - mappings from real transaction categories to anonymized demo categories, including category-level amount masking coefficients.

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

The public `dim_accounts_demo.csv` seed is included in version control and normally does not need to be modified.
However, its account_id values must remain consistent with the account identifiers defined in the local private `dim_accounts.csv` seed.

Seeds are loaded into the seed schema.


## Optional Demo Configuration

The demo branch is controlled through the following environment variable:

```
DBT_ENABLE_DEMO
```

The default configuration is:

```
DBT_ENABLE_DEMO=False
```

With this value:

- models in `models/04_dm_demo` are disabled
- singular data tests in `tests/demo` are disabled
- `category_mapping_demo.csv` is not required
- the standard private warehouse can be built with a complete dbt build

To enable the anonymized demo branch, set:

```
DBT_ENABLE_DEMO=True
```

The value uses capitalized True and False because it is converted to a boolean by the dbt project configuration.

When the demo branch is enabled:

- `category_mapping_demo.csv` must exist
- `dm_demo` models are included in the dbt dependency graph
- demo-specific data tests are executed
- missing or invalid category mappings cause the dbt build to fail



## Tests

The project uses generic data tests and custom singular data tests.

Test severity is configured by layer:

- `stg` - warning
- `core` - error
- `dm` - warning
- `dm_demo` - warning
- `infra` - warning

The `core` layer has stricter validation because it represents the canonical business layer used by downstream marts.

Demo-specific anonymization tests are stored in:

```
tests/demo
```

These tests are enabled only when:

```
DBT_ENABLE_DEMO=True
```

They use error severity because incomplete or ambiguous mappings can produce an invalid anonymized dataset.

The demo tests validate:

- required values in category_mapping_demo
- uniqueness of mappings for real category combinations
- coverage of categories used by the canonical transaction model

Each singular test returns invalid rows and passes only when its query returns no records.


## Macros

Custom macros are used for schema generation and observability logging:

- `macro__generate_schema_name.sql` - custom schema naming logic
- `macro__log_test_results_to_infra.sql` - writes dbt test results into infra tables
- `macro__log_model_runs_to_infra.sql` - writes dbt model run metadata into infra tables


## Observability

The project logs dbt execution metadata into the `infra` schema using `on-run-end` hooks:

```
on-run-end:
  - "{{ log_test_results_to_infra() }}"
  - "{{ log_model_runs_to_infra() }}"
```

This makes dbt runs and test results available for monitoring in Superset dashboards.


## Running dbt

The project is designed to execute dbt inside the running `prefect-worker`
container.

The container already includes:

- Python
- dbt
- all project dependencies
- the mounted project source code

The working directory must be set to the dbt project directory because `dbt_project.yml` is located in:

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
