/* =============================================================================
   013_infra_comments.sql
   Layer: raw
   Purpose: Create comments for infra tables.
   ============================================================================= */

/* =======================================================
   ingestion_file_registry
   =======================================================*/

COMMENT ON TABLE infra.ingestion_file_registry IS
'Registry of files discovered in external storage (e.g. S3) and processed by ingestion pipeline';

COMMENT ON COLUMN infra.ingestion_file_registry.source_system IS
'Source system that produced the file';

COMMENT ON COLUMN infra.ingestion_file_registry.source_object IS
'Logical object name (e.g. transactions, balances)';

COMMENT ON COLUMN infra.ingestion_file_registry.raw_table IS
'Target raw table where the file data is loaded';

COMMENT ON COLUMN infra.ingestion_file_registry.s3_bucket IS
'S3 bucket name';

COMMENT ON COLUMN infra.ingestion_file_registry.s3_key IS
'Full object key in S3 storage';

COMMENT ON COLUMN infra.ingestion_file_registry.status IS
'Processing status: pending, processing, loaded, failed';

COMMENT ON COLUMN infra.ingestion_file_registry.rows_loaded IS
'Number of rows successfully loaded into raw table';

COMMENT ON COLUMN infra.ingestion_file_registry.error_message IS
'Error text if ingestion failed';
