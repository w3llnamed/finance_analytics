/* =============================================================================
   stg__fact_transaction.sql
   Layer: stg
   Purpose: Clean and normalize raw money flow transactions.

   Source:
       raw.money_flow
       infra.ingestion_file_registry

   Description:
       This staging model performs basic technical normalization of raw money
       flow transactions before loading data into the core layer.

       Main responsibilities:
       - Select rows from the latest successfully loaded ingestion batch
       - Trim whitespace from text fields
       - Convert empty strings to NULL
       - Normalize currencies to upper case
       - Parse transaction date
       - Parse numeric amount fields
       - Preserve ingestion metadata
       - Derive technical helper fields (flow_type, is_transfer)

       No business mappings or dimensional enrichment are applied here.
   ============================================================================= */

WITH latest_loaded_batch AS (

    SELECT MAX(ingestion_id) AS ingestion_id
    FROM {{ source('infra', 'ingestion_file_registry') }}
    WHERE
        source_system = 'money_flow_app'
        AND source_object = 'money_flow'
        AND raw_table = 'raw.money_flow'
        AND status = 'loaded'

),

source_data AS (

    SELECT
        r.raw_id,
        r.source_number,
        r.transaction_date,
        r.account,
        r.amount,
        r.currency,
        r.parent_category,
        r.subcategory,
        r.category,
        r.counterparty,
        r.transfer_account,
        r.transfer_amount,
        r.transfer_currency,
        r.tags,
        r.place,
        r.note,
        r.ingested_at,
        r.ingested_by,
        r.source_file,
        r.ingestion_id
    FROM {{ source('raw', 'money_flow') }} AS r
    INNER JOIN latest_loaded_batch AS b
        ON r.ingestion_id = b.ingestion_id

),

cleaned AS (

    SELECT
        raw_id,

        NULLIF(BTRIM(source_number), '') AS source_number,
        NULLIF(BTRIM(transaction_date), '') AS transaction_date_text,
        NULLIF(BTRIM(account), '') AS account,
        NULLIF(BTRIM(amount), '') AS amount_text,
        UPPER(NULLIF(BTRIM(currency), '')) AS currency,
        NULLIF(BTRIM(parent_category), '') AS parent_category,
        NULLIF(BTRIM(subcategory), '') AS subcategory,
        NULLIF(BTRIM(category), '') AS category,
        NULLIF(BTRIM(counterparty), '') AS counterparty,
        NULLIF(BTRIM(transfer_account), '') AS transfer_account,
        NULLIF(BTRIM(transfer_amount), '') AS transfer_amount_text,
        UPPER(NULLIF(BTRIM(transfer_currency), '')) AS transfer_currency,
        NULLIF(BTRIM(tags), '') AS tags,
        NULLIF(BTRIM(place), '') AS place,
        NULLIF(BTRIM(note), '') AS note,
        ingested_at AS ingested_at,
        NULLIF(BTRIM(ingested_by), '') AS ingested_by,
        NULLIF(BTRIM(source_file), '') AS source_file,
        ingestion_id AS ingestion_id
    FROM source_data

),

typed AS (

    SELECT
        raw_id,
        source_number,

        CASE
            WHEN transaction_date_text IS NULL THEN NULL
            ELSE TO_TIMESTAMP(transaction_date_text, 'YYYY-MM-DD HH24:MI:SS')::TIMESTAMP
        END AS transaction_date,

        account,

        CASE
            WHEN amount_text IS NULL THEN NULL
            ELSE REPLACE(REPLACE(amount_text, ' ', ''), ',', '.')::NUMERIC(18, 2)
        END AS amount,

        currency,
        parent_category,
        subcategory,
        category,
        counterparty,
        transfer_account,

        CASE
            WHEN transfer_amount_text IS NULL THEN NULL
            ELSE REPLACE(REPLACE(transfer_amount_text, ' ', ''), ',', '.')::NUMERIC(18, 2)
        END AS transfer_amount,

        transfer_currency,
        tags,
        place,
        note,
        ingested_at,
        ingested_by,
        source_file,
        ingestion_id
    FROM cleaned

),

final AS (

    SELECT
        raw_id,
        source_number,
        transaction_date,
        account,
        amount,
        currency,
        parent_category,
        subcategory,
        category,
        counterparty,
        transfer_account,
        transfer_amount,
        transfer_currency,
        tags,
        place,
        note,
        ingested_at,
        ingested_by,
        source_file,
        ingestion_id,

        CASE
            WHEN COALESCE(amount, 0) < 0 THEN 'expense'
            WHEN COALESCE(amount, 0) > 0 THEN 'income'
            ELSE 'zero'
        END AS flow_type,

        COALESCE(transfer_account IS NOT NULL OR transfer_amount IS NOT NULL, FALSE) AS is_transfer
    FROM typed

)

SELECT
    raw_id,
    source_number,
    transaction_date,
    account,
    amount,
    currency,
    parent_category,
    subcategory,
    category,
    counterparty,
    transfer_account,
    transfer_amount,
    transfer_currency,
    tags,
    place,
    note,
    ingested_at,
    ingested_by,
    source_file,
    ingestion_id,
    flow_type,
    is_transfer
FROM final
