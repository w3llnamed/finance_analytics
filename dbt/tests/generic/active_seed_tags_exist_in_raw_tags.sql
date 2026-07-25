{% test active_seed_tags_exist_in_raw_tags(
    model,
    column_name,
    raw_source_name,
    raw_table_name,
    raw_tags_column,
    separator=','
) %}

WITH active_seed_tags AS (
    SELECT
        TRIM({{ column_name }}) AS tag
    FROM {{ model }}
    WHERE is_active = TRUE
      AND {{ column_name }} IS NOT NULL
      AND TRIM({{ column_name }}) <> ''
),

raw_tags AS (
    SELECT DISTINCT
        TRIM(
            regexp_split_to_table(
                {{ raw_tags_column }},
                '{{ separator }}'
            )
        ) AS tag
    FROM {{ source(raw_source_name, raw_table_name) }}
    WHERE {{ raw_tags_column }} IS NOT NULL
      AND TRIM({{ raw_tags_column }}) <> ''
)

SELECT
    active_seed_tags.tag
FROM active_seed_tags
LEFT JOIN raw_tags
    ON active_seed_tags.tag = raw_tags.tag
WHERE raw_tags.tag IS NULL

{% endtest %}
