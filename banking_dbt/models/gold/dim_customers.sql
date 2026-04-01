SELECT
    customer_id,
    full_name,
    email,
    phone,
    nationality,
    customer_created_at
FROM {{ ref('customers_snapshot') }}
WHERE dbt_valid_to IS NULL
