/* =============================================================================
   stg__exchange_rate.sql
   Layer: stg
   Purpose: Clean and normalize raw exchange rates.

   Source:
       raw.exchange_rate

   Description:
       This staging model performs basic technical normalization of raw
       exchange rates before loading data into the core layer.

       Main responsibilities:
       - Trim whitespace from text fields
       - Convert empty strings to NULL
       - Normalize currency codes to upper case
       - Parse source-specific rate date formats into DATE
       - Parse numeric base/quote amount fields
       - Normalize nominal-based quoting into a per-unit rate

       No business mappings, currency conversion logic, or reporting-currency
       selection are applied here.
   ============================================================================= */

WITH source_data AS (

    SELECT
        raw_id,
        source,
        source_rate_key,
        rate_date,
        base_currency,
        base_amount,
        quote_currency,
        quote_amount,
        ingested_at,
        ingested_by
    FROM {{ source('raw', 'exchange_rate') }}

),

cleaned AS (

    SELECT
        raw_id,
        NULLIF(BTRIM(source), '') AS source,
        NULLIF(BTRIM(source_rate_key), '') AS source_rate_key,
        NULLIF(BTRIM(rate_date), '') AS rate_date_text,
        UPPER(NULLIF(BTRIM(base_currency), '')) AS base_currency,
        NULLIF(BTRIM(base_amount), '') AS base_amount_text,
        UPPER(NULLIF(BTRIM(quote_currency), '')) AS quote_currency,
        NULLIF(BTRIM(quote_amount), '') AS quote_amount_text,
        ingested_at,
        NULLIF(BTRIM(ingested_by), '') AS ingested_by
    FROM source_data

),

typed AS (

    SELECT
        raw_id,
        source,
        source_rate_key,

        CASE
            WHEN rate_date_text IS NULL THEN NULL
            WHEN source = 'cbr' THEN TO_DATE(rate_date_text, 'DD.MM.YYYY')
        END AS rate_date,

        base_currency,

        CASE
            WHEN base_amount_text IS NULL THEN NULL
            ELSE REPLACE(REPLACE(base_amount_text, ' ', ''), ',', '.')::NUMERIC(18, 6)
        END AS base_amount,

        quote_currency,

        CASE
            WHEN quote_amount_text IS NULL THEN NULL
            ELSE REPLACE(REPLACE(quote_amount_text, ' ', ''), ',', '.')::NUMERIC(18, 6)
        END AS quote_amount,

        ingested_at,
        ingested_by
    FROM cleaned

),

final AS (

    SELECT
        raw_id,
        source,
        source_rate_key,
        rate_date,
        base_currency,
        base_amount,
        quote_currency,
        quote_amount,

        CASE
            WHEN base_amount IS NULL OR base_amount = 0 THEN NULL
            ELSE quote_amount / base_amount
        END AS rate,

        ingested_at,
        ingested_by
    FROM typed

)

SELECT
    raw_id,
    source,
    source_rate_key,
    rate_date,
    base_currency,
    base_amount,
    quote_currency,
    quote_amount,
    rate,
    ingested_at,
    ingested_by
FROM final
