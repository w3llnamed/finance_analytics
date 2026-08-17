/* =============================================================================
   dm_demo_fact_transaction_demo.sql
   Layer: dm
   Purpose: Anonymized transaction-level mart for public demo dashboards.

   Source:
       core.fact_transaction
       core.exchange_rate
       seed.recurring_expense_tag
       seed.reserve_funded_expense_tag
       seed.dim_accounts
       seed.dim_accounts_demo
       seed.category_mapping_demo

   Description:
       The model mirrors dm.fact_transaction but replaces real accounts and
       categories with demo values and masks transaction amounts using
       category-level masking parameters before any currency conversion.
       Currency codes and exchange rates are not anonymized: they do not
       identify a person.

       Each transaction is expanded into five time grains:
       Day, Week, Month, Quarter and Year.

       This allows demo dashboards to use categorical period axes while
       preserving dynamic grain selection and dashboard cross-filtering
       by period.

       Each transaction is further expanded into one row per supported
       target currency, carrying amount_abs_converted (the masked absolute
       amount converted using the exchange rate closest to, and not after,
       the transaction date), so any aggregation must filter to a single
       period_grain and a single target_currency.
   ============================================================================= */

WITH source AS (

    SELECT
        transaction_ts,
        account,
        amount,
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
    LEFT JOIN {{ ref('category_mapping_demo') }} AS cat
        ON
            flagged.parent_category = cat.real_parent_category
            AND flagged.category = cat.real_category

),

final AS (

    SELECT
        transaction_ts AS transaction_date,
        demo_account AS account,

        ABS(ROUND(amount * amount_factor, 2)) AS amount_abs,

        currency,
        demo_parent_category AS parent_category,
        demo_category AS category,

        NULL::TEXT AS tags,
        NULL::TEXT AS note,

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
    FROM mapped

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
            'Day'::TEXT,
            TO_CHAR(
                final.transaction_date,
                'YYYY-MM-DD'
            )
        ),

        (
            'Week'::TEXT,
            TO_CHAR(
                DATE_TRUNC(
                    'week',
                    final.transaction_date
                ),
                'YYYY-MM-DD'
            )
        ),

        (
            'Month'::TEXT,
            TO_CHAR(
                final.transaction_date,
                'YYYY-MM'
            )
        ),

        (
            'Quarter'::TEXT,
            TO_CHAR(
                final.transaction_date,
                'YYYY'
            )
            || '-Q'
            || EXTRACT(
                QUARTER FROM final.transaction_date
            )::INTEGER::TEXT
        ),

        (
            'Year'::TEXT,
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
            AND er.rate_date <= periodized.transaction_date::DATE
        ORDER BY er.rate_date DESC
        LIMIT 1
    ) AS tx_fx ON periodized.currency <> 'RUB' AND periodized.currency <> tc.target_currency

    LEFT JOIN LATERAL (
        SELECT er.rate
        FROM {{ ref('core__exchange_rate') }} AS er
        WHERE
            er.base_currency = tc.target_currency
            AND er.rate_date <= periodized.transaction_date::DATE
        ORDER BY er.rate_date DESC
        LIMIT 1
    ) AS target_fx ON tc.target_currency <> 'RUB' AND periodized.currency <> tc.target_currency

)

SELECT *
FROM converted
