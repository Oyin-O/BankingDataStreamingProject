{% snapshot accounts_snapshot %}

{{
    config(
        target_schema='snapshots',
        unique_key='account_id',
        strategy='timestamp',
        updated_at='account_updated_at'
    )
}}

SELECT
    account_id,
    customer_id,
    bank_id,
    account_type,
    balance,
    currency,
    account_opened_at,
    account_updated_at
FROM {{ ref('silver_accounts') }}

{% endsnapshot %}