/* =============================================================================
    dm__fact__transaction.sql
    Layer: dm
    Purpose: Analytical mart with expense and account classifications.

    Source:
        core.fact_transaction
        core.exchange_rate
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

        Each transaction is further expanded into one row per supported
        target currency (tracked FX currencies, RUB, and any currency
        actually used in transactions), so any aggregation of
        amount_abs_converted must filter to a single target_currency, in
        addition to a single period_grain.

        amount_abs_converted uses the exchange rate closest to (and not
        after) the transaction date. It is NULL when no exchange rate
        history exists for the transaction currency or the target
        currency, except for the identity case (currency = target_currency),
        which is always exact.
   ============================================================================= */

WITH source AS (

    SELECT
        transaction_ts,
        account,
        amount,
        amount_abs,
        currency,
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
        currency,
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

),

target_currencies AS (

    SELECT DISTINCT base_currency AS target_currency
    FROM {{ ref('core__exchange_rate') }}

    UNION

    SELECT 'RUB'

    UNION

    SELECT DISTINCT currency
    FROM {{ ref('core__fact_transaction') }}

),

converted AS (

    SELECT
        periodized.transaction_date,
        periodized.account,
        periodized.currency,
        periodized.parent_category,
        periodized.category,
        periodized.tags,
        periodized.note,
        periodized.transaction_type,
        periodized.expense_type,
        periodized.account_type,
        periodized.period_grain,
        periodized.period,
        tc.target_currency,

        CASE
            WHEN periodized.currency = tc.target_currency THEN periodized.amount_abs
            WHEN periodized.currency = 'RUB' THEN periodized.amount_abs / NULLIF(target_fx.rate, 0)
            WHEN tc.target_currency = 'RUB' THEN periodized.amount_abs * tx_fx.rate
            ELSE periodized.amount_abs * tx_fx.rate / NULLIF(target_fx.rate, 0)
        END AS amount_abs_converted

    FROM periodized
    CROSS JOIN target_currencies AS tc

    LEFT JOIN LATERAL (
        SELECT er.rate
        FROM {{ ref('core__exchange_rate') }} AS er
        WHERE
            er.base_currency = periodized.currency
            AND er.rate_date <= periodized.transaction_date::date
        ORDER BY er.rate_date DESC
        LIMIT 1
    ) AS tx_fx ON periodized.currency <> 'RUB' AND periodized.currency <> tc.target_currency

    LEFT JOIN LATERAL (
        SELECT er.rate
        FROM {{ ref('core__exchange_rate') }} AS er
        WHERE
            er.base_currency = tc.target_currency
            AND er.rate_date <= periodized.transaction_date::date
        ORDER BY er.rate_date DESC
        LIMIT 1
    ) AS target_fx ON tc.target_currency <> 'RUB' AND periodized.currency <> tc.target_currency

)

SELECT *
FROM converted
