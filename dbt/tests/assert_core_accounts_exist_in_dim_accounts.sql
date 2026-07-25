{{ config(severity='error') }}

WITH core_accounts AS (
    SELECT DISTINCT TRIM(account) AS account_name
    FROM {{ ref('core__fact_transaction') }}
    WHERE
        account IS NOT NULL
        AND TRIM(account) <> ''
),

seed_accounts AS (
    SELECT TRIM(account_name) AS account_name
    FROM {{ ref('dim_accounts') }}
)

SELECT core_accounts.account_name
FROM core_accounts
LEFT JOIN seed_accounts
    ON core_accounts.account_name = seed_accounts.account_name
WHERE seed_accounts.account_name IS NULL
