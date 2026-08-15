/* =============================================================================
    dm__fact__transaction.sql
    Layer: dm
    Purpose: Analytical mart with expense and account classifications.

    Source:
        core.fact_transaction
        seed.recurring_expense_tag
        seed.reserve_funded_expense_tag

    Description:
        The model enriches fact transactions with expense and account classifications:
        - expense_type is derived from active recurring and reserve-funded expense tags
        - account_type is derived from reserve and credit account flags

        Each transaction is expanded into five time grains:
        Day, Week, Month, Quarter and Year.

        This allows dashboards to use categorical period axes while preserving
        dynamic grain selection and dashboard cross-filtering by period.
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
        rt.tag IS NOT NULL AS is_recurring_expense,
        rs.tag IS NOT NULL AS is_reserve_funded_expense
    FROM source AS src
    LEFT JOIN {{ ref('recurring_expense_tag') }} AS rt
        ON
            rt.tag = ANY(STRING_TO_ARRAY(src.tags, ', '))
            AND rt.is_active = TRUE
    LEFT JOIN {{ ref('reserve_funded_expense_tag') }} AS rs
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
            WHEN is_recurring_expense THEN 'Recurring'
            WHEN is_reserve_funded_expense THEN 'Reserve-funded'
            ELSE 'Ad hoc'
        END AS expense_type,

        CASE
            WHEN is_reserve_account THEN 'Reserve'
            WHEN is_credit_account THEN 'Credit'
            ELSE 'Standard'
        END AS account_type
    FROM flagged

),

periodized AS (

    SELECT
        final.*,
        period.period_grain,
        period.period
    FROM final

    CROSS JOIN LATERAL (

        VALUES

        (
            'Day'::text,
            TO_CHAR(
                final.transaction_date,
                'YYYY-MM-DD'
            )
        ),

        (
            'Week'::text,
            TO_CHAR(
                DATE_TRUNC(
                    'week',
                    final.transaction_date
                ),
                'YYYY-MM-DD'
            )
        ),

        (
            'Month'::text,
            TO_CHAR(
                final.transaction_date,
                'YYYY-MM'
            )
        ),

        (
            'Quarter'::text,
            TO_CHAR(
                final.transaction_date,
                'YYYY'
            )
            || '-Q'
            || EXTRACT(
                QUARTER FROM final.transaction_date
            )::integer::text
        ),

        (
            'Year'::text,
            TO_CHAR(
                final.transaction_date,
                'YYYY'
            )
        )

    ) AS period (
        period_grain,
        period
    )

)

SELECT *
FROM periodized
