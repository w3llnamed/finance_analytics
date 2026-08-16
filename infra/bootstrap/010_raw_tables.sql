/* =============================================================================
   010_raw_tables.sql
   Layer: raw
   Purpose: Create raw tables.
   ============================================================================= */

/* =======================================================
   money_flow
   =======================================================*/
CREATE TABLE IF NOT EXISTS raw.money_flow
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


/* =======================================================
   exchange_rates
   =======================================================*/
CREATE TABLE IF NOT EXISTS raw.exchange_rates
(
    raw_id              BIGSERIAL PRIMARY KEY,

    source              TEXT        NOT NULL,
    source_rate_key     TEXT        NOT NULL,
    rate_date           TEXT        NOT NULL,

    base_currency       TEXT        NOT NULL,
    base_amount         TEXT        NOT NULL,
    quote_currency      TEXT        NOT NULL,
    quote_amount        TEXT        NOT NULL,

    ingested_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ingested_by         TEXT        NOT NULL DEFAULT CURRENT_USER,

    CONSTRAINT ux_exchange_rates_source_date_pair
        UNIQUE (source, rate_date, base_currency, quote_currency)
);
