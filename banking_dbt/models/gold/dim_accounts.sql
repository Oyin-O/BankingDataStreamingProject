SELECT
    account_id,
    customer_id,
    bank_id,
    account_type,
    balance,
    currency,
    account_opened_at
FROM {{ ref('accounts_snapshot') }}
WHERE dbt_valid_to IS NULL