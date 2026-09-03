/* =============================================================================
    dm_demo__account_balance_demo.sql
    Layer: dm
    Purpose: Anonymized historical account balance snapshots for public demo
             dashboards.

    Source:
        core.fact_transaction
        core.exchange_rate
        seed.dim_accounts
        seed.dim_accounts_demo
        seed.category_mapping_demo

    Description:
        The model mirrors dm__account_balance but replaces real account
        names with demo account names and masks each transaction amount
        using category-level masking parameters from category_mapping_demo
        before the balance spine is built. This keeps the demo balance
        arithmetically consistent with dm_demo__fact_transaction_demo: the
        balance is the cumulative sum of masked amounts, not a separate
        coefficient applied to the real balance. Rows without a category
        match (in particular opening balances, which have no category) use
        an amount_factor of 1.0, matching the existing demo masking rule.

        Currency codes and exchange rates are not anonymized.

        See dm__account_balance.sql for the underlying spine, running
        balance and period-collapse logic, which is reused unchanged here.
   ============================================================================= */

WITH masked_transactions AS (

    SELECT
        cft.transaction_ts,
        acc_demo.account_name AS account,
        ROUND(cft.amount * COALESCE(cat.amount_factor, 1.0), 2) AS amount,
        cft.currency,
        cft.transaction_type,
        cft.is_reserve_account,
        cft.is_credit_account
    FROM {{ ref('core__fact_transaction') }} AS cft
    LEFT JOIN {{ ref('dim_accounts') }} AS acc_real
        ON cft.account = acc_real.account_name
    LEFT JOIN {{ ref('dim_accounts_demo') }} AS acc_demo
        ON acc_real.account_id = acc_demo.account_id
    LEFT JOIN {{ ref('category_mapping_demo') }} AS cat
        ON
            cft.parent_category = cat.real_parent_category
            AND cft.category = cat.real_category
    WHERE cft.is_active_account IS TRUE

),

accounts AS (

    SELECT
        account,
        MIN(transaction_ts)::DATE AS balance_start_date,
        MAX(currency) FILTER (WHERE transaction_type = 'opening_balance') AS currency,
        BOOL_OR(is_reserve_account) AS is_reserve_account,
        BOOL_OR(is_credit_account) AS is_credit_account
    FROM masked_transactions
    GROUP BY account

),

daily_transaction_totals AS (

    SELECT
        account,
        transaction_ts::DATE AS snapshot_date,
        SUM(amount) AS day_amount
    FROM masked_transactions
    GROUP BY account, transaction_ts::DATE

),

spine_bounds AS (

    SELECT
        MIN(balance_start_date) AS spine_start,
        CURRENT_DATE AS spine_end
    FROM accounts

),

calendar_spine AS (

    SELECT GENERATE_SERIES(spine_start, spine_end, INTERVAL '1 day')::DATE AS snapshot_date
    FROM spine_bounds

),

account_days AS (

    SELECT
        accounts.account,
        accounts.currency,
        accounts.is_reserve_account,
        accounts.is_credit_account,
        calendar_spine.snapshot_date
    FROM accounts
    CROSS JOIN calendar_spine
    WHERE calendar_spine.snapshot_date >= accounts.balance_start_date

),

running_balance AS (

    SELECT
        account_days.account,
        account_days.currency,
        account_days.is_reserve_account,
        account_days.is_credit_account,
        account_days.snapshot_date,

        SUM(COALESCE(daily_transaction_totals.day_amount, 0)) OVER (
            PARTITION BY account_days.account
            ORDER BY account_days.snapshot_date
        ) AS balance

    FROM account_days
    LEFT JOIN daily_transaction_totals
        ON
            daily_transaction_totals.account = account_days.account
            AND daily_transaction_totals.snapshot_date = account_days.snapshot_date

),

periodized AS (

    SELECT
        running_balance.account,

        CASE
            WHEN running_balance.is_reserve_account THEN 'Reserve'
            WHEN running_balance.is_credit_account THEN 'Credit'
            ELSE 'Standard'
        END AS account_type,

        running_balance.currency,
        running_balance.snapshot_date,
        running_balance.balance,
        period.period_grain,
        period.period
    FROM running_balance

    CROSS JOIN LATERAL (

        VALUES

        (
            'Day'::TEXT,
            TO_CHAR(
                running_balance.snapshot_date,
                'YYYY-MM-DD'
            )
        ),

        (
            'Week'::TEXT,
            TO_CHAR(
                DATE_TRUNC(
                    'week',
                    running_balance.snapshot_date
                ),
                'YYYY-MM-DD'
            )
        ),

        (
            'Month'::TEXT,
            TO_CHAR(
                running_balance.snapshot_date,
                'YYYY-MM'
            )
        ),

        (
            'Quarter'::TEXT,
            TO_CHAR(
                running_balance.snapshot_date,
                'YYYY'
            )
            || '-Q'
            || EXTRACT(
                QUARTER FROM running_balance.snapshot_date
            )::INTEGER::TEXT
        ),

        (
            'Year'::TEXT,
            TO_CHAR(
                running_balance.snapshot_date,
                'YYYY'
            )
        )

    ) AS period (
        period_grain,
        period
    )

),

period_snapshot AS (

    SELECT
        account,
        account_type,
        currency,
        period_grain,
        period,
        snapshot_date AS period_end,
        balance,

        ROW_NUMBER() OVER (
            PARTITION BY account, period_grain, period
            ORDER BY snapshot_date DESC
        ) AS rn
    FROM periodized

),

final AS (

    SELECT
        account,
        account_type,
        currency,
        period_grain,
        period,
        period_end,
        balance,
        period_end = MAX(period_end) OVER (
            PARTITION BY period_grain
        ) AS is_latest_period
    FROM period_snapshot
    WHERE rn = 1

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
        final.account,
        final.account_type,
        final.period_grain,
        final.period,
        final.period_end,
        final.is_latest_period,
        final.currency,
        final.balance,
        tc.target_currency,

        CASE
            WHEN final.currency = tc.target_currency THEN final.balance
            WHEN final.currency = 'RUB' THEN final.balance / NULLIF(target_fx.rate, 0)
            WHEN tc.target_currency = 'RUB' THEN final.balance * tx_fx.rate
            ELSE final.balance * tx_fx.rate / NULLIF(target_fx.rate, 0)
        END AS balance_converted

    FROM final
    CROSS JOIN target_currencies AS tc

    LEFT JOIN LATERAL (
        SELECT er.rate
        FROM {{ ref('core__exchange_rate') }} AS er
        WHERE
            er.base_currency = final.currency
            AND er.rate_date <= final.period_end
        ORDER BY er.rate_date DESC
        LIMIT 1
    ) AS tx_fx ON final.currency <> 'RUB' AND final.currency <> tc.target_currency

    LEFT JOIN LATERAL (
        SELECT er.rate
        FROM {{ ref('core__exchange_rate') }} AS er
        WHERE
            er.base_currency = tc.target_currency
            AND er.rate_date <= final.period_end
        ORDER BY er.rate_date DESC
        LIMIT 1
    ) AS target_fx ON tc.target_currency <> 'RUB' AND final.currency <> tc.target_currency

)

SELECT
    account,
    account_type,
    period_grain,
    period,
    period_end,
    is_latest_period,
    currency,
    balance,
    target_currency,
    balance_converted
FROM converted
