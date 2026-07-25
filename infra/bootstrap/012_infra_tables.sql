/* =============================================================================
   infra.ingestion_file_registry.sql
   Layer: infra
   Purpose: Registry of files discovered in external storage (e.g. S3) and
            processed by the ingestion pipeline.
   ============================================================================= */



/* =======================================================
   ingestion_file_registry
   =======================================================*/

CREATE TABLE IF NOT EXISTS infra.ingestion_file_registry
(
    ingestion_id      BIGSERIAL PRIMARY KEY,

    source_system     TEXT        NOT NULL,   -- источник (например: finance_app)
    source_object     TEXT        NOT NULL,   -- логический объект (например: transactions)

    raw_table         TEXT        NOT NULL,   -- целевая таблица raw слоя (например: raw.transactions)

    s3_bucket         TEXT        NOT NULL,   -- bucket
    s3_key            TEXT        NOT NULL,   -- полный путь к файлу в S3

    file_size_bytes   BIGINT,                 -- размер файла
    file_checksum     TEXT,                   -- checksum (если считаем)

    status            TEXT        NOT NULL DEFAULT 'pending', -- pending / processing / loaded / failed

    rows_loaded       INTEGER,                -- сколько строк загрузилось
    error_message     TEXT,                   -- текст ошибки

    discovered_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(), -- когда файл обнаружен
    started_at        TIMESTAMPTZ,            -- начало загрузки
    finished_at       TIMESTAMPTZ             -- окончание загрузки
);

--   Indexes

CREATE UNIQUE INDEX IF NOT EXISTS ux_ingestion_file_registry_s3_object
ON infra.ingestion_file_registry (s3_bucket, s3_key);
