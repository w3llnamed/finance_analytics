/* =============================================================================
   006_grants.sql
   Layer: bootstrap
   Purpose: Grant schema and object privileges for DWH service roles.
   ============================================================================= */

/* -----------------------------------------------------------------------------
   Database-level privileges
----------------------------------------------------------------------------- */

GRANT CONNECT ON DATABASE finance_analytics TO ingestion_user, dbt_runner, bi_user, bi_demo_user, dev_user;
GRANT TEMP ON DATABASE finance_analytics TO dbt_runner, dev_user;
GRANT CREATE ON DATABASE finance_analytics TO dbt_runner, dev_user;


/* -----------------------------------------------------------------------------
   Schema create grants
----------------------------------------------------------------------------- */

GRANT CREATE ON SCHEMA raw     TO ingestion_user, dev_user;
GRANT CREATE ON SCHEMA stg     TO dbt_runner, dev_user;
GRANT CREATE ON SCHEMA core    TO dbt_runner, dev_user;
GRANT CREATE ON SCHEMA dm      TO dbt_runner, dev_user;
GRANT CREATE ON SCHEMA dm_demo TO dbt_runner, dev_user;
GRANT CREATE ON SCHEMA infra   TO dbt_runner, dev_user;
GRANT CREATE ON SCHEMA seed    TO dbt_runner, dev_user;

/* -----------------------------------------------------------------------------
   Schema usage grants
----------------------------------------------------------------------------- */

GRANT USAGE ON SCHEMA raw     TO ingestion_user, dbt_runner, dev_user;
GRANT USAGE ON SCHEMA stg     TO dbt_runner, dev_user;
GRANT USAGE ON SCHEMA core    TO dbt_runner, dev_user;
GRANT USAGE ON SCHEMA dm      TO dbt_runner, bi_user, dev_user;
GRANT USAGE ON SCHEMA dm_demo TO dbt_runner, bi_demo_user, dev_user;
GRANT USAGE ON SCHEMA infra   TO ingestion_user, dbt_runner, bi_user, dev_user;
GRANT USAGE ON SCHEMA seed    TO dbt_runner, dev_user;


/* -----------------------------------------------------------------------------
   Raw layer access
   - ingestion_user loads source data into raw
   - dbt_runner reads from raw
   - dev_user can inspect and modify during development
----------------------------------------------------------------------------- */

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA raw
TO ingestion_user;

GRANT SELECT ON ALL TABLES IN SCHEMA raw
TO dbt_runner;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA raw
TO dev_user;

GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA raw
TO ingestion_user, dev_user;


/* -----------------------------------------------------------------------------
   STG layer access
   - dbt_runner builds transformation objects
   - dev_user can work with objects during development
----------------------------------------------------------------------------- */

GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
ON ALL TABLES IN SCHEMA stg
TO dbt_runner, dev_user;

GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA stg
TO dbt_runner, dev_user;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA stg
TO dbt_runner, dev_user;


/* -----------------------------------------------------------------------------
   CORE layer access
----------------------------------------------------------------------------- */

GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
ON ALL TABLES IN SCHEMA core
TO dbt_runner, dev_user;

GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA core
TO dbt_runner, dev_user;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA core
TO dbt_runner, dev_user;


/* -----------------------------------------------------------------------------
   DM layer access
   - dbt_runner builds marts
   - bi_user reads marts
   - dev_user has development access
----------------------------------------------------------------------------- */

GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
ON ALL TABLES IN SCHEMA dm
TO dbt_runner, dev_user;

GRANT SELECT ON ALL TABLES IN SCHEMA dm
TO bi_user;

GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA dm
TO dbt_runner, dev_user;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA dm
TO dbt_runner, dev_user;


/* -----------------------------------------------------------------------------
   DM_DEMO layer access
   - dbt_runner builds public demo marts
   - bi_demo_user reads public demo marts
   - dev_user has development access
----------------------------------------------------------------------------- */

GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
ON ALL TABLES IN SCHEMA dm_demo
TO dbt_runner, dev_user;

GRANT SELECT ON ALL TABLES IN SCHEMA dm_demo
TO bi_demo_user;

GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA dm_demo
TO dbt_runner, dev_user;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA dm_demo
TO dbt_runner, dev_user;


/* -----------------------------------------------------------------------------
   INFRA layer access
   - dbt_runner may use technical metadata objects
   - dev_user may inspect and maintain them
   - ingestion_user may select, insert
----------------------------------------------------------------------------- */

GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
ON ALL TABLES IN SCHEMA infra
TO dbt_runner, dev_user;

GRANT SELECT ON ALL TABLES IN SCHEMA infra
TO bi_user;

GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA infra
TO dbt_runner, dev_user;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA infra
TO dbt_runner, dev_user;

GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA infra
TO ingestion_user;

GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA infra
TO ingestion_user;

/* -----------------------------------------------------------------------------
   SEED layer access
   - dbt_runner may use technical metadata objects
   - dev_user may inspect and maintain them
   - ingestion_user may select, insert
----------------------------------------------------------------------------- */

GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
ON ALL TABLES IN SCHEMA seed
TO dbt_runner, dev_user;

GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA seed
TO dbt_runner, dev_user;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA seed
TO dbt_runner, dev_user;

/* -----------------------------------------------------------------------------
   Default privileges for future objects created by dwh_owner
----------------------------------------------------------------------------- */

-- raw
ALTER DEFAULT PRIVILEGES FOR ROLE dwh_owner IN SCHEMA raw
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ingestion_user;

ALTER DEFAULT PRIVILEGES FOR ROLE dwh_owner IN SCHEMA raw
GRANT SELECT ON TABLES TO dbt_runner;

ALTER DEFAULT PRIVILEGES FOR ROLE dwh_owner IN SCHEMA raw
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO dev_user;

ALTER DEFAULT PRIVILEGES FOR ROLE dwh_owner IN SCHEMA raw
GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO ingestion_user, dev_user;

-- stg
ALTER DEFAULT PRIVILEGES FOR ROLE dwh_owner IN SCHEMA stg
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLES TO dbt_runner, dev_user;

ALTER DEFAULT PRIVILEGES FOR ROLE dwh_owner IN SCHEMA stg
GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO dbt_runner, dev_user;

ALTER DEFAULT PRIVILEGES FOR ROLE dwh_owner IN SCHEMA stg
GRANT EXECUTE ON FUNCTIONS TO dbt_runner, dev_user;

-- core
ALTER DEFAULT PRIVILEGES FOR ROLE dwh_owner IN SCHEMA core
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLES TO dbt_runner, dev_user;

ALTER DEFAULT PRIVILEGES FOR ROLE dwh_owner IN SCHEMA core
GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO dbt_runner, dev_user;

ALTER DEFAULT PRIVILEGES FOR ROLE dwh_owner IN SCHEMA core
GRANT EXECUTE ON FUNCTIONS TO dbt_runner, dev_user;

-- dm
ALTER DEFAULT PRIVILEGES FOR ROLE dwh_owner IN SCHEMA dm
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLES TO dbt_runner, dev_user;

ALTER DEFAULT PRIVILEGES FOR ROLE dwh_owner IN SCHEMA dm
GRANT SELECT ON TABLES TO bi_user;

ALTER DEFAULT PRIVILEGES FOR ROLE dwh_owner IN SCHEMA dm
GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO dbt_runner, dev_user;

ALTER DEFAULT PRIVILEGES FOR ROLE dwh_owner IN SCHEMA dm
GRANT EXECUTE ON FUNCTIONS TO dbt_runner, dev_user;

-- dm_demo
ALTER DEFAULT PRIVILEGES FOR ROLE dwh_owner IN SCHEMA dm_demo
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
ON TABLES TO dbt_runner, dev_user;

ALTER DEFAULT PRIVILEGES FOR ROLE dwh_owner IN SCHEMA dm_demo
GRANT SELECT ON TABLES TO bi_demo_user;

ALTER DEFAULT PRIVILEGES FOR ROLE dwh_owner IN SCHEMA dm_demo
GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO dbt_runner, dev_user;

ALTER DEFAULT PRIVILEGES FOR ROLE dwh_owner IN SCHEMA dm_demo
GRANT EXECUTE ON FUNCTIONS TO dbt_runner, dev_user;

-- infra
ALTER DEFAULT PRIVILEGES FOR ROLE dwh_owner IN SCHEMA infra
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLES TO dbt_runner, dev_user;

ALTER DEFAULT PRIVILEGES FOR ROLE dwh_owner IN SCHEMA infra
GRANT SELECT, INSERT, UPDATE ON TABLES TO ingestion_user;

