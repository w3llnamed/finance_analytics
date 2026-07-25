/* =============================================================================
   003_db_settings.sql
   Layer: bootstrap
   Purpose: Configure database-level settings for the DWH project.
   ============================================================================= */

ALTER DATABASE finance_analytics SET timezone  TO 'UTC';
ALTER DATABASE finance_analytics SET datestyle TO 'ISO, DMY';

COMMENT ON DATABASE finance_analytics IS
'Personal DWH project for finance analytics.';
