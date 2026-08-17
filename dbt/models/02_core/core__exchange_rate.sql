/* =============================================================================
   core__exchange_rate.sql
   Layer: core
   Purpose: Canonical fact table for exchange rates.

   Source:
       stg__exchange_rate

   Description:
       The model materializes normalized exchange rates as a stable
       canonical business table for downstream analytical marts and
       future currency-conversion logic.

       Main responsibilities:
       - Materialize normalized exchange rates from the staging layer
       - Preserve source and ingestion metadata for traceability
   ============================================================================= */

SELECT
    raw_id,
    source,
    source_rate_key,
    rate_date,
    base_currency,
    quote_currency,
    base_amount,
    quote_amount,
    rate,
    ingested_at,
    ingested_by
FROM {{ ref('stg__exchange_rate') }}