ALTER DEFAULT PRIVILEGES FOR ROLE dwh_owner IN SCHEMA infra
GRANT SELECT ON TABLES TO bi_user;

ALTER DEFAULT PRIVILEGES FOR ROLE dwh_owner IN SCHEMA infra
GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO dbt_runner, dev_user, ingestion_user;

ALTER DEFAULT PRIVILEGES FOR ROLE dwh_owner IN SCHEMA infra
GRANT EXECUTE ON FUNCTIONS TO dbt_runner, dev_user;

-- seed
ALTER DEFAULT PRIVILEGES FOR ROLE dwh_owner IN SCHEMA seed
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLES TO dbt_runner, dev_user;

ALTER DEFAULT PRIVILEGES FOR ROLE dwh_owner IN SCHEMA seed
GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO dbt_runner, dev_user;

ALTER DEFAULT PRIVILEGES FOR ROLE dwh_owner IN SCHEMA seed
GRANT EXECUTE ON FUNCTIONS TO dbt_runner, dev_user;


/* -----------------------------------------------------------------------------
   Default privileges for future objects created by dbt_runner
----------------------------------------------------------------------------- */

-- stg
ALTER DEFAULT PRIVILEGES FOR ROLE dbt_runner IN SCHEMA stg
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLES TO dev_user;

ALTER DEFAULT PRIVILEGES FOR ROLE dbt_runner IN SCHEMA stg
GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO dev_user;

ALTER DEFAULT PRIVILEGES FOR ROLE dbt_runner IN SCHEMA stg
GRANT EXECUTE ON FUNCTIONS TO dev_user;

-- core
ALTER DEFAULT PRIVILEGES FOR ROLE dbt_runner IN SCHEMA core
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLES TO dev_user;

ALTER DEFAULT PRIVILEGES FOR ROLE dbt_runner IN SCHEMA core
GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO dev_user;

ALTER DEFAULT PRIVILEGES FOR ROLE dbt_runner IN SCHEMA core
GRANT EXECUTE ON FUNCTIONS TO dev_user;

-- dm
ALTER DEFAULT PRIVILEGES FOR ROLE dbt_runner IN SCHEMA dm
GRANT SELECT ON TABLES TO bi_user;

ALTER DEFAULT PRIVILEGES FOR ROLE dbt_runner IN SCHEMA dm
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLES TO dev_user;

ALTER DEFAULT PRIVILEGES FOR ROLE dbt_runner IN SCHEMA dm
GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO dev_user;

ALTER DEFAULT PRIVILEGES FOR ROLE dbt_runner IN SCHEMA dm
GRANT EXECUTE ON FUNCTIONS TO dev_user;

-- dm_demo
ALTER DEFAULT PRIVILEGES FOR ROLE dbt_runner IN SCHEMA dm_demo
GRANT SELECT ON TABLES TO bi_demo_user;

ALTER DEFAULT PRIVILEGES FOR ROLE dbt_runner IN SCHEMA dm_demo
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
ON TABLES TO dev_user;

ALTER DEFAULT PRIVILEGES FOR ROLE dbt_runner IN SCHEMA dm_demo
GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO dev_user;

ALTER DEFAULT PRIVILEGES FOR ROLE dbt_runner IN SCHEMA dm_demo
GRANT EXECUTE ON FUNCTIONS TO dev_user;

-- infra
ALTER DEFAULT PRIVILEGES FOR ROLE dbt_runner IN SCHEMA infra
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLES TO dev_user;

ALTER DEFAULT PRIVILEGES FOR ROLE dbt_runner IN SCHEMA infra
GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO dev_user;

ALTER DEFAULT PRIVILEGES FOR ROLE dbt_runner IN SCHEMA infra
GRANT SELECT ON TABLES TO bi_user;

ALTER DEFAULT PRIVILEGES FOR ROLE dbt_runner IN SCHEMA infra
GRANT EXECUTE ON FUNCTIONS TO dev_user;

-- seed
ALTER DEFAULT PRIVILEGES FOR ROLE dbt_runner IN SCHEMA seed
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLES TO dev_user;

ALTER DEFAULT PRIVILEGES FOR ROLE dbt_runner IN SCHEMA seed
GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO dev_user;

ALTER DEFAULT PRIVILEGES FOR ROLE dbt_runner IN SCHEMA seed
GRANT EXECUTE ON FUNCTIONS TO dev_user;
