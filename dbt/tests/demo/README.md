# Demo Data Tests

This directory contains singular data tests for the optional demo models
documented in:

```
dbt/models/04_dm_demo/README.md
```

The tests are enabled only when `DBT_ENABLE_DEMO=True` and use error
severity because incomplete mappings make the anonymized mart invalid.
