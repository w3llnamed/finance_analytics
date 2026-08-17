# Ingestion Layer

This directory contains the Python-based ingestion pipelines for loading financial data into the PostgreSQL raw layer: Money Flow transactions from S3-compatible object storage, and official exchange rates from an external FX API.


## Overview

The ingestion process performs:

- discovery of the latest uploaded CSV file
- CSV validation
- raw data loading into PostgreSQL
- ingestion metadata registration
- technical logging and status tracking

The ingestion layer is intentionally lightweight and avoids business transformations.
Business logic is implemented later in dbt models.


## Source System

Source data originates from the Money Flow mobile application.

Users export transactions in CSV format and upload files into S3-compatible object storage (Timeweb S3).


## Ingestion Flow

The ingestion pipeline performs the following steps:

1. Load runtime configuration from `.env`
2. Connect to S3-compatible storage
3. Find the latest uploaded CSV file
4. Download the file into memory
5. Validate CSV structure and required headers
6. Parse rows without applying business logic
7. Load rows into `raw.money_flow`
8. Register ingestion metadata in `infra.ingestion_file_registry`


## Design Principles

The ingestion layer follows several principles:

- source-preserving raw ingestion
- no business transformations during loading
- metadata-driven ingestion tracking
- environment-based configuration
- explicit validation before loading
- separation between ingestion and transformation logic


## Raw Layer Philosophy

The ingestion process stores values as close to the original source format as possible.

Examples:

- dates are initially loaded as text
- numeric values are initially loaded as text without type conversion
- business categorization is not modified
- enrichment is deferred to dbt models

Normalization and business logic are implemented in downstream dbt layers.


## Environment Variables

The ingestion pipeline uses environment variables from:

```
infra/deploy/.env
```

Main configuration groups include:

- S3 connection settings
- PostgreSQL connection settings
- CSV parsing settings
- ingestion source metadata


## CSV Mapping

CSV columns are mapped into `raw.money_flow` columns using an explicit mapping dictionary:

```
CSV_TO_RAW_COLUMN_MAP
```

This keeps ingestion logic deterministic and source-aligned.


## Running Ingestion

The ingestion layer is typically executed through Prefect orchestration.


```
docker exec -it \
  -w /opt/finance_analytics \
  prefect-worker \
  python ingestion/load_money_flow_from_s3.py
```

The script loads the latest available CSV file from S3 and registers ingestion metadata in PostgreSQL.

**The command must be executed after the Docker Compose environment has been started.**


## Metadata Tracking

Each ingestion batch is registered in: `infra.ingestion_file_registry`

Tracked metadata includes:

- source system
- source object
- ingestion status
- file size
- checksum
- row count
- timestamps


## Error Handling

The ingestion pipeline validates:

- required environment variables
- S3 connectivity
- CSV headers
- empty files
- missing required columns

Failures are registered in ingestion metadata tables for observability purposes.


## Exchange Rate Ingestion

A second ingestion script loads official exchange rates from an external API into `raw.exchange_rate`:

```
ingestion/load_exchange_rates.py
```

Unlike Money Flow ingestion, it does not read from S3 and does not depend on `infra.ingestion_file_registry`.


### Source

The only currently supported source is the Bank of Russia (`cbr`).


### Refresh Timing

Ingestion state per source and currency is tracked in `infra.fx_ingestion_state`.

A refresh is skipped unless the source has never been checked, or the last check is at least `FX_REFRESH_INTERVAL_MINUTES` old, so the external API is not called on every scheduled flow run.


### Backfill and Incremental Requests

For a currency requested for the first time, the request window starts `FX_INITIAL_LOOKBACK_DAYS` before the earliest Money Flow transaction date.

For a currency already loaded before, ingestion re-requests the last `FX_RELOAD_LOOKBACK_DAYS` days on each due refresh, to pick up rates the source may publish or correct after the fact.


### Raw Load

Fetched rates are upserted into `raw.exchange_rate`, keyed on `(source, rate_date, base_currency, quote_currency)`. An existing row is updated only when its values actually changed.


### Environment Variables

- `FX_SOURCE` - currently only `cbr` is supported
- `FX_CURRENCIES` - comma-separated currency codes to track
- `FX_REFRESH_INTERVAL_MINUTES`, `FX_INITIAL_LOOKBACK_DAYS`, `FX_RELOAD_LOOKBACK_DAYS`, `FX_HTTP_TIMEOUT_SECONDS`

Configuration is loaded from the same `infra/deploy/.env` file used by Money Flow ingestion.


### Running Exchange Rate Ingestion

```
docker exec -it \
  -w /opt/finance_analytics \
  prefect-worker \
  python ingestion/load_exchange_rates.py
```


## Orchestration

The ingestion layer is normally executed by Prefect flow.

Prefect is responsible for:

- scheduling pipeline runs
- triggering the ingestion script
- executing downstream dbt transformations after successful ingestion
- recording flow execution status and logs

Duplicate file detection and ingestion idempotency are implemented inside the
ingestion layer using `infra.ingestion_file_registry`.

Direct execution of the ingestion script remains available for development and
debugging.

For more details, see `orchestration/README.md`
