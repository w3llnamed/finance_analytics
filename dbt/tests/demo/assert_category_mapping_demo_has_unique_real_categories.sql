-- Verifies that every combination of real parent category and real
-- category has no more than one row in category_mapping_demo.

SELECT
    real_parent_category,
    real_category,
    COUNT(*) AS mapping_count
FROM {{ ref('category_mapping_demo') }}
GROUP BY
    real_parent_category,
    real_category
HAVING count(*) > 1
