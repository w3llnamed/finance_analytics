-- Verifies that every category combination used by the canonical
-- transaction model has a corresponding row in category_mapping_demo.

WITH core_categories AS (
    SELECT DISTINCT
        TRIM(parent_category) AS parent_category,
        TRIM(category) AS category
    FROM {{ ref('core__fact_transaction') }}
    WHERE
        parent_category IS NOT NULL
        AND TRIM(parent_category) <> ''
        AND category IS NOT NULL
        AND TRIM(category) <> ''
),

seed_categories AS (
    SELECT
        TRIM(real_parent_category) AS parent_category,
        TRIM(real_category) AS category
    FROM {{ ref('category_mapping_demo') }}
)

SELECT
    core_categories.parent_category,
    core_categories.category
FROM core_categories
LEFT JOIN seed_categories
    ON
        core_categories.parent_category = seed_categories.parent_category
        AND core_categories.category = seed_categories.category
WHERE seed_categories.category IS NULL
