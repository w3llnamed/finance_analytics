/* =============================================================================
   infra__data_volume_monitoring.sql
   Layer: infra
   Purpose: Data volume monitoring for BI quality dashboard
   Source: infra.ingestion_file_registry
   Description:
       Compares the latest successful ingestion row count with the historical
       baseline based on previous successful loads.
   ============================================================================= */

WITH successful_loads AS (
    SELECT
        ingestion_id,
        source_system,
        source_object,
        raw_table,
        s3_bucket,
        s3_key,
        file_size_bytes,
        rows_loaded,
        finished_at,

        ROW_NUMBER() OVER (
            PARTITION BY source_system, source_object, raw_table
            ORDER BY finished_at DESC
        ) AS load_rank
    FROM {{ source('infra', 'ingestion_file_registry') }}
    WHERE status = 'loaded'
),

latest_load AS (
    SELECT
        ingestion_id,
        source_system,
        source_object,
        raw_table,
        s3_bucket,
        s3_key,
        file_size_bytes,
        rows_loaded AS latest_rows_loaded,
        finished_at AS latest_load_at
    FROM successful_loads
    WHERE load_rank = 1
),

baseline_loads AS (
    SELECT
        source_system,
        source_object,
        raw_table,

        COUNT(*) AS baseline_load_count,

        ROUND(AVG(rows_loaded), 2) AS avg_rows_loaded,
        MIN(rows_loaded) AS min_rows_loaded,
        MAX(rows_loaded) AS max_rows_loaded
    FROM successful_loads
    WHERE load_rank BETWEEN 2 AND 8
    GROUP BY
        source_system,
        source_object,
        raw_table
)

SELECT
    latest_load.ingestion_id,
    latest_load.source_system,
    latest_load.source_object,
    latest_load.raw_table,
    latest_load.s3_bucket,
    latest_load.s3_key,
    latest_load.file_size_bytes,

    latest_load.latest_load_at,
    latest_load.latest_rows_loaded,

    baseline_loads.baseline_load_count,
    baseline_loads.avg_rows_loaded,
    baseline_loads.min_rows_loaded,
    baseline_loads.max_rows_loaded,

    CASE
        WHEN baseline_loads.avg_rows_loaded IS NULL THEN NULL
        WHEN baseline_loads.avg_rows_loaded = 0 THEN NULL
        ELSE ROUND(
            (
                latest_load.latest_rows_loaded - baseline_loads.avg_rows_loaded
            ) / baseline_loads.avg_rows_loaded * 100,
            2
        )
    END AS deviation_pct,

    CASE
        WHEN baseline_loads.baseline_load_count IS NULL THEN 'no_baseline'
        WHEN baseline_loads.baseline_load_count < 3 THEN 'weak_baseline'
        WHEN baseline_loads.avg_rows_loaded = 0 THEN 'invalid_baseline'

        WHEN latest_load.latest_rows_loaded <= baseline_loads.avg_rows_loaded * 0.2 THEN 'anomaly'
        WHEN latest_load.latest_rows_loaded <= baseline_loads.avg_rows_loaded * 0.6 THEN 'warning'

        WHEN latest_load.latest_rows_loaded >= baseline_loads.avg_rows_loaded * 2.5 THEN 'warning'

        ELSE 'normal'
    END AS volume_status,

    NOW() AS checked_at

FROM latest_load
LEFT JOIN baseline_loads
    ON
        latest_load.source_system = baseline_loads.source_system
        AND latest_load.source_object = baseline_loads.source_object
        AND latest_load.raw_table = baseline_loads.raw_table
