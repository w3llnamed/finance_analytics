# Continuous Integration

This directory contains the GitHub Actions workflows used to validate the Finance Analytics Platform.

The main CI workflow is:

```
.github/workflows/ci.yml
```


## Purpose

The CI pipeline validates repository changes in an isolated environment before they are accepted into the main branch.

The workflow checks:

- repository formatting and static validation
- Docker Compose configuration
- Superset deployment configuration
- Prefect runtime compatibility
- Prefect flow availability
- SQL style and dbt templating
- PostgreSQL and dbt connectivity
- complete dbt model and test execution

The CI environment uses synthetic data and does not require production credentials or production financial data.


## Triggers

The workflow runs automatically:

- on pushes to `main`
- on pull requests targeting `main`

It can also be started manually through GitHub Actions using `workflow_dispatch`.


## Workflow

The CI job runs on Ubuntu 22.04 LTS with Python 3.12.

The workflow performs the following stages.


### Repository Checks

The repository is checked out and Python dependencies are installed from:

```
requirements.txt
```

The configured pre-commit hooks are then executed against all repository files.

These checks include repository-level formatting and YAML validation.


### CI Environment Preparation

The workflow creates a temporary runtime environment from:

```
infra/deploy/.env.example
```

No production `.env` file or production credentials are used.

Docker Compose configuration is validated before any project containers are started.


### Superset Checks

Superset is validated without starting the complete Superset runtime.

The CI pipeline performs:

- Dockerfile validation with Docker Buildx
- Python syntax validation for `superset_config.py`

These checks verify the deployment configuration while keeping the CI pipeline lightweight.


### Prefect Smoke Test

The Prefect environment is started through Docker Compose.

The CI pipeline starts the Prefect components required by the Worker,
including:

- Prefect PostgreSQL
- Redis
- Prefect Server
- Prefect Services
- Prefect Worker

The Prefect Worker image is built from the project Dockerfile.

The image build installs the repository Python dependencies and runs:

```
pip check
```

This verifies that the resulting Python environment does not contain broken package dependencies.

After startup, CI verifies that:

- the orchestration flow can be imported inside the real Worker container
- the `finance-process-pool` work pool exists
- the work pool reaches the `READY` state

The readiness check retries for a limited period because the Worker may require
several seconds after container startup to register with Prefect Server.


### PostgreSQL and dbt

A separate PostgreSQL container is started for dbt validation.

The workflow prepares the dbt profile from:

```
dbt/profiles.yml.example
```

and uses the dedicated `ci` target.

Database connection variables are derived from the temporary CI environment.

The connection is validated with:

```
dbt debug --target ci
```


### Private Seed Preparation

The real private account seed is never used in CI.

Instead, the workflow creates the required seed from:

```
dbt/seeds/private/dim_accounts.csv.example
```

The generated file exists only inside the temporary GitHub Actions runner.


### SQLFluff

SQL models are linted with SQLFluff using the dbt templater.

CI-specific SQLFluff configuration is stored in:

```
tests/ci/sqlfluff.cfg
```

The configuration forces SQLFluff to compile the dbt project using the `ci` target.


### Synthetic Source Data

Synthetic Money Flow data is loaded into the temporary PostgreSQL database from:

```
tests/ci/raw_money_flow.sql
```

The fixture provides the minimum source and ingestion-registry state required
for the dbt project to execute against realistic input structures.


### dbt Build

The final functional validation is:

```
dbt build --target ci
```

This executes the dbt project against the synthetic CI environment, including:

- seeds
- models
- data tests
- project hooks

A failing error-level dbt test or model causes the CI workflow to fail.


## Isolation from Production

The CI environment is isolated from the production platform.

CI does not:

- access the production PostgreSQL database
- use production private seeds
- use production credentials
- read source files from the production S3 bucket
- execute the real ingestion pipeline against S3
- deploy changes to the VPS

S3 integration and production deployment remain outside the scope of the standard CI workflow.


## Execution Controls

The CI workflow uses read-only repository permissions.

The complete CI job has a fixed timeout to prevent indefinitely hanging
executions.

Concurrency control cancels an older in-progress CI run when a newer run for
the same Git reference starts.


## Related Files

```
.github/workflows/ci.yml
dbt/profiles.yml.example
dbt/seeds/private/dim_accounts.csv.example
infra/deploy/.env.example
infra/deploy/docker-compose.yml
infra/deploy/prefect-worker.Dockerfile
requirements.txt
tests/ci/raw_money_flow.sql
tests/ci/sqlfluff.cfg
```
