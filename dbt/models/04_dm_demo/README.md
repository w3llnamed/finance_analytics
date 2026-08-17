# Demo Data Marts

This directory contains the optional anonymized data marts used for public dashboard demonstration.

The demo branch is disabled by default and is included in the dbt project only
when the following environment variable is configured:

```
DBT_ENABLE_DEMO=True
```

When `DBT_ENABLE_DEMO=False`, the models in this directory and the related singular data tests are excluded from the dbt dependency graph.


## Dependencies

The demo marts are built from the canonical transaction model and canonical exchange rates, and additionally require:

- `dbt/seeds/private/dim_accounts_demo.csv`
- `dbt/seeds/private/category_mapping_demo.csv`

`dim_accounts_demo.csv` contains anonymized account names and is included in version control.

`category_mapping_demo.csv` contains mappings from real categories to demo categories together with amount masking parameters.
It is excluded from version control because it is derived from private financial data.


## Anonymization

The demo marts:

- replace real account names with demo account names
- replace real categories and parent categories with demo mappings
- adjust amounts using category-level masking coefficients
- remove transaction tags and notes
- preserve transaction types and analytical flags
- convert masked amounts into a selectable target currency using historical exchange rates

A second demo mart, `dm_demo__account_balance_demo`, represents account balance snapshots rather than transactions. It applies the same account and amount masking rules per transaction before building its balance spine, so its numbers stay consistent with `dm_demo__fact_transaction_demo`.

The model does not fall back to real category values when a mapping is missing.

Incomplete or ambiguous mappings are treated as build errors by the singular data tests stored in:

`dbt/tests/demo`
