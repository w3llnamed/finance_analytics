# CI Test Fixtures

This directory contains synthetic data and configuration used by the GitHub
Actions CI environment.

The files in this directory are intended only for automated repository
validation and are not used by the production platform.


## Synthetic Raw Data

The file:

```
raw_money_flow.sql
```

creates the minimum synthetic source state required for a complete dbt build.

It inserts:

- a successful synthetic ingestion record into `infra.ingestion_file_registry`
- synthetic Money Flow transactions into `raw.money_flow`

The fixture is designed to exercise the main transformation paths without
using real financial data.

The synthetic dataset includes representative transaction types required by
the current dbt models and tests.

The fixture runs only against the temporary PostgreSQL database created by CI.


## Private Seed

The required private account seed is not stored in this directory.

During CI, the workflow creates it from:

```
dbt/seeds/private/dim_accounts.csv.example
```

and writes the temporary file to:

```
dbt/seeds/private/dim_accounts.csv
```

This allows the dbt project to preserve the same private-seed contract used by
normal deployments without exposing real account metadata.


## SQLFluff Configuration

The file:

```
sqlfluff.cfg
```

contains CI-specific SQLFluff configuration.

The main SQLFluff configuration remains in the repository-level `.sqlfluff` file.

The CI override configures the dbt templater to use:

```
target = ci
```

This ensures that SQLFluff parses and compiles dbt models using the same
dedicated target used by the CI dbt checks.


## Data Isolation

All CI data is synthetic.

The CI fixtures must not contain:

- real financial transactions
- real account names
- production credentials
- production S3 credentials
- other private runtime configuration

Production data and private seeds are not required for CI execution.


## Maintenance

Update the CI fixtures when changes to the dbt project introduce new mandatory
source structures, reference data or error-level tests that cannot be exercised
by the existing synthetic dataset.

Fixtures should remain as small as possible while still covering the required
transformation and data-quality paths.

CI-specific configuration should remain in this directory when it is required
only by automated validation and is not part of the normal runtime
configuration.
