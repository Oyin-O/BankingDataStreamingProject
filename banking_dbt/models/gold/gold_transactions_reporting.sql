WITH transactions AS (
    SELECT * FROM {{ ref('silver_transactions') }}
),

-- use snapshot to get customer details at time of transaction
customers AS (
    SELECT * FROM {{ ref('customers_snapshot') }}
),

-- use snapshot to get account details at time of transaction
accounts AS (
    SELECT * FROM {{ ref('accounts_snapshot') }}
),

transaction_legs AS (
    SELECT * FROM {{ ref('silver_transaction_legs') }}
),

debit_legs AS (
    SELECT
        transaction_id,
        account_id        AS sender_account_id,
        bank_id           AS sender_bank_id
    FROM transaction_legs
    WHERE direction = 'debit'
),

credit_legs AS (
    SELECT
        transaction_id,
        external_account_reference,
        external_account_name,
        bank_id           AS receiver_bank_id
    FROM transaction_legs
    WHERE direction = 'credit'
),

final AS (
    SELECT
        -- transaction details
        t.transaction_id,
        t.transaction_type,
        t.amount,
        t.currency,
        t.exchange_rate,
        t.amount_in_usd,
        t.status,
        t.channel,
        t.country,
        t.city,
        t.description,
        t.transaction_created_at,
        t.transaction_updated_at,

        -- account details at time of transaction
        a.account_id,
        a.account_type,
        a.balance          AS balance_at_transaction_time,
        a.currency         AS account_currency,

        -- customer details at time of transaction
        c.customer_id,
        c.full_name        AS customer_name,
        c.nationality      AS customer_nationality_at_time,
        c.email            AS customer_email,

        -- receiver details
        cl.external_account_name       AS receiver_name,
        cl.external_account_reference  AS receiver_iban,
        cl.receiver_bank_id

    FROM transactions t
    LEFT JOIN accounts a ON
        t.account_id = a.account_id
        AND t.transaction_created_at >= a.dbt_valid_from
        AND (t.transaction_created_at < a.dbt_valid_to OR a.dbt_valid_to IS NULL)
    LEFT JOIN customers c ON
        a.customer_id = c.customer_id
        AND t.transaction_created_at >= c.dbt_valid_from
        AND (t.transaction_created_at < c.dbt_valid_to OR c.dbt_valid_to IS NULL)
    LEFT JOIN debit_legs dl   ON t.transaction_id = dl.transaction_id
    LEFT JOIN credit_legs cl  ON t.transaction_id = cl.transaction_id
)

SELECT * FROM final