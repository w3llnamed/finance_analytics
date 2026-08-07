# Private Seeds

This directory contains private dbt seeds required to build the project with user-specific account metadata and opening balances.

The real seed files are intentionally excluded from version control because they contain account names and attributes derived from personal financial data.


## Required Private File

The following file must be created locally:

```text
dim_accounts.csv
```

A public template is provided:

```text
dim_accounts.csv.example
```

Before running a full dbt build, copy the template:

```bash
cp dbt/seeds/private/dim_accounts.csv.example \
   dbt/seeds/private/dim_accounts.csv
```

Then replace the example rows with the required local account values.


## Optional Demo Environment

The project optionally includes an anonymized demo environment for public
dashboard deployment.

The demo environment is controlled through:

```
DBT_ENABLE_DEMO
```

It is disabled by default:

```
DBT_ENABLE_DEMO=False
```

In this mode:

- only dim_accounts.csv must be created locally
- demo models are excluded from the dbt project
- demo-specific tests are not executed
- category_mapping_demo.csv is not required

To enable the demo environment, set the following value in `infra/deploy/.env:`

```
DBT_ENABLE_DEMO=True
```

The enabled demo environment uses:

`dbt/seeds/private/dim_accounts_demo.csv`
`dbt/seeds/private/category_mapping_demo.csv`

`dim_accounts.csv` contains the real account metadata and opening balances used
by the canonical analytical models.

`dim_accounts_demo.csv` contains anonymized account names. Demo accounts are
linked to real accounts through account_id.

`category_mapping_demo.csv` contains mappings from real transaction categories
to anonymized demo categories together with category-level amount masking
parameters.

The demo models are built from the same canonical transaction pipeline as the
main analytical mart. They use the real account configuration internally and
replace sensitive attributes before publishing the demo mart.

`dim_accounts_demo.csv` is included in version control.

`category_mapping_demo.csv` is excluded from version control because it
contains mappings derived from real transaction categories. A public template
is provided:

`category_mapping_demo.csv.example`


## Build Requirements

A standard private deployment requires:

`dim_accounts.csv`

An enabled demo environment additionally requires:

`category_mapping_demo.csv`

The demo category mapping is validated by singular data tests before the demo
mart is considered valid.

The private `dim_accounts.csv` seed remains required by the core analytical
models and their associated data tests in both configurations.
