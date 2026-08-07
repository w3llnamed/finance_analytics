-- Verifies that all required real and demo category attributes are
-- populated in category_mapping_demo and that text attributes do not
-- contain empty values.


SELECT
    real_parent_category,
    real_category,
    demo_parent_category,
    demo_category,
    amount_factor
FROM {{ ref('category_mapping_demo') }}
WHERE real_parent_category is null
   OR btrim(real_parent_category) = ''
   OR real_category is null
   OR btrim(real_category) = ''
   OR demo_parent_category is null
   OR btrim(demo_parent_category) = ''
   OR demo_category is null
   OR btrim(demo_category) = ''
   OR amount_factor is null
