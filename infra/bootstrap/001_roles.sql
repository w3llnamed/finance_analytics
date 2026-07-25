/* =============================================================================
   001_roles.sql
   Layer: bootstrap
   Purpose: Create application roles for the DWH environment.

   Note:
   - dwh_owner already exists (created by POSTGRES_USER in docker-compose).
   - This script creates service roles used by dbt, ingestion pipelines,
     BI tools, and developers.
   ============================================================================= */


/* -----------------------------------------------------------------------------
   DBT runner role
   Used by dbt to build transformation layers (stg, core, dm)
----------------------------------------------------------------------------- */

DO
$$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'dbt_runner'
    ) THEN
        CREATE ROLE dbt_runner LOGIN;
    END IF;
END
$$;

COMMENT ON ROLE dbt_runner IS
'Service role used by dbt to build data transformation models.';



/* -----------------------------------------------------------------------------
   Ingestion role
   Used by ingestion pipelines to write data to raw layer
----------------------------------------------------------------------------- */

DO
$$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'ingestion_user'
    ) THEN
        CREATE ROLE ingestion_user LOGIN;
    END IF;
END
$$;

COMMENT ON ROLE ingestion_user IS
'Service role used by ingestion pipelines to load data into raw schema.';



/* -----------------------------------------------------------------------------
   BI role
   Used by BI tools (Superset, dashboards)
----------------------------------------------------------------------------- */

DO
$$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'bi_user'
    ) THEN
        CREATE ROLE bi_user LOGIN;
    END IF;
END
$$;

COMMENT ON ROLE bi_user IS
'Read-only role used by BI tools such as Superset.';



/* -----------------------------------------------------------------------------
   Demo BI role
   Used by the public Superset demo connection.
   Has read-only access only to demo data marts.
----------------------------------------------------------------------------- */

DO
$$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'bi_demo_user'
    ) THEN
        CREATE ROLE bi_demo_user LOGIN;
    END IF;
END
$$;

COMMENT ON ROLE bi_demo_user IS
'Read-only role used by the public Superset demo connection.';



/* -----------------------------------------------------------------------------
   Developer role
   Used by engineers during development
----------------------------------------------------------------------------- */

DO
$$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'dev_user'
    ) THEN
        CREATE ROLE dev_user LOGIN;
    END IF;
END
$$;

COMMENT ON ROLE dev_user IS
'Role used by developers working with the DWH environment.';
