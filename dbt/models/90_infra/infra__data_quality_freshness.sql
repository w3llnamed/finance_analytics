/* =============================================================================
   infra__data_quality_freshness.sql
   Layer: infra
   Purpose: Data freshness monitoring for BI quality dashboard
   Source: infra.ingestion_file_registry
   Description:
       Calculates the last successful ingestion time and current freshness status.
   ============================================================================= */

{{ config(materialized='view') }}

WITH last_successful_load AS (
    SELECT
        ingestion_id,
        source_system,
        source_object,
        raw_table,
        s3_bucket,
        s3_key,
        file_size_bytes,
        rows_loaded,
        discovered_at,
        started_at,
        finished_at
    FROM {{ source('infra', 'ingestion_file_registry') }}
    WHERE status = 'loaded'
    ORDER BY finished_at DESC
    LIMIT 1
),

freshness AS (
    SELECT
        ingestion_id,
        source_system,
        source_object,
        raw_table,
        s3_bucket,
        s3_key,
        file_size_bytes,
        rows_loaded,

        discovered_at,
        started_at,
        finished_at AS last_successful_load_at,
        NOW() AS checked_at,

        CASE
            WHEN finished_at IS NULL THEN NULL
            ELSE EXTRACT(EPOCH FROM (NOW() - finished_at))::bigint
        END AS seconds_since_last_load

    FROM last_successful_load

    UNION ALL

    SELECT
        NULL AS ingestion_id,
        NULL AS source_system,
        NULL AS source_object,
        NULL AS raw_table,
        NULL AS s3_bucket,
        NULL AS s3_key,
        NULL AS file_size_bytes,
        NULL AS rows_loaded,

        NULL AS discovered_at,
        NULL AS started_at,
        NULL AS last_successful_load_at,
        NOW() AS checked_at,

        NULL AS seconds_since_last_load

    WHERE NOT EXISTS (
        SELECT 1
        FROM last_successful_load
    )
)

SELECT
    ingestion_id,
    source_system,
    source_object,
    raw_table,
    s3_bucket,
    s3_key,
    file_size_bytes,
    rows_loaded,

    discovered_at,
    started_at,
    last_successful_load_at,
    checked_at,

    seconds_since_last_load,

    CASE
        WHEN seconds_since_last_load IS NULL THEN NULL
        ELSE CONCAT_WS(
            ' ',
            FLOOR(seconds_since_last_load / 86400)::int || ' d',
            FLOOR(MOD(seconds_since_last_load, 86400) / 3600)::int || ' h',
            FLOOR(MOD(seconds_since_last_load, 3600) / 60)::int || ' min'
        )
    END AS time_since_last_load_text,

    CASE
        WHEN last_successful_load_at IS NULL THEN 'no_data'
        WHEN seconds_since_last_load <= 259200 THEN 'fresh'
        WHEN seconds_since_last_load <= 604800 THEN 'warning'
        ELSE 'stale'
    END AS freshness_status

FROM freshness
