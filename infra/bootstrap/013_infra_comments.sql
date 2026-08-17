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

COMMENT ON COLUMN infra.ingestion_file_registry.file_size_bytes IS
'File size in bytes, as reported by external storage';

COMMENT ON COLUMN infra.ingestion_file_registry.file_checksum IS
'File checksum, if provided by external storage';

COMMENT ON COLUMN infra.ingestion_file_registry.rows_loaded IS
'Number of rows successfully loaded into raw table';

COMMENT ON COLUMN infra.ingestion_file_registry.error_message IS
'Error text if ingestion failed';

COMMENT ON COLUMN infra.ingestion_file_registry.discovered_at IS
'Timestamp when the file was first discovered in external storage';

COMMENT ON COLUMN infra.ingestion_file_registry.started_at IS
'Timestamp when ingestion processing started';

COMMENT ON COLUMN infra.ingestion_file_registry.finished_at IS
'Timestamp when ingestion processing finished';


/* =======================================================
   fx_ingestion_state
   =======================================================*/

COMMENT ON TABLE infra.fx_ingestion_state IS
'Per source/currency ingestion state for exchange-rate refresh, used to control refresh cadence and incremental lookback window';

COMMENT ON COLUMN infra.fx_ingestion_state.source IS
'Exchange-rate source identifier (e.g. cbr)';

COMMENT ON COLUMN infra.fx_ingestion_state.currency_code IS
'Currency code tracked for this source';

COMMENT ON COLUMN infra.fx_ingestion_state.last_checked_at IS
'Timestamp of the last refresh attempt for this source/currency, regardless of whether new data was loaded';

COMMENT ON COLUMN infra.fx_ingestion_state.last_requested_through IS
'End date of the last date range requested from the source API';

COMMENT ON COLUMN infra.fx_ingestion_state.last_rate_date IS
'Latest rate date successfully loaded for this source/currency';

COMMENT ON COLUMN infra.fx_ingestion_state.last_rows_affected IS
'Number of raw rows inserted or updated during the last refresh';

COMMENT ON COLUMN infra.fx_ingestion_state.updated_at IS
'Timestamp when this state row was last updated';
