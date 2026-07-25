# Infrastructure

This directory contains infrastructure configuration for the local Finance Analytics Platform environment.

It includes PostgreSQL bootstrap scripts and Docker-based deployment configuration for PostgreSQL and Apache Superset.


## Structure

```text
infra/
├── bootstrap/            # PostgreSQL initialization scripts
└── deploy/               # Docker Compose, Superset and Prefect deployment configuration
```


## Bootstrap

The `bootstrap/` directory contains scripts that initialize the PostgreSQL database on the first container startup.

PostgreSQL automatically executes files mounted into:

```text
/docker-entrypoint-initdb.d
```

Current bootstrap scripts:

- `001_roles.sql` — creates database roles
- `002_role_passwords.sh` — applies role passwords from environment variables
- `003_db_settings.sql` — configures database-level settings
- `004_extensions.sql` — enables required PostgreSQL extensions
- `005_schemas.sql` — creates DWH schemas
- `006_grants.sql` — grants privileges to project roles
- `010_raw_tables.sql` — creates raw ingestion tables
- `011_raw_comments.sql` — documents raw tables and columns
- `012_infra_tables.sql` — creates infra monitoring tables
- `013_infra_comments.sql` — documents infra tables and columns


## Deployment

The `deploy/` directory defines the local Docker-based analytics and orchestration environment.

Current services:

- PostgreSQL 16 — analytical database and layered DWH
- Apache Superset — BI and observability dashboards
- Prefect PostgreSQL — orchestration metadata database
- Redis 7 — Prefect messaging broker and cache
- Prefect Server — orchestration API and user interface
- Prefect Services — background Prefect server services
- Prefect Worker — execution of scheduled ingestion and dbt flows

The analytical PostgreSQL database is exposed only on localhost:

```text
127.0.0.1:5432
```

Superset is exposed on:

```text
http://localhost:8088
```

Prefect Server is exposed on:

```text
http://localhost:4200
```

The Prefect Worker automatically creates the `finance-process-pool` work pool if necessary and executes scheduled pipeline runs.

Prefect uses a dedicated PostgreSQL database for orchestration metadata.

Redis is used as the messaging broker and cache.


## Docker Volumes

The deployment uses persistent Docker volumes:

- `postgres_data` — analytical PostgreSQL database files
- `superset_home` — Superset metadata, users and dashboard configuration
- `prefect_db_data` — Prefect orchestration metadata

The project source code is mounted into the Prefect Worker container from the local repository.

These volumes are managed by Docker and are not stored in git.


## First Startup Behavior

Bootstrap scripts are executed only when PostgreSQL initializes an empty data directory.

This means they run on the first startup of a new `postgres_data` volume.

To recreate the database from scratch:

```bash
cd infra/deploy
docker compose down -v
docker compose up -d
```

Warning: `docker compose down -v` permanently removes:

- analytical PostgreSQL data;
- Superset metadata, users and dashboard configuration;
- Prefect orchestration metadata.


## Superset Image

Superset is built from a custom Docker image based on:

```dockerfile
apache/superset:latest
```

Additional Python dependencies are installed:

- `psycopg2-binary`
- `prophet`

`psycopg2-binary` is used for PostgreSQL connectivity from Superset.

`prophet` is installed for analytical forecasting capabilities.


## Prefect Worker Image

The project includes a dedicated Docker image for Prefect workers:

```text
prefect-worker.Dockerfile
```

The image contains all dependencies required to execute:

* Prefect flows;
* ingestion scripts;
* dbt commands.

The worker is responsible for running scheduled orchestration workflows defined in the project.


## Environment Variables

Runtime configuration is provided through:

```text
infra/deploy/.env
```

The `.env` file is not stored in git.

Use the example file as a template:

```bash
cp infra/deploy/.env.example infra/deploy/.env
```


## Start Services

Start the complete local environment:

```bash
cd infra/deploy
docker compose up -d
```

Check service status:

```bash
docker compose ps
```

Deploy Prefect flows:

```bash
cd ../..
prefect deploy
```

The containerized Prefect Worker automatically connects to Prefect Server, creates the `finance-process-pool` work pool if it does not already exist and starts polling it for scheduled flow runs.


## Check Service Status

Check running services:

```bash
docker compose ps
```

View logs:

```bash
docker compose logs
```

Follow logs:

```bash
docker compose logs -f
```


## Stop Services

Stop all Docker services while preserving persistent data:

```bash
docker compose down
```
