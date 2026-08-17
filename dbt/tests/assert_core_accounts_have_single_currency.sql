{{ config(severity='error') }}

SELECT
    account,
    COUNT(DISTINCT currency) AS currency_count
FROM {{ ref('core__fact_transaction') }}
WHERE is_active_account IS TRUE
GROUP BY account
HAVING COUNT(DISTINCT currency) > 1
