/* =============================================================================
   012_infra_tables.sql
   Layer: infra
   Purpose: Create infrastructure and ingestion metadata tables.
   ============================================================================= */


/* =======================================================
   ingestion_file_registry
   ======================================================= */
CREATE TABLE IF NOT EXISTS infra.ingestion_file_registry
(
    ingestion_id      BIGSERIAL PRIMARY KEY,

    source_system     TEXT        NOT NULL,   -- source system (e.g. finance_app)
    source_object     TEXT        NOT NULL,   -- logical object (e.g. transactions)

    raw_table         TEXT        NOT NULL,   -- target raw-layer table (e.g. raw.transactions)

    s3_bucket         TEXT        NOT NULL,   -- S3 bucket
    s3_key            TEXT        NOT NULL,   -- full file path in S3

    file_size_bytes   BIGINT,                 -- file size in bytes
    file_checksum     TEXT,                   -- checksum, if available

    status            TEXT        NOT NULL DEFAULT 'pending', -- pending / processing / loaded / failed

    rows_loaded       INTEGER,                -- number of rows loaded
    error_message     TEXT,                   -- error message

    discovered_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(), -- file discovery time
    started_at        TIMESTAMPTZ,            -- ingestion start time
    finished_at       TIMESTAMPTZ             -- ingestion completion time
);

-- Indexes

CREATE UNIQUE INDEX IF NOT EXISTS ux_ingestion_file_registry_s3_object
ON infra.ingestion_file_registry (s3_bucket, s3_key);


/* =======================================================
   fx_ingestion_state
   ======================================================= */
CREATE TABLE IF NOT EXISTS infra.fx_ingestion_state
(
    source                  TEXT        NOT NULL,
    currency_code           TEXT        NOT NULL,

    last_checked_at         TIMESTAMPTZ,
    last_requested_through  DATE,
    last_rate_date          DATE,
    last_rows_affected      INTEGER,

    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (source, currency_code)
);
