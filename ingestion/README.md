# Ingestion Layer

This directory contains the Python-based ingestion pipeline for loading financial transaction data from S3-compatible object storage into the PostgreSQL raw layer.


## Overview

The ingestion process performs:

- discovery of the latest uploaded CSV file
- CSV validation
- raw data loading into PostgreSQL
- ingestion metadata registration
- technical logging and status tracking

The ingestion layer is intentionally lightweight and avoids business transformations. Business logic is implemented later in dbt models.


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
- numeric values are preserved from source CSV
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

Each ingestion batch is registered in:

```
infra.ingestion_file_registry
```

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


## Orchestration

The ingestion layer is normally executed by Prefect flows.

Prefect is responsible for:

- scheduling pipeline runs
- triggering the ingestion script
- executing downstream dbt transformations after successful ingestion
- recording flow execution status and logs

Duplicate file detection and ingestion idempotency are implemented inside the
ingestion layer using `infra.ingestion_file_registry`.

Direct execution of the ingestion script remains available for development and
debugging.
