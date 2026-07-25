/* =============================================================================
   dm_demo_fact_transaction_demo.sql
   Layer: dm
   Purpose: Anonymized transaction-level mart for public demo dashboards.

   Source:
       core.fact_transaction
       seed.regular_expense_tag
       seed.reserve_expense_tag
       seed.dim_accounts
       seed.dim_accounts_demo
       seed.category_mapping

   Description:
       The model mirrors dm.fact_transaction but replaces real accounts and
       categories with demo values and masks transaction amounts using
       category-level masking parameters.
   ============================================================================= */

WITH source AS (

    SELECT
        transaction_ts,
        account,
        amount,
        amount_abs,
        parent_category,
        category,
        tags,
        note,
        transaction_type,
        is_active_account,
        is_reserve_account,
        is_credit_account
    FROM {{ ref('core__fact_transaction') }}

),

flagged AS (

    SELECT
        src.*,
        rt.tag IS NOT NULL AS is_regular_expense,
        rs.tag IS NOT NULL AS is_reserve_expense
    FROM source AS src
    LEFT JOIN {{ ref('regular_expense_tag') }} AS rt
        ON
            rt.tag = ANY(STRING_TO_ARRAY(src.tags, ', '))
            AND rt.is_active = TRUE
    LEFT JOIN {{ ref('reserve_expense_tag') }} AS rs
        ON
            rs.tag = ANY(STRING_TO_ARRAY(src.tags, ', '))
            AND rs.is_active = TRUE
    WHERE src.is_active_account IS TRUE

),

mapped AS (

    SELECT
        flagged.*,
        acc_demo.account_name AS demo_account,
        cat.demo_parent_category,
        cat.demo_category,
        COALESCE(cat.amount_factor, 1.0) AS amount_factor
    FROM flagged
    LEFT JOIN {{ ref('dim_accounts') }} AS acc_real
        ON flagged.account = acc_real.account_name
    LEFT JOIN {{ ref('dim_accounts_demo') }} AS acc_demo
        ON acc_real.account_id = acc_demo.account_id
    LEFT JOIN {{ ref('category_mapping') }} AS cat
        ON
            flagged.parent_category = cat.real_parent_category
            AND flagged.category = cat.real_category

),

final AS (

    SELECT
        transaction_ts AS transaction_date,
        demo_account AS account,

        ROUND(amount * amount_factor, 2) AS amount,
        ABS(ROUND(amount * amount_factor, 2)) AS amount_abs,

        demo_parent_category AS parent_category,
        demo_category AS category,

        NULL::text AS tags,
        NULL::text AS note,

        CASE
            WHEN transaction_type = 'transfer_out' THEN 'Transfer out'
            WHEN transaction_type = 'transfer_in' THEN 'Transfer in'
            WHEN transaction_type = 'expense' THEN 'Expense'
            WHEN transaction_type = 'income' THEN 'Income'
            WHEN transaction_type = 'opening_balance' THEN 'Opening balance'
        END AS transaction_type,

        CASE
            WHEN is_regular_expense THEN 'Regular'
            WHEN is_reserve_expense THEN 'Reserve'
            ELSE 'Discretionary'
        END AS expense_type,

        CASE
            WHEN is_reserve_account THEN 'Reserve'
            WHEN is_credit_account THEN 'Credit'
            ELSE 'Regular'
        END AS account_type
    FROM mapped

)

SELECT *
FROM final
