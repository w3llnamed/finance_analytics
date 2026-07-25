/* =============================================================================
   dm__fact__transaction.sql
   Layer: dm
   Purpose: Analytical mart with transaction-level flags for regular and reserve expenses.

   Source:
       core.fact_transaction
       seed.regular_expense_tag
       seed.reserve_expense_tag

   Description:
       The model enriches fact transactions with analytical flags based on tags:
       - is_regular  — transaction has at least one active regular expense tag
       - is_reserve  — transaction has at least one active reserve expense tag
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

final AS (

    SELECT
        transaction_ts AS transaction_date,
        account,
        amount,
        amount_abs,
        parent_category,
        category,
        tags,
        note,
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
    FROM flagged

)

SELECT *
FROM final
