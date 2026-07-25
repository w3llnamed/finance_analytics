# Private Seeds

This directory contains private dbt seeds required to build the project with real account metadata.

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

## Demo Seed Dependencies

The public demo dashboard depends on three seeds:

```text
dbt/seeds/private/dim_accounts.csv
dbt/seeds/demo/dim_accounts_demo.csv
dbt/seeds/demo/category_mapping.csv
```

`dim_accounts.csv` is a private seed containing the real account definitions used by the main data models.

`dim_accounts_demo.csv` is a public seed containing anonymized account names. Demo accounts are linked to real accounts through `account_id`.

`category_mapping.csv` is a public seed containing mappings from real transaction categories to anonymized demo categories, together with category-level amount masking parameters.

The demo models first identify real accounts and categories and then replace them with the corresponding public demo values. For this reason, the private `dim_accounts.csv` file is still required even when only the demo dashboard is being reproduced.

The public demo seeds are included in version control and normally do not need to be changed. However, `dim_accounts_demo.csv` must remain consistent with the account identifiers defined in the local private seed.

## Build Requirements

A full dbt build cannot complete without a local `dim_accounts.csv` file.

The private account seed is used by core models, demo models and data tests. The public `dim_accounts_demo.csv` and `category_mapping.csv` seeds provide anonymization rules for the demo layer but do not replace the private account definitions.
