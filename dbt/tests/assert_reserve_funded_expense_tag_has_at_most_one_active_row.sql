SELECT COUNT(*) AS active_row_count
FROM {{ ref('reserve_funded_expense_tag') }}
WHERE is_active = TRUE
HAVING COUNT(*) > 1
