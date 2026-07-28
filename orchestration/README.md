# Orchestration Layer

This directory contains Prefect-based workflow orchestration for the Finance Analytics Platform.

The orchestration layer coordinates ingestion and transformation processes while keeping business logic inside ingestion and dbt components.


## Overview

The orchestration layer is responsible for:

- scheduled pipeline execution;
- S3 polling;
- duplicate file detection;
- ingestion triggering;
- dbt execution;
- workflow monitoring and logging.

The orchestration layer does not perform transformations itself. Its role is to coordinate execution of platform components.


## Architecture

Current orchestration flow:

```
Timeweb S3
      │
      ▼
Prefect Flow
      │
      ▼
Check ingestion registry
      │
      ├── File already processed → Exit
      │
      └── New file
              │
              ▼
      Python Ingestion
              │
              ▼
          dbt build
```

The orchestration flow relies on ingestion metadata stored in PostgreSQL.


## Structure

```
orchestration/
├── README.md
└── flows/
    └── money_flow_s3_ingestion_flow.py
```

Project-level deployment configuration is stored in:

```
prefect.yaml
```


## Flow Logic

The current workflow performs the following steps:

1. Connect to S3-compatible object storage.
2. Determine the latest available Money Flow CSV file.
3. Check `infra.ingestion_file_registry`.
4. Verify whether the file has already been processed.
5. Exit if the file already exists in the registry.
6. Execute the ingestion pipeline.
7. Execute dbt transformations and tests.
8. Record execution logs in Prefect.


## Scheduling

Deployments are configured through Prefect.

Current schedule:

```
interval: 300
```

The flow runs every 5 minutes.

Deployment configuration is stored in:

```
prefect.yaml
```


## Deployment

Create or update the deployment from inside the running Prefect Worker
container:

```bash
docker exec -it \
  -w /opt/finance_analytics \
  prefect-worker \
  prefect deploy
```

The deployment configuration is read from the project-level `prefect.yaml`
file.

The Prefect Worker is started automatically as part of the Docker Compose
environment.

It connects to Prefect Server, creates the `finance-process-pool` work pool if
necessary and continuously polls it for scheduled flow runs.


## Docker Integration

Prefect workers are deployed using a dedicated Docker image:

```
infra/deploy/prefect-worker.Dockerfile
```

The image contains:

- Python runtime;
- ingestion dependencies;
- dbt dependencies;
- Prefect runtime.


## Idempotency

The orchestration layer is designed to prevent duplicate processing.

Before executing ingestion, the flow verifies whether the source file has already been registered in:

```
infra.ingestion_file_registry
```

If the file is already registered, the flow exits without loading data or executing dbt.


## Monitoring

Pipeline execution history is available through Prefect.

Typical monitoring information includes:

- flow status;
- execution duration;
- failure logs;
- retry history;
- deployment schedule status.


## Future Improvements

Potential future enhancements:

- Telegram notifications;
- anomaly-based alerting;
- multiple ingestion pipelines;
- event-driven execution;
- data quality gates.
