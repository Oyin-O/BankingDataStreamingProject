{% snapshot customers_snapshot %}

{{
    config(
        target_schema='snapshots',
        unique_key='customer_id',
        strategy='timestamp',
        updated_at='customer_updated_at'
    )
}}

SELECT
    customer_id,
    full_name,
    email,
    phone,
    nationality,
    customer_created_at,
    customer_updated_at
FROM {{ ref('silver_customers') }}

{% endsnapshot %}