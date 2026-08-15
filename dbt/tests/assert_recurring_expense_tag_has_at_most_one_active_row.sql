SELECT COUNT(*) AS active_row_count
FROM {{ ref('recurring_expense_tag') }}
WHERE is_active = TRUE
HAVING COUNT(*) > 1
