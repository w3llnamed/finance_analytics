# Demo Data Mart

This directory contains the optional anonymized data mart used for public
dashboard demonstration.

The demo branch is disabled by default and is included in the dbt project only
when the following environment variable is configured:

```
DBT_ENABLE_DEMO=True
```

When `DBT_ENABLE_DEMO=False`, the models in this directory and the related
singular data tests are excluded from the dbt dependency graph.


## Dependencies

The demo mart is built from the canonical transaction model and additionally
requires:

- `dbt/seeds/private/dim_accounts_demo.csv`
- `dbt/seeds/private/category_mapping_demo.csv`

`dim_accounts_demo.csv` contains anonymized account names and is included in
version control.

`category_mapping_demo.csv` contains mappings from real categories to demo
categories together with amount masking parameters. It is excluded from
version control because it is derived from private financial data.


## Anonymization

The demo mart:

- replaces real account names with demo account names
- replaces real categories and parent categories with demo mappings
- adjusts amounts using category-level masking coefficients
- removes transaction tags and notes
- preserves transaction types and analytical flags

The model does not fall back to real category values when a mapping is missing.

Incomplete or ambiguous mappings are treated as build errors by the singular
data tests stored in:

`dbt/tests/demo`
