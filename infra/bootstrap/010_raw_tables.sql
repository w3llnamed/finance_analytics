/* =============================================================================
   010_raw_tables.sql
   Layer: raw
   Purpose: Create raw tables.
   ============================================================================= */

/* =======================================================
   money_flow
   =======================================================*/
CREATE TABLE raw.money_flow
(
    raw_id              BIGSERIAL PRIMARY KEY,

    source_number       TEXT,
    transaction_date    TEXT,
    account             TEXT,
    amount              TEXT,
    currency            TEXT,
    parent_category     TEXT,
    subcategory         TEXT,
    category            TEXT,
    counterparty        TEXT,
    transfer_account    TEXT,
    transfer_amount     TEXT,
    transfer_currency   TEXT,
    tags                TEXT,
    place               TEXT,
    note                TEXT,

    ingested_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ingested_by         TEXT        NOT NULL DEFAULT CURRENT_USER,
    source_file         TEXT        NOT NULL,
    ingestion_id        BIGINT
);
