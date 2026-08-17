/* =============================================================================
   011_raw_comments.sql
   Layer: raw
   Purpose: Create comments for raw tables.
   ============================================================================= */

/* =======================================================
   money_flow
   =======================================================*/
COMMENT ON TABLE raw.money_flow IS
'Raw landing table for Money Flow CSV exports. Stores source data as-is without cleaning or type conversion. One row per source record.';


COMMENT ON COLUMN raw.money_flow.raw_id IS
'Technical surrogate key for raw records.';


COMMENT ON COLUMN raw.money_flow.source_number IS
'Original Number field from the source file (as-is, TEXT).';

COMMENT ON COLUMN raw.money_flow.transaction_date IS
'Original Date field from the source file (as-is, TEXT, not parsed).';

COMMENT ON COLUMN raw.money_flow.account IS
'Original Account field from the source file (as-is, TEXT).';

COMMENT ON COLUMN raw.money_flow.amount IS
'Original Amount field from the source file (as-is, TEXT, not converted to numeric).';

COMMENT ON COLUMN raw.money_flow.currency IS
'Original Currency field from the source file (as-is, TEXT).';

COMMENT ON COLUMN raw.money_flow.parent_category IS
'Original Parent Category field from the source file (as-is, TEXT).';

COMMENT ON COLUMN raw.money_flow.subcategory IS
'Original Subcategory field from the source file (as-is, TEXT).';

COMMENT ON COLUMN raw.money_flow.category IS
'Original Category field from the source file (as-is, TEXT).';

COMMENT ON COLUMN raw.money_flow.counterparty IS
'Original Counterparty field from the source file (as-is, TEXT).';

COMMENT ON COLUMN raw.money_flow.transfer_account IS
'Original Transfer: Account field from the source file (as-is, TEXT).';

COMMENT ON COLUMN raw.money_flow.transfer_amount IS
'Original Transfer: Amount field from the source file (as-is, TEXT, not converted to numeric).';

COMMENT ON COLUMN raw.money_flow.transfer_currency IS
'Original Transfer: Currency field from the source file (as-is, TEXT).';

COMMENT ON COLUMN raw.money_flow.tags IS
'Original Tags field from the source file (as-is, TEXT).';

COMMENT ON COLUMN raw.money_flow.place IS
'Original Place field from the source file (as-is, TEXT).';

COMMENT ON COLUMN raw.money_flow.note IS
'Original Note field from the source file (as-is, TEXT).';


COMMENT ON COLUMN raw.money_flow.ingested_at IS
'UTC timestamp when the row was ingested into the raw layer.';

COMMENT ON COLUMN raw.money_flow.ingested_by IS
'Technical field storing the ingestion user or service account.';

COMMENT ON COLUMN raw.money_flow.source_file IS
'Technical field storing the original source file name in S3.';

COMMENT ON COLUMN raw.money_flow.ingestion_id IS
'Reference to infra.ingestion_file_registry.ingestion_id for tracing ingestion batches.';


/* =======================================================
   exchange_rate
   =======================================================*/
COMMENT ON TABLE raw.exchange_rate IS
'Raw landing table for exchange rates fetched from official FX sources (e.g. CBR). Stores source data as-is without cleaning or type conversion. One row per (source, rate_date, base_currency, quote_currency), upserted on refresh.';


COMMENT ON COLUMN raw.exchange_rate.raw_id IS
'Technical surrogate key for raw records.';

COMMENT ON COLUMN raw.exchange_rate.source IS
'Exchange-rate source identifier (as-is, TEXT, e.g. cbr).';

COMMENT ON COLUMN raw.exchange_rate.source_rate_key IS
'Source-specific identifier for the rate series (as-is, TEXT, e.g. CBR currency ID).';

COMMENT ON COLUMN raw.exchange_rate.rate_date IS
'Original rate date from the source (as-is, TEXT, not parsed; format depends on source).';

COMMENT ON COLUMN raw.exchange_rate.base_currency IS
'Currency code the rate is quoted from, as provided by the source (as-is, TEXT).';

COMMENT ON COLUMN raw.exchange_rate.base_amount IS
'Original base amount/nominal from the source (as-is, TEXT, not converted to numeric).';

COMMENT ON COLUMN raw.exchange_rate.quote_currency IS
'Currency code the rate is quoted to, as provided by the source (as-is, TEXT).';

COMMENT ON COLUMN raw.exchange_rate.quote_amount IS
'Original quote amount/value from the source (as-is, TEXT, not converted to numeric).';

COMMENT ON COLUMN raw.exchange_rate.ingested_at IS
'UTC timestamp when the row was last ingested or updated in the raw layer.';

COMMENT ON COLUMN raw.exchange_rate.ingested_by IS
'Technical field storing the ingestion user or service account.';
