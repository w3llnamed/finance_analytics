/* =============================================================================
   005_schemas.sql
   Layer: bootstrap
   Purpose: Create DWH schemas and assign ownership.
   ============================================================================= */

CREATE SCHEMA IF NOT EXISTS raw   AUTHORIZATION dwh_owner;
CREATE SCHEMA IF NOT EXISTS stg   AUTHORIZATION dwh_owner;
CREATE SCHEMA IF NOT EXISTS core  AUTHORIZATION dwh_owner;
CREATE SCHEMA IF NOT EXISTS dm    AUTHORIZATION dwh_owner;
CREATE SCHEMA IF NOT EXISTS dm_demo AUTHORIZATION dwh_owner;
CREATE SCHEMA IF NOT EXISTS infra AUTHORIZATION dwh_owner;
CREATE SCHEMA IF NOT EXISTS seed AUTHORIZATION dwh_owner;

ALTER SCHEMA raw     OWNER TO dwh_owner;
ALTER SCHEMA stg     OWNER TO dwh_owner;
ALTER SCHEMA core    OWNER TO dwh_owner;
ALTER SCHEMA dm      OWNER TO dwh_owner;
ALTER SCHEMA dm_demo OWNER TO dwh_owner;
ALTER SCHEMA infra   OWNER TO dwh_owner;
ALTER SCHEMA seed    OWNER TO dwh_owner;

COMMENT ON SCHEMA raw     IS 'Landing layer for ingested source data';
COMMENT ON SCHEMA stg     IS 'Staging layer for cleaning and normalization';
COMMENT ON SCHEMA core    IS 'Core business logic layer';
COMMENT ON SCHEMA dm      IS 'Data marts layer for BI and analytics';
COMMENT ON SCHEMA dm_demo IS 'Public demo data marts containing anonymized and transformed data.';
COMMENT ON SCHEMA infra   IS 'Infrastructure layer for technical metadata and service objects';
COMMENT ON SCHEMA seed    IS 'Reference data layer for static seed tables loaded by dbt.';



/* -----------------------------------------------------------------------------
   Lock down default public schema
----------------------------------------------------------------------------- */

REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE USAGE  ON SCHEMA public FROM PUBLIC;

GRANT USAGE ON SCHEMA public TO dwh_owner;

COMMENT ON SCHEMA public IS
'Default PostgreSQL schema. Not used in this DWH project.';
