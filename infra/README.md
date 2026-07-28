# Infrastructure

This directory contains infrastructure configuration for the Finance Analytics Platform.

It includes PostgreSQL bootstrap scripts and Docker-based deployment
configuration for PostgreSQL, Apache Superset, Prefect and Redis.


## Structure

```
infra/
├── bootstrap/            # PostgreSQL initialization scripts
└── deploy/               # Docker Compose, Superset and Prefect deployment configuration
```


## Bootstrap

The `bootstrap/` directory contains scripts that initialize the PostgreSQL database on the first container startup.

PostgreSQL automatically executes files mounted into:

```
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

The `deploy/` directory defines the Docker-based analytics and orchestration environment.

The same Docker Compose stack can be started locally or on a Linux server.
Public server access, DNS, HTTPS, firewall rules and reverse-proxy
configuration are managed separately at the host level.

Current services:

- PostgreSQL 16 — analytical database and layered DWH
- Apache Superset — BI and observability dashboards
- Prefect PostgreSQL — orchestration metadata database
- Redis 7 — Prefect messaging broker and cache
- Prefect Server — orchestration API and user interface
- Prefect Services — background Prefect server services
- Prefect Worker — execution of scheduled ingestion and dbt flows


With the current Docker Compose port bindings, the services are available
from the Docker host at:

- PostgreSQL: `127.0.0.1:5432`
- Superset: `http://127.0.0.1:8088`
- Prefect Server: `http://127.0.0.1:4200`

The loopback bindings prevent direct external access to these services.

For a public server deployment, Superset remains bound to the loopback
interface and is exposed through a reverse proxy with HTTPS.

The Prefect Worker automatically creates the `finance-process-pool` work pool if necessary and executes scheduled pipeline runs.

Prefect uses a dedicated PostgreSQL database for orchestration metadata.

Redis is used as the messaging broker and cache.


## Docker Volumes

The deployment uses persistent Docker volumes:

- `postgres_data` — analytical PostgreSQL database files
- `superset_home` — Superset metadata, users and dashboard configuration
- `prefect_db_data` — Prefect orchestration metadata

The repository source directory on the Docker host is bind-mounted into the
Prefect Worker container at:

```
/opt/finance_analytics
```

These volumes are managed by Docker and are not stored in git.


## First Startup Behavior

Bootstrap scripts are executed only when PostgreSQL initializes an empty data directory.

This means they run on the first startup of a new `postgres_data` volume.

To recreate the complete environment from scratch, all persistent Docker
volumes must be removed.

> [!CAUTION]
> The following operation permanently deletes:
>
> - analytical PostgreSQL data;
> - Superset metadata, users and dashboard configuration;
> - Prefect orchestration metadata.
>
> Do not execute this command unless the data is backed up or intentionally
> disposable.

From the repository root:

```
cd infra/deploy
docker compose down -v
docker compose up -d --build
```


## Superset Image

Superset is built from a custom Docker image based on:

`apache/superset:latest`

Additional Python dependencies are installed:

- `psycopg2-binary`
- `prophet`

`psycopg2-binary` is used for PostgreSQL connectivity from Superset.

`prophet` is installed for analytical forecasting capabilities.


## Prefect Worker Image

The project includes a dedicated Docker image for the Prefect Worker:

`infra/deploy/prefect-worker.Dockerfile`

The worker image contains:

- Python
- Prefect
- dbt
- project dependencies installed from the root requirements.txt
- the runtime environment required by ingestion and orchestration code

The repository source directory is mounted into the running container at:

`/opt/finance_analytics`

The worker executes:

- scheduled Prefect flows
- Python ingestion scripts
- dbt transformations and tests

A separate Python installation or virtual environment on the Docker host is
not required for container-based deployment.


## Environment Variables

Runtime configuration is provided through:

`infra/deploy/.env`

The `.env` file contains credentials and other sensitive runtime values.
It is excluded from version control and must not be committed.

From the repository root, create it from the public template:

```
cp infra/deploy/.env.example infra/deploy/.env
```

Open the created file and replace every placeholder value before starting the
containers.

The public `.env.example` file documents the required variable names but must
not contain real secrets.


## Start Services

Before starting the containers, create:

- `infra/deploy/.env`;
- the required private seed files.

From the repository root, build and start the complete environment:

```
cd infra/deploy
docker compose up -d --build
```

Docker Compose automatically reads `docker-compose.yml` and `.env` from the
current `infra/deploy` directory.

The command:
- builds the custom Superset and Prefect Worker images;
- starts all services in the background.

During the Prefect Worker image build, Python project dependencies are
installed from the root `requirements.txt` file.

Check the service status:

```
docker compose ps
```

Open the local interfaces:

- Superset: `http://localhost:8088`
- Prefect Server: `http://localhost:4200`


## Deploy Prefect Flows

Run the deployment command inside the Prefect Worker container:

```
docker exec -it \
  -w /opt/finance_analytics \
  prefect-worker \
  prefect deploy
```

The command:

- runs inside the `prefect-worker` container;
- uses `/opt/finance_analytics` as the working directory;
- reads the project-level `prefect.yaml`;
- creates or updates the Prefect deployment.

The worker automatically connects to Prefect Server, creates the
`finance-process-pool` work pool if necessary and polls it for scheduled flow
runs.


## Run dbt Manually

Run the full dbt build inside the Prefect Worker container:

```
docker exec -it \
  -w /opt/finance_analytics/dbt \
  prefect-worker \
  dbt build
```

The working directory is set to `/opt/finance_analytics/dbt` because
`dbt_project.yml` is stored in that directory.


## Run Ingestion Manually

Run the ingestion script inside the Prefect Worker container:

```
docker exec -it \
  -w /opt/finance_analytics \
  prefect-worker \
  python ingestion/load_money_flow_from_s3.py
```

## Check Service Status

Run these commands from the `infra/deploy` directory.

Check all containers:
```
docker compose ps
```

View logs from all services:
```
docker compose logs
```

Follow logs continuously:
```
docker compose logs -f
```

Follow logs for one service, for example the Prefect Worker:
```
docker compose logs -f prefect-worker
```

## Stop Services
Run these commands from the `infra/deploy` directory.

Stop and remove the containers while preserving persistent data:
```
docker compose down
```

The named Docker volumes are preserved and will be reused on the next startup.

To stop the containers without removing them:

```
docker compose stop
```

The difference is:

- `stop` stops existing containers without removing them;
- `down` stops and removes containers and the Compose network;
- `down` without `-v` preserves named volumes;
- `down -v` permanently deletes named volumes and their data.
