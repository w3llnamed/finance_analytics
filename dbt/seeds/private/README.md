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

The project optionally includes an anonymized demo environment for public dashboard deployment.

Reproducing the demo environment additionally requires the following seed files:

`dbt/seeds/private/dim_accounts_demo.csv`
`dbt/seeds/private/category_mapping_demo.csv`


`dim_accounts.csv` is a private seed containing the real account metadata and opening balances used by the canonical analytical models.

`dim_accounts_demo.csv` is a public seed containing anonymized account names. Demo accounts are linked to real accounts through `account_id`.

`category_mapping_demo.csv` is a private seed containing mappings from real transaction categories to anonymized demo categories, together with category-level amount masking parameters.

The demo models are built from the same canonical transaction pipeline as the main analytical mart. They first use the real account metadata from the private seed and then replace
sensitive attributes using the demo seed files.

`dim_accounts_demo.csv` is included in version control.
`category_mapping_demo.csv` is excluded from version control because it contains mappings derived from real transaction categories. A public `.example` template is provided for creating the local file.


## Build Requirements

A standard private deployment requires only the local `dim_accounts.csv` file.

The optional demo environment additionally requires the demo seed files described above.

The demo seeds are required only when reproducing the optional anonymized demo environment.

The private `dim_accounts.csv` seed is required by the core analytical models and their associated data tests.
