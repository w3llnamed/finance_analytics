/* =============================================================================
   core__fact_transaction.sql
   Layer: core
   Purpose: Canonical fact table for personal money flow transactions.

   Source:
       stg__fact_transaction
       dim_accounts

   Description:
       The model stores income, expense, transfer and opening balance
       operations in a single canonical structure for downstream marts.

       Main responsibilities:
       - Union source transactions with opening balances
       - Expand transfers into transfer_out and transfer_in records
       - Generate stable transaction identifier
       - Enrich transactions with account attributes
       - Preserve ingestion metadata
   ============================================================================= */

WITH source_data AS (

    SELECT
        source_number,
        transaction_date AS transaction_ts,
        account,
        amount,
        currency,
        parent_category,
        subcategory,
        category,
        counterparty,
        transfer_account,
        transfer_amount,
        transfer_currency,
        tags,
        place,
        note,
        flow_type,
        CASE
            WHEN is_transfer THEN 'transfer_out'
        END AS transfer_type,
        ingested_at,
        ingested_by,
        source_file,
        ingestion_id
    FROM {{ ref('stg__fact_transaction') }}

),

opening_balance AS (

    SELECT
        NULL::TEXT AS source_number,
        opening_date::TIMESTAMP AS transaction_ts,
        account_name AS account,
        initial_amount::NUMERIC(18, 2) AS amount,
        currency AS currency,
        NULL::TEXT AS parent_category,
        NULL::TEXT AS subcategory,
        NULL::TEXT AS category,
        NULL::TEXT AS counterparty,
        NULL::TEXT AS transfer_account,
        NULL::NUMERIC(18, 2) AS transfer_amount,
        NULL::TEXT AS transfer_currency,
        NULL::TEXT AS tags,
        NULL::TEXT AS place,
        'Opening balance loaded from seed' AS note,
        'opening_balance' AS flow_type,
        NULL::TEXT AS transfer_type,
        NOW()::TIMESTAMPTZ AS ingested_at,
        CURRENT_USER::TEXT AS ingested_by,
        'seed.dim_accounts' AS source_file,
        NULL::BIGINT AS ingestion_id
    FROM {{ ref('dim_accounts') }}

),

unioned AS (

    SELECT * FROM source_data
    UNION ALL
    SELECT * FROM opening_balance

),

transfer_in AS (

    SELECT
        u.source_number,
        u.transaction_ts,
        u.transfer_account AS account,
        u.transfer_amount AS amount,
        COALESCE(u.transfer_currency, u.currency) AS currency,
        u.parent_category,
        u.subcategory,
        u.category,
        u.counterparty,
        u.account AS transfer_account,
        u.amount AS transfer_amount,
        u.currency AS transfer_currency,
        u.tags,
        u.place,
        u.note,
        u.flow_type,
        'transfer_in' AS transfer_type,
        u.ingested_at,
        u.ingested_by,
        u.source_file,
        u.ingestion_id
    FROM unioned AS u
    WHERE
        u.transfer_type IS NOT NULL
        AND u.transfer_account IS NOT NULL
        AND u.transfer_amount IS NOT NULL

),

expanded AS (

    SELECT * FROM unioned
    UNION ALL
    SELECT * FROM transfer_in

),

final AS (

    SELECT
        MD5(
            CONCAT_WS(
                '||',
                COALESCE(e.source_number, ''),
                COALESCE(e.transaction_ts::TEXT, ''),
                COALESCE(BTRIM(e.account), ''),
                COALESCE(e.amount::TEXT, ''),
                COALESCE(UPPER(BTRIM(e.currency)), ''),
                COALESCE(BTRIM(e.parent_category), ''),
                COALESCE(BTRIM(e.subcategory), ''),
                COALESCE(BTRIM(e.category), ''),
                COALESCE(BTRIM(e.counterparty), ''),
                COALESCE(BTRIM(e.transfer_account), ''),
                COALESCE(e.transfer_amount::TEXT, ''),
                COALESCE(BTRIM(e.transfer_currency), ''),
                COALESCE(BTRIM(e.tags), ''),
                COALESCE(BTRIM(e.place), ''),
                COALESCE(BTRIM(e.note), ''),
                COALESCE(BTRIM(e.transfer_type), ''),
                COALESCE(BTRIM(e.source_file), '')
            )
        ) AS transaction_id,

        e.source_number AS source_number,
        e.transaction_ts AS transaction_ts,
        e.account AS account,
        e.amount AS amount,
        e.currency AS currency,
        e.parent_category AS parent_category,
        e.subcategory AS subcategory,
        e.category AS category,
        e.counterparty AS counterparty,
        e.transfer_account AS transfer_account,
        e.transfer_amount AS transfer_amount,
        e.transfer_currency AS transfer_currency,
        e.tags AS tags,
        e.place AS place,
        e.note AS note,

        CASE
            WHEN e.flow_type = 'expense' THEN ABS(e.amount)
            WHEN e.flow_type = 'income' THEN e.amount
            WHEN e.flow_type = 'opening_balance' THEN e.amount
            ELSE ABS(e.amount)
        END AS amount_abs,

        CASE
            WHEN e.transfer_type = 'transfer_out' THEN 'transfer_out'
            WHEN e.transfer_type = 'transfer_in' THEN 'transfer_in'
            WHEN e.flow_type = 'expense' THEN 'expense'
            WHEN e.flow_type = 'income' THEN 'income'
            WHEN e.flow_type = 'opening_balance' THEN 'opening_balance'
            ELSE 'other'
        END AS transaction_type,

        dim_acc.is_active AS is_active_account,
        dim_acc.is_reserve AS is_reserve_account,
        dim_acc.is_credit AS is_credit_account,

        e.ingested_at AS ingested_at,
        e.ingested_by AS ingested_by,
        e.source_file AS source_file,
        e.ingestion_id AS ingestion_id

    FROM expanded AS e
    LEFT JOIN {{ ref('dim_accounts') }} AS dim_acc
        ON dim_acc.account_name = e.account

)

SELECT *
FROM final
